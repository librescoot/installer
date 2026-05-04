// daclaim — macOS Disk Arbitration helper.
//
// Long-lived subprocess that pre-claims block devices via the DiskArbitration
// framework so macOS Finder/DiskUtility doesn't auto-mount them or pop the
// "Initialize / Erase / Ignore" dialog when an unrecognised partition table
// shows up (e.g. the MDB's Linux eMMC layout). With a claim held, even the
// kernel-level EPERM that authopen normally hits on /dev/rdiskN goes away.
//
// Protocol: line-based plain text on stdin/stdout.
//   claim <bsdname>     -> "ok" or "error: ..."
//   release <bsdname>   -> "ok" or "error: ..."
//   ping                -> "pong"
//   quit                -> exits cleanly (also: stdin EOF)
// <bsdname> is the BSD name without leading /dev/ — e.g. "disk8".
//
// On exit (clean or otherwise) all held claims are released. The DA framework
// also drops the claim if the helper crashes since the session goes away.

#import <Foundation/Foundation.h>
#import <DiskArbitration/DiskArbitration.h>
#import <stdatomic.h>
#import <stdio.h>
#import <string.h>

static DASessionRef gSession;
static dispatch_queue_t gDAQueue;
static NSMutableDictionary<NSString *, NSValue *> *gClaims; // bsdName -> DADiskRef pointer

// Returned to anyone else trying to claim/mount/probe the disk while we hold it.
// kDAReturnNotPermitted produces a clean rejection rather than a flapping retry.
static DADissenterRef onClaimAttempt(DADiskRef disk, void *ctx) {
    return DADissenterCreate(kCFAllocatorDefault, kDAReturnNotPermitted,
                             CFSTR("Held by librescoot-installer"));
}

// Heap-allocated so the DA callback can safely write to it even if our
// wait times out and we walk away. The ARC-vs-C-struct dance: we store the
// semaphore as a manually-retained void* (bridge_retained on create,
// bridge_transfer on free) so the dispatch_semaphore_t lifetime isn't tied
// to a stack-scoped strong reference. Worst case on timeout we leak ~280
// bytes per op; the OS reclaims at process exit.
typedef struct {
    DAReturn ret;
    char err[256];
    void *sema; // dispatch_semaphore_t, manually retained
    atomic_int abandoned; // set to 1 by waiter on timeout; callback frees if seen
} OpResult;

static OpResult *opNew(void) {
    OpResult *r = calloc(1, sizeof(OpResult));
    r->sema = (__bridge_retained void *)dispatch_semaphore_create(0);
    return r;
}

static void opFree(OpResult *r) {
    if (!r) return;
    if (r->sema) {
        dispatch_semaphore_t s = (__bridge_transfer dispatch_semaphore_t)r->sema;
        (void)s; // ARC releases on scope exit
        r->sema = NULL;
    }
    free(r);
}

static void completionCallback(DADiskRef disk, DADissenterRef dissenter, void *ctx) {
    OpResult *r = (OpResult *)ctx;
    if (dissenter) {
        r->ret = DADissenterGetStatus(dissenter);
        CFStringRef str = DADissenterGetStatusString(dissenter);
        if (str) {
            CFStringGetCString(str, r->err, sizeof(r->err), kCFStringEncodingUTF8);
        }
    } else {
        r->ret = kDAReturnSuccess;
    }
    if (atomic_load(&r->abandoned)) {
        opFree(r);
    } else {
        dispatch_semaphore_signal((__bridge dispatch_semaphore_t)r->sema);
    }
}

// Wait for an op to complete. Returns 1 on completion (caller owns r and
// should opFree it), 0 on timeout (callback now owns r, caller must NOT
// touch it again).
static int opWait(OpResult *r, dispatch_time_t deadline) {
    long rc = dispatch_semaphore_wait((__bridge dispatch_semaphore_t)r->sema, deadline);
    if (rc == 0) return 1;
    atomic_store(&r->abandoned, 1);
    return 0;
}

