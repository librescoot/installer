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
//   watch <vid> <pid>   -> "ok" or "error: ..."
//   unwatch             -> "ok"
//   ping                -> "pong"
//   quit                -> exits cleanly (also: stdin EOF)
// <bsdname> is the BSD name without leading /dev/ — e.g. "disk8".
// <vid>/<pid> are USB ids, decimal or 0x-prefixed hex.
//
// `claim` needs the disk to already exist, which loses the race: macOS pops
// the dialog within milliseconds of enumeration, long before the caller's next
// poll. `watch` claims from a DA peek callback instead, which runs before the
// disk is probed. Arm it before the board reboots into mass-storage mode.
//
// On exit (clean or otherwise) all held claims are released. The DA framework
// also drops the claim if the helper crashes since the session goes away.

#import <Foundation/Foundation.h>
#import <DiskArbitration/DiskArbitration.h>
#import <IOKit/IOKitLib.h>
#import <stdatomic.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

static DASessionRef gSession;
static dispatch_queue_t gDAQueue;
static NSMutableDictionary<NSString *, NSValue *> *gClaims; // bsdName -> DADiskRef pointer

static bool gWatching;
static long gWatchVendor;
static long gWatchProduct;

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

// ---- watch ----

// Whether [media] sits underneath a USB device carrying [vendor]/[product].
// idVendor/idProduct live on the IOUSBHostDevice node, several nubs above the
// IOMedia, so walk up the service plane. Depth-limited: an unterminated walk
// would hang the DA queue.
static bool mediaIsUnderUsbDevice(io_service_t media, long vendor, long product) {
    io_service_t node = media;
    IOObjectRetain(node);

    for (int depth = 0; depth < 24 && node != IO_OBJECT_NULL; depth++) {
        CFNumberRef v = IORegistryEntryCreateCFProperty(
            node, CFSTR("idVendor"), kCFAllocatorDefault, 0);
        CFNumberRef p = IORegistryEntryCreateCFProperty(
            node, CFSTR("idProduct"), kCFAllocatorDefault, 0);

        bool decided = false;
        bool match = false;
        if (v && p &&
            CFGetTypeID(v) == CFNumberGetTypeID() &&
            CFGetTypeID(p) == CFNumberGetTypeID()) {
            long gotV = 0, gotP = 0;
            CFNumberGetValue(v, kCFNumberLongType, &gotV);
            CFNumberGetValue(p, kCFNumberLongType, &gotP);
            // First node publishing both ids wins; walking past it would test
            // the hub's identity instead.
            decided = true;
            match = (gotV == vendor && gotP == product);
        }
        if (v) CFRelease(v);
        if (p) CFRelease(p);
        if (decided) {
            IOObjectRelease(node);
            return match;
        }

        io_registry_entry_t parent = IO_OBJECT_NULL;
        kern_return_t kr =
            IORegistryEntryGetParentEntry(node, kIOServicePlane, &parent);
        IOObjectRelease(node);
        if (kr != KERN_SUCCESS) return false;
        node = parent;
    }

    if (node != IO_OBJECT_NULL) IOObjectRelease(node);
    return false;
}

static bool diskIsWholeMedia(DADiskRef disk) {
    CFDictionaryRef desc = DADiskCopyDescription(disk);
    if (!desc) return false;
    CFBooleanRef whole = CFDictionaryGetValue(desc, kDADiskDescriptionMediaWholeKey);
    bool result = (whole != NULL && CFBooleanGetValue(whole));
    CFRelease(desc);
    return result;
}

// Unlike doClaim's completion this one must not block: it shares the DA queue
// with the peek callback that submitted it.
static void watchClaimCallback(DADiskRef disk, DADissenterRef dissenter, void *ctx) {
    NSString *bsdName = (__bridge_transfer NSString *)ctx;
    if (!dissenter) {
        fprintf(stderr, "daclaim: watch claimed %s\n", [bsdName UTF8String]);
        return;
    }

    // Drop the optimistic entry made at submit time, so a later explicit
    // claim retries instead of being told it is already held.
    DADiskRef held = NULL;
    @synchronized (gClaims) {
        NSValue *boxed = gClaims[bsdName];
        if (boxed) {
            held = (DADiskRef)[boxed pointerValue];
            [gClaims removeObjectForKey:bsdName];
        }
    }
    if (held) CFRelease(held);
    fprintf(stderr, "daclaim: watch claim %s dissented 0x%x\n",
            [bsdName UTF8String], (unsigned)DADissenterGetStatus(dissenter));
}

