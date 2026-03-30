#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

/* i.MX6UL USB OTG1 controller */
#define USB_OTG1_BASE	0x02184000
#define USBSTS_OFF	0x144
#define USBCMD_OFF	0x140
#define PORTSC_OFF	0x184
#define OTGSC_OFF	0x1A4

/* USBPHY1 */
#define USBPHY1_BASE	0x020C9000
#define PHY_CTRL	0x30
#define PHY_CTRL_SET	0x34
#define PHY_STATUS	0x40

/* Bits */
#define STS_SLI		(1 << 8)
#define STS_URI		(1 << 6)
#define STS_PCI		(1 << 2)
#define STS_UI		(1 << 0)
#define OTGSC_BSV	(1 << 11)  /* B-Session Valid */
#define OTGSC_BSE	(1 << 12)  /* B-Session End */
#define PHY_ENDEVPLUGINDET (1 << 4)
#define PHY_DEVPLUGIN	(1 << 6)

#define MAP_SIZE 0x1000

int main(int argc, char **argv)
{
	setvbuf(stdout, NULL, _IONBF, 0);

	int fd = open("/dev/mem", O_RDWR | O_SYNC);
	if (fd < 0) { perror("open /dev/mem"); return 1; }

	volatile uint32_t *usb = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE,
				      MAP_SHARED, fd, USB_OTG1_BASE);
	volatile uint32_t *phy = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE,
				      MAP_SHARED, fd, USBPHY1_BASE);
	if (usb == MAP_FAILED || phy == MAP_FAILED) { perror("mmap"); return 1; }

	/* Enable PHY detection */
	phy[PHY_CTRL_SET / 4] = PHY_ENDEVPLUGINDET;
	usleep(50000);

	printf("Initial state:\n");
	printf("  USBSTS  = 0x%08x (SLI=%d URI=%d PCI=%d UI=%d)\n",
		usb[USBSTS_OFF/4],
		!!(usb[USBSTS_OFF/4] & STS_SLI),
		!!(usb[USBSTS_OFF/4] & STS_URI),
		!!(usb[USBSTS_OFF/4] & STS_PCI),
		!!(usb[USBSTS_OFF/4] & STS_UI));
	printf("  USBCMD  = 0x%08x\n", usb[USBCMD_OFF/4]);
	printf("  PORTSC  = 0x%08x\n", usb[PORTSC_OFF/4]);
	printf("  OTGSC   = 0x%08x (BSV=%d BSE=%d)\n",
		usb[OTGSC_OFF/4],
		!!(usb[OTGSC_OFF/4] & OTGSC_BSV),
		!!(usb[OTGSC_OFF/4] & OTGSC_BSE));
	printf("  PHY_CTRL   = 0x%08x\n", phy[PHY_CTRL/4]);
	printf("  PHY_STATUS = 0x%08x (DEVPLUGIN=%d)\n",
		phy[PHY_STATUS/4],
		!!(phy[PHY_STATUS/4] & PHY_DEVPLUGIN));

	int seconds = argc > 1 ? atoi(argv[1]) : 60;
	printf("\nPolling for %ds (unplug USB to test):\n", seconds);

	uint32_t last_sts = 0, last_otgsc = 0, last_portsc = 0, last_phy = 0;
	for (int i = 0; i < seconds * 10; i++) {
		uint32_t sts = usb[USBSTS_OFF/4];
		uint32_t otgsc = usb[OTGSC_OFF/4];
		uint32_t portsc = usb[PORTSC_OFF/4];
		uint32_t physts = phy[PHY_STATUS/4];

		if (sts != last_sts || otgsc != last_otgsc ||
		    portsc != last_portsc || physts != last_phy) {
			printf("  [%3d.%ds] STS=0x%08x(SLI=%d) OTGSC=0x%08x(BSV=%d) PORTSC=0x%08x DEVPLUGIN=%d\n",
				i/10, (i%10)*100,
				sts, !!(sts & STS_SLI),
				otgsc, !!(otgsc & OTGSC_BSV),
				portsc,
				!!(physts & PHY_DEVPLUGIN));
			last_sts = sts;
			last_otgsc = otgsc;
			last_portsc = portsc;
			last_phy = physts;
		}
		usleep(100000);
	}

	munmap((void*)usb, MAP_SIZE);
	munmap((void*)phy, MAP_SIZE);
	close(fd);
	return 0;
}