static NSString *doClaim(NSString *bsdName) {
    @synchronized (gClaims) {
        if (gClaims[bsdName]) return @"already claimed";
    }

    DADiskRef disk = DADiskCreateFromBSDName(kCFAllocatorDefault, gSession,
                                             [bsdName UTF8String]);
    if (!disk) return @"disk not found";

    // Force-unmount the whole disk (recursive across partitions). Best effort:
    // a disk with no mounted volumes returns an error here, which is fine.
    OpResult *unmount = opNew();
    DADiskUnmount(disk, kDADiskUnmountOptionWhole | kDADiskUnmountOptionForce,
                  completionCallback, unmount);
    if (opWait(unmount, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC))) {
        opFree(unmount);
    }

    // Now the actual claim. This is what blocks Finder/DA from grabbing it.
    OpResult *claim = opNew();
    DADiskClaim(disk, kDADiskClaimOptionDefault, onClaimAttempt, NULL,
                completionCallback, claim);
    if (!opWait(claim, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC))) {
        CFRelease(disk);
        return @"claim timeout";
    }
    DAReturn ret = claim->ret;
    char err[256];
    strncpy(err, claim->err, sizeof(err));
    opFree(claim);
    if (ret != kDAReturnSuccess) {
        CFRelease(disk);
        return [NSString stringWithFormat:@"claim failed: 0x%x %s",
                (unsigned)ret, err];
    }

    @synchronized (gClaims) {
        gClaims[bsdName] = [NSValue valueWithPointer:disk];
    }
    return @"ok";
}

static NSString *doRelease(NSString *bsdName) {
    DADiskRef disk = NULL;
    @synchronized (gClaims) {
        NSValue *boxed = gClaims[bsdName];
        if (!boxed) return @"not claimed";
        disk = (DADiskRef)[boxed pointerValue];
        [gClaims removeObjectForKey:bsdName];
    }
    DADiskUnclaim(disk);
    CFRelease(disk);
    return @"ok";
}

static void releaseAll(void) {
    NSDictionary *snapshot;
    @synchronized (gClaims) {
        snapshot = [gClaims copy];
        [gClaims removeAllObjects];
    }
    for (NSString *key in snapshot) {
        DADiskRef disk = (DADiskRef)[snapshot[key] pointerValue];
        DADiskUnclaim(disk);
        CFRelease(disk);
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        gSession = DASessionCreate(kCFAllocatorDefault);
        if (!gSession) {
            fprintf(stderr, "daclaim: DASessionCreate failed\n");
            return 1;
        }
        gDAQueue = dispatch_queue_create("net.librescoot.daclaim",
                                         DISPATCH_QUEUE_SERIAL);
        DASessionSetDispatchQueue(gSession, gDAQueue);
        gClaims = [NSMutableDictionary new];

        // Unbuffered stdout so the parent sees replies immediately.
        setvbuf(stdout, NULL, _IOLBF, 0);

        char line[1024];
        while (fgets(line, sizeof(line), stdin)) {
            char *nl = strchr(line, '\n');
            if (nl) *nl = '\0';
            char *cmd = strtok(line, " ");
            char *arg = strtok(NULL, " ");
            NSString *result;

            if (cmd && strcmp(cmd, "claim") == 0 && arg) {
                result = doClaim(@(arg));
            } else if (cmd && strcmp(cmd, "release") == 0 && arg) {
                result = doRelease(@(arg));
            } else if (cmd && strcmp(cmd, "ping") == 0) {
                result = @"pong";
            } else if (cmd && strcmp(cmd, "quit") == 0) {
                break;
            } else {
                result = @"error: unknown command";
            }
            printf("%s\n", [result UTF8String]);
        }

        releaseAll();
        if (gSession) CFRelease(gSession);
    }
    return 0;
}