// Claim [disk] if it is ours and not already held. Returns without waiting.
static void watchConsider(DADiskRef disk) {
    if (!gWatching) return;

    const char *name = DADiskGetBSDName(disk);
    if (!name) return;
    NSString *bsdName = @(name);

    if (!diskIsWholeMedia(disk)) return;

    io_service_t media = DADiskCopyIOMedia(disk);
    if (media == IO_OBJECT_NULL) return;
    bool mine = mediaIsUnderUsbDevice(media, gWatchVendor, gWatchProduct);
    IOObjectRelease(media);
    if (!mine) return;

    @synchronized (gClaims) {
        if (gClaims[bsdName]) return;
        // Recorded before the grant so peek-then-appeared can't double-submit.
        CFRetain(disk);
        gClaims[bsdName] = [NSValue valueWithPointer:disk];
    }

    fprintf(stderr, "daclaim: watch matched %s, claiming\n", name);
    DADiskClaim(disk, kDADiskClaimOptionDefault, onClaimAttempt, NULL,
                watchClaimCallback, (__bridge_retained void *)bsdName);
}

// Runs before the disk is probed. Everything that pops the dialog reacts to
// the probe, so this is the callback that beats it.
static void peekCallback(DADiskRef disk, void *ctx) {
    watchConsider(disk);
}

// Covers a disk already attached when the watch armed: its probe is long over,
// so no peek callback is coming.
static void appearedCallback(DADiskRef disk, void *ctx) {
    watchConsider(disk);
}

static void disappearedCallback(DADiskRef disk, void *ctx) {
    const char *name = DADiskGetBSDName(disk);
    if (!name) return;
    NSString *bsdName = @(name);
    DADiskRef held = NULL;
    @synchronized (gClaims) {
        NSValue *boxed = gClaims[bsdName];
        if (boxed) {
            held = (DADiskRef)[boxed pointerValue];
            [gClaims removeObjectForKey:bsdName];
        }
    }
    if (held) {
        fprintf(stderr, "daclaim: %s disappeared, dropping claim\n", name);
        CFRelease(held);
    }
}

static NSString *doWatch(long vendor, long product) {
    if (gWatching) return @"already watching";
    gWatchVendor = vendor;
    gWatchProduct = product;
    gWatching = true;
    DARegisterDiskPeekCallback(gSession, NULL, 0, peekCallback, NULL);
    DARegisterDiskAppearedCallback(gSession, NULL, appearedCallback, NULL);
    DARegisterDiskDisappearedCallback(gSession, NULL, disappearedCallback, NULL);
    return @"ok";
}

static NSString *doUnwatch(void) {
    if (!gWatching) return @"not watching";
    gWatching = false;
    DAUnregisterCallback(gSession, peekCallback, NULL);
    DAUnregisterCallback(gSession, appearedCallback, NULL);
    DAUnregisterCallback(gSession, disappearedCallback, NULL);
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
            char *arg2 = strtok(NULL, " ");
            NSString *result;

            if (cmd && strcmp(cmd, "claim") == 0 && arg) {
                result = doClaim(@(arg));
            } else if (cmd && strcmp(cmd, "release") == 0 && arg) {
                result = doRelease(@(arg));
            } else if (cmd && strcmp(cmd, "watch") == 0 && arg && arg2) {
                // Base 0: accepts 1317 and 0x525 alike, as ioreg prints both.
                char *endV = NULL, *endP = NULL;
                long vendor = strtol(arg, &endV, 0);
                long product = strtol(arg2, &endP, 0);
                if (endV == arg || *endV != '\0' || endP == arg2 || *endP != '\0') {
                    result = @"error: bad vid/pid";
                } else {
                    result = doWatch(vendor, product);
                }
            } else if (cmd && strcmp(cmd, "unwatch") == 0) {
                result = doUnwatch();
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
