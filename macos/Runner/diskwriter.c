// diskwriter — authorized disk writer for macOS
// Uses AuthorizationCreate + authopen to get a writable fd to raw disk devices,
// bypassing macOS TCC restrictions on /dev/rdiskN.
//
// Usage: diskwriter [--seek=N] [--skip=N] [--count=N] /dev/rdiskN
//   --seek=N   Seek N blocks (4MB each) into the device before writing
//   --skip=N   Skip N blocks (4MB each) from stdin before writing
//   --count=N  Only write N blocks (4MB each)
//   Reads data from stdin, writes to the authorized device fd.
//   Reports progress as "PROGRESS:<bytes_written>\n" on stderr.
//
// Example:
//   gunzip -c image.sdimg.gz | diskwriter --seek=6 --skip=6 /dev/rdisk16
//   gunzip -c image.sdimg.gz | diskwriter --count=6 /dev/rdisk16

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <errno.h>
#include <Security/Authorization.h>

#define BLOCK_SIZE (4 * 1024 * 1024)

static void usage(const char *prog) {
    fprintf(stderr, "Usage: %s [--seek=N] [--skip=N] [--count=N] /dev/rdiskN\n", prog);
    fprintf(stderr, "  --seek=N   Seek N blocks (4MB) into device before writing\n");
    fprintf(stderr, "  --skip=N   Skip N blocks (4MB) from stdin\n");
    fprintf(stderr, "  --count=N  Write at most N blocks (4MB)\n");
    fprintf(stderr, "  Reads from stdin, writes to device. Progress on stderr.\n");
}

static int receive_fd(int sock) {
    struct msghdr msg = {0};
    char cmsgbuf[CMSG_SPACE(sizeof(int))];
    char dummy;
    struct iovec iov = { .iov_base = &dummy, .iov_len = 1 };

    msg.msg_iov = &iov;
    msg.msg_iovlen = 1;
    msg.msg_control = cmsgbuf;
    msg.msg_controllen = sizeof(cmsgbuf);

    ssize_t n = recvmsg(sock, &msg, 0);
    if (n < 0) {
        perror("recvmsg");
        return -1;
    }

    struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg);
    if (!cmsg || cmsg->cmsg_type != SCM_RIGHTS) {
        fprintf(stderr, "No fd received from authopen\n");
        return -1;
    }

    return *((int *)CMSG_DATA(cmsg));
}

static int authorize_and_open(const char *device_path) {
    // Request authorization with the specific right for this device
    char right_name[512];
    snprintf(right_name, sizeof(right_name), "sys.openfile.readwrite.%s", device_path);

    AuthorizationItem item = { right_name, 0, NULL, 0 };
    AuthorizationRights rights = { 1, &item };
    AuthorizationFlags flags = kAuthorizationFlagInteractionAllowed |
                               kAuthorizationFlagExtendRights |
                               kAuthorizationFlagPreAuthorize;

    AuthorizationRef auth_ref = NULL;
    OSStatus status = AuthorizationCreate(&rights, NULL, flags, &auth_ref);
    if (status != errAuthorizationSuccess) {
        fprintf(stderr, "Authorization failed: %d\n", (int)status);
        return -1;
    }

    // Serialize auth token for authopen
    AuthorizationExternalForm ext_form;
    status = AuthorizationMakeExternalForm(auth_ref, &ext_form);
    if (status != errAuthorizationSuccess) {
        fprintf(stderr, "AuthorizationMakeExternalForm failed: %d\n", (int)status);
        AuthorizationFree(auth_ref, kAuthorizationFlagDefaults);
        return -1;
    }

    // Create socket pair for fd passing (authopen -stdoutpipe sends fd via SCM_RIGHTS)
    int socks[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, socks) < 0) {
        perror("socketpair");
        AuthorizationFree(auth_ref, kAuthorizationFlagDefaults);
        return -1;
    }

    // Create pipe for authopen's stdin (to send the auth external form)
    int stdin_pipe[2];
    if (pipe(stdin_pipe) < 0) {
        perror("pipe");
        close(socks[0]);
        close(socks[1]);
        AuthorizationFree(auth_ref, kAuthorizationFlagDefaults);
        return -1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        close(socks[0]);
        close(socks[1]);
        close(stdin_pipe[0]);
        close(stdin_pipe[1]);
        AuthorizationFree(auth_ref, kAuthorizationFlagDefaults);
        return -1;
    }

    if (pid == 0) {
        // Child: exec authopen
        close(socks[0]);
        close(stdin_pipe[1]);

        dup2(socks[1], STDOUT_FILENO);
        dup2(stdin_pipe[0], STDIN_FILENO);
        close(socks[1]);
        close(stdin_pipe[0]);

        char mode_str[16];
        snprintf(mode_str, sizeof(mode_str), "%d", O_WRONLY);

        execl("/usr/libexec/authopen", "authopen",
              "-stdoutpipe", "-extauth",
              "-o", mode_str,
              device_path, NULL);
        perror("execl authopen");
        _exit(127);
    }

    // Parent
    close(socks[1]);
    close(stdin_pipe[0]);

    // Write auth token to authopen's stdin
    ssize_t written = write(stdin_pipe[1], ext_form.bytes, sizeof(ext_form.bytes));
    close(stdin_pipe[1]);

    if (written != sizeof(ext_form.bytes)) {
        fprintf(stderr, "Failed to write auth token to authopen\n");
        close(socks[0]);
        waitpid(pid, NULL, 0);
        AuthorizationFree(auth_ref, kAuthorizationFlagDefaults);
        return -1;
    }

    // Receive the writable fd via SCM_RIGHTS
    int device_fd = receive_fd(socks[0]);
    close(socks[0]);

    // Wait for authopen to exit
    int wstatus;
    waitpid(pid, &wstatus, 0);

    AuthorizationFree(auth_ref, kAuthorizationFlagDefaults);

    if (device_fd < 0) {
        fprintf(stderr, "Failed to receive device fd from authopen\n");
        if (WIFEXITED(wstatus)) {
            fprintf(stderr, "authopen exited with status %d\n", WEXITSTATUS(wstatus));
        }
        return -1;
    }

    return device_fd;
}

