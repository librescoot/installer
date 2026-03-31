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

int main(int argc, char *argv[]) {
    int seek_blocks = 0;
    int skip_blocks = 0;
    int count_blocks = -1;  // -1 = unlimited
    const char *device_path = NULL;

    for (int i = 1; i < argc; i++) {
        if (strncmp(argv[i], "--seek=", 7) == 0) {
            seek_blocks = atoi(argv[i] + 7);
        } else if (strncmp(argv[i], "--skip=", 7) == 0) {
            skip_blocks = atoi(argv[i] + 7);
        } else if (strncmp(argv[i], "--count=", 8) == 0) {
            count_blocks = atoi(argv[i] + 8);
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

    // Seek to the right position if --seek was specified
    if (seek_blocks > 0) {
        off_t offset = (off_t)seek_blocks * BLOCK_SIZE;
        if (lseek(device_fd, offset, SEEK_SET) < 0) {
            perror("lseek");
            close(device_fd);
            return 3;
        }
        fprintf(stderr, "Seeked to offset %lld (%d blocks)\n",
                (long long)offset, seek_blocks);
    }

    // Skip blocks from stdin if --skip was specified
    if (skip_blocks > 0) {
        char *skip_buf = malloc(BLOCK_SIZE);
        if (!skip_buf) {
            perror("malloc");
            close(device_fd);
            return 4;
        }
        for (int i = 0; i < skip_blocks; i++) {
            ssize_t remaining = BLOCK_SIZE;
            while (remaining > 0) {
                ssize_t r = read(STDIN_FILENO, skip_buf, remaining);
                if (r <= 0) {
                    fprintf(stderr, "EOF or error while skipping block %d\n", i);
                    free(skip_buf);
                    close(device_fd);
                    return 5;
                }
                remaining -= r;
            }
        }
        free(skip_buf);
        fprintf(stderr, "Skipped %d blocks from input\n", skip_blocks);
    }

    // Read from stdin, write to device
    char *buf = malloc(BLOCK_SIZE);
    if (!buf) {
        perror("malloc");
        close(device_fd);
        return 4;
    }

    off_t total_written = 0;
    int blocks_written = 0;

    while (count_blocks < 0 || blocks_written < count_blocks) {
        // Read one full block (or less at EOF)
        ssize_t block_read = 0;
        while (block_read < BLOCK_SIZE) {
            ssize_t r = read(STDIN_FILENO, buf + block_read, BLOCK_SIZE - block_read);
            if (r < 0) {
                perror("read from stdin");
                free(buf);
                close(device_fd);
                return 6;
            }
            if (r == 0) break;  // EOF
            block_read += r;
        }

        if (block_read == 0) break;  // EOF

        // Write the block to the device
        ssize_t written = 0;
        while (written < block_read) {
            ssize_t w = write(device_fd, buf + written, block_read - written);
            if (w < 0) {
                fprintf(stderr, "Write error at offset %lld: %s\n",
                        (long long)(total_written + written), strerror(errno));
                free(buf);
                close(device_fd);
                return 7;
            }
            written += w;
        }

        total_written += written;
        blocks_written++;

        // Report progress
        fprintf(stderr, "PROGRESS:%lld\n", (long long)total_written);
    }

    // Sync and close
    if (fsync(device_fd) < 0) {
        perror("fsync");
    }
    close(device_fd);
    free(buf);

    fprintf(stderr, "DONE:%lld\n", (long long)total_written);
    return 0;
}
