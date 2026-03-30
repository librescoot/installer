#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <signal.h>

/* i.MX6UL USB PHY base addresses */
#define USBPHY1_BASE 0x020C9000
#define USBPHY2_BASE 0x020CA000

/* Register offsets (MXS PHY layout with SET/CLR/TOG) */
#define PHY_CTRL     0x30
#define PHY_CTRL_SET 0x34
#define PHY_CTRL_CLR 0x38
#define PHY_STATUS   0x40

/* Bits */
#define CTRL_ENDEVPLUGINDET  (1 << 4)
#define CTRL_DEVPLUGIN_IRQ   (1 << 12)
#define STATUS_DEVPLUGIN     (1 << 6)

#define MAP_SIZE 0x1000

static volatile uint32_t *map_phys(int fd, uint32_t base)
{
    void *mapped = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE,
                        MAP_SHARED, fd, base & ~(MAP_SIZE - 1));
    if (mapped == MAP_FAILED) {
        perror("mmap");
        return NULL;
    }
    return (volatile uint32_t *)mapped;
}

static void test_phy(int fd, const char *name, uint32_t base)
{
    volatile uint32_t *regs = map_phys(fd, base);
    if (!regs)
        return;

    uint32_t ctrl = regs[PHY_CTRL / 4];
    uint32_t status = regs[PHY_STATUS / 4];

    printf("%s (0x%08X):\n", name, base);
    printf("  CTRL   = 0x%08X\n", ctrl);
    printf("  STATUS = 0x%08X\n", status);
    printf("  ENDEVPLUGINDET = %d\n", (ctrl >> 4) & 1);
    printf("  DEVPLUGIN_STATUS = %d\n", (status >> 6) & 1);

    if (!(ctrl & CTRL_ENDEVPLUGINDET)) {
        printf("  -> Enabling ENDEVPLUGINDET...\n");
        regs[PHY_CTRL_SET / 4] = CTRL_ENDEVPLUGINDET;
        usleep(50000); /* 50ms settle */

        ctrl = regs[PHY_CTRL / 4];
        status = regs[PHY_STATUS / 4];
        printf("  CTRL   = 0x%08X (after enable)\n", ctrl);
        printf("  STATUS = 0x%08X (after enable)\n", status);
        printf("  DEVPLUGIN_STATUS = %d\n", (status >> 6) & 1);
    }

    printf("\n");
    munmap((void *)regs, MAP_SIZE);
}

static void poll_phy(int fd, uint32_t base, int seconds)
{
    volatile uint32_t *regs = map_phys(fd, base);
    if (!regs)
        return;

    /* Ensure detection is enabled */
    regs[PHY_CTRL_SET / 4] = CTRL_ENDEVPLUGINDET;
    usleep(50000);

    printf("Polling DEVPLUGIN_STATUS for %ds (unplug/replug USB to test):\n", seconds);
    int last = -1;
    for (int i = 0; i < seconds * 10; i++) {
        uint32_t status = regs[PHY_STATUS / 4];
        int plugged = (status >> 6) & 1;
        if (plugged != last) {
            printf("  [%3d.%ds] DEVPLUGIN_STATUS = %d (%s)\n",
                   i / 10, (i % 10) * 100,
                   plugged, plugged ? "CONNECTED" : "DISCONNECTED");
            last = plugged;
        }
        usleep(100000); /* 100ms */
    }

    munmap((void *)regs, MAP_SIZE);
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0); /* disable output buffering */
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("open /dev/mem");
        return 1;
    }

    test_phy(fd, "USBPHY1 (OTG1)", USBPHY1_BASE);
    test_phy(fd, "USBPHY2 (OTG2)", USBPHY2_BASE);

    int poll_seconds = 30;
    if (argc > 1)
        poll_seconds = atoi(argv[1]);

    printf("--- Polling USBPHY1 (OTG1) ---\n");
    poll_phy(fd, USBPHY1_BASE, poll_seconds);

    close(fd);
    return 0;
}