// Write data from an input fd to the device fd with skip/seek/count support.
// Returns 0 on success, non-zero on failure.
// Read exactly n bytes from fd, handling partial reads from pipes.
static ssize_t read_exact(int fd, void *buf, size_t n) {
    size_t total = 0;
    while (total < n) {
        ssize_t r = read(fd, (char *)buf + total, n - total);
        if (r < 0) return -1;
        if (r == 0) break;  // EOF
        total += r;
    }
    return (ssize_t)total;
}

static int write_phase(int device_fd, int input_fd, int skip_blocks, int seek_blocks, int count_blocks, const char *phase_name) {
    char buf[BLOCK_SIZE];

    // Seek on the device
    if (seek_blocks > 0) {
        off_t offset = (off_t)seek_blocks * BLOCK_SIZE;
        if (lseek(device_fd, offset, SEEK_SET) < 0) {
            fprintf(stderr, "%s: lseek to %lld failed: %s\n", phase_name, (long long)offset, strerror(errno));
            return 1;
        }
        fprintf(stderr, "%s: seeked to offset %lld\n", phase_name, (long long)offset);
    } else {
        lseek(device_fd, 0, SEEK_SET);
    }

    // Skip input blocks (read exactly BLOCK_SIZE per block)
    for (int i = 0; i < skip_blocks; i++) {
        ssize_t r = read_exact(input_fd, buf, BLOCK_SIZE);
        if (r < BLOCK_SIZE) {
            fprintf(stderr, "%s: failed to skip block %d (got %zd bytes)\n", phase_name, i, r);
            return 1;
        }
    }
    if (skip_blocks > 0) {
        fprintf(stderr, "%s: skipped %d input blocks (%lld bytes)\n", phase_name, skip_blocks, (long long)skip_blocks * BLOCK_SIZE);
    }

    // Write full blocks
    off_t total_written = 0;
    int blocks_written = 0;

    while (count_blocks < 0 || blocks_written < count_blocks) {
        ssize_t bytes_read = read_exact(input_fd, buf, BLOCK_SIZE);
        if (bytes_read <= 0) break;  // EOF or error

        ssize_t wr = 0;
        while (wr < bytes_read) {
            ssize_t w = write(device_fd, buf + wr, bytes_read - wr);
            if (w < 0) {
                fprintf(stderr, "%s: write error: %s\n", phase_name, strerror(errno));
                return 1;
            }
            wr += w;
        }
        total_written += wr;
        blocks_written++;
        fprintf(stderr, "PROGRESS:%lld\n", (long long)total_written);

        if (count_blocks > 0 && blocks_written >= count_blocks) break;
    }

    fsync(device_fd);
    fprintf(stderr, "%s: done, %lld bytes written\n", phase_name, (long long)total_written);
    return 0;
}

int main(int argc, char *argv[]) {
    int seek_blocks = 0;
    int skip_blocks = 0;
    int count_blocks = -1;  // -1 = unlimited
    int two_phase = 0;
    int boot_area_blocks = 6;
    const char *device_path = NULL;
    const char *image_path = NULL;

    for (int i = 1; i < argc; i++) {
        if (strncmp(argv[i], "--seek=", 7) == 0) {
            seek_blocks = atoi(argv[i] + 7);
        } else if (strncmp(argv[i], "--skip=", 7) == 0) {
            skip_blocks = atoi(argv[i] + 7);
        } else if (strncmp(argv[i], "--count=", 8) == 0) {
            count_blocks = atoi(argv[i] + 8);
        } else if (strcmp(argv[i], "--two-phase") == 0) {
            two_phase = 1;
        } else if (strncmp(argv[i], "--boot-blocks=", 14) == 0) {
            boot_area_blocks = atoi(argv[i] + 14);
        } else if (strncmp(argv[i], "--image=", 8) == 0) {
            image_path = argv[i] + 8;
        } else if (argv[i][0] == '/') {
            device_path = argv[i];
        } else {
            usage(argv[0]);
            return 1;
        }
    }

    if (!device_path) {
        usage(argv[0]);
        return 1;
    }

    fprintf(stderr, "Requesting authorization for %s...\n", device_path);

    int device_fd = authorize_and_open(device_path);
    if (device_fd < 0) {
        return 2;
    }

    fprintf(stderr, "Got authorized fd %d for %s\n", device_fd, device_path);

    // Bypass buffer cache (equivalent to oflag=direct)
    if (fcntl(device_fd, F_NOCACHE, 1) < 0) {
        fprintf(stderr, "Warning: F_NOCACHE failed: %s\n", strerror(errno));
    }

    if (two_phase && image_path) {
        // Two-phase flash: partitions first (safe), boot sector last (commits).
        // Uses a single authorization and keeps the fd open between phases.
        // The image is decompressed twice (once per phase) to avoid temp files.
        int is_compressed = (strlen(image_path) > 3 &&
            strcmp(image_path + strlen(image_path) - 3, ".gz") == 0);

        // Phase A: write everything from boot_area_blocks onwards
        fprintf(stderr, "PHASE:A\n");
        char decompress_cmd[4096];
        if (is_compressed) {
            snprintf(decompress_cmd, sizeof(decompress_cmd), "gunzip -c '%s'", image_path);
        } else {
            snprintf(decompress_cmd, sizeof(decompress_cmd), "cat '%s'", image_path);
        }

        FILE *input_a = popen(decompress_cmd, "r");
        if (!input_a) {
            fprintf(stderr, "Failed to open image for Phase A\n");
            close(device_fd);
            return 3;
        }
        int result = write_phase(device_fd, fileno(input_a), boot_area_blocks, boot_area_blocks, -1, "Phase A");
        pclose(input_a);
        if (result != 0) {
            close(device_fd);
            return 4;
        }

        // Phase B: write the first boot_area_blocks (boot sector)
        fprintf(stderr, "PHASE:B\n");
        FILE *input_b = popen(decompress_cmd, "r");
        if (!input_b) {
            fprintf(stderr, "Failed to open image for Phase B\n");
            close(device_fd);
            return 5;
        }
        result = write_phase(device_fd, fileno(input_b), 0, 0, boot_area_blocks, "Phase B");
        pclose(input_b);
        if (result != 0) {
            close(device_fd);
            return 6;
        }

        // Verify boot sector by reading back and comparing
        fprintf(stderr, "PHASE:VERIFY\n");
        FILE *verify_src = popen(decompress_cmd, "r");
        if (!verify_src) {
            fprintf(stderr, "Failed to open image for verification\n");
            close(device_fd);
            return 7;
        }

        lseek(device_fd, 0, SEEK_SET);
        char src_buf[BLOCK_SIZE];
        char dev_buf[BLOCK_SIZE];
        int verify_ok = 1;
        off_t verify_offset = 0;

        for (int i = 0; i < boot_area_blocks; i++) {
            ssize_t src_read = read_exact(fileno(verify_src), src_buf, BLOCK_SIZE);
            if (src_read <= 0) {
                fprintf(stderr, "Verify: failed to read source block %d\n", i);
                verify_ok = 0;
                break;
            }
            ssize_t dev_read = read_exact(device_fd, dev_buf, src_read);
            if (dev_read != src_read) {
                fprintf(stderr, "Verify: failed to read device block %d (got %zd, expected %zd)\n", i, dev_read, src_read);
                verify_ok = 0;
                break;
            }
            if (memcmp(src_buf, dev_buf, src_read) != 0) {
                // Find first mismatch
                for (ssize_t j = 0; j < src_read; j++) {
                    if (src_buf[j] != dev_buf[j]) {
                        fprintf(stderr, "Verify: MISMATCH at offset %lld (block %d + %zd): expected 0x%02x, got 0x%02x\n",
                                (long long)(verify_offset + j), i, j,
                                (unsigned char)src_buf[j], (unsigned char)dev_buf[j]);
                        break;
                    }
                }
                verify_ok = 0;
                break;
            }
            verify_offset += src_read;
            fprintf(stderr, "PROGRESS:%lld\n", (long long)verify_offset);
        }
        pclose(verify_src);

        if (!verify_ok) {
            fprintf(stderr, "VERIFY:FAIL\n");
            fprintf(stderr, "Boot sector verification FAILED — device may be corrupt!\n");
            close(device_fd);
            return 8;
        }
        fprintf(stderr, "VERIFY:OK\n");
        fprintf(stderr, "Boot sector verified: %lld bytes match\n", (long long)verify_offset);
    } else {
        // Single-phase write from stdin
        int result = write_phase(device_fd, STDIN_FILENO, skip_blocks, seek_blocks, count_blocks, "Write");
        if (result != 0) {
            close(device_fd);
            return 3;
        }
    }

    // Sync and close
    if (fsync(device_fd) < 0) {
        perror("fsync");
    }
    close(device_fd);

    fprintf(stderr, "DONE\n");
    return 0;
}
