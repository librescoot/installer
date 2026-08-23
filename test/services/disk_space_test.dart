import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/download_state.dart';
import 'package:librescoot_installer/services/download_service.dart';

/// The queue is several hundred MB. Starting it on a disk that cannot hold it
/// fills the cache with half-written files and fails somewhere in the middle,
/// where the reason is not visible. The check belongs before the first byte.
void main() {
  DownloadItem item(int size, {int done = 0}) {
    final i = DownloadItem(
      type: DownloadItemType.mdbFirmware,
      url: 'https://example.invalid/x',
      filename: 'x',
      expectedSize: size,
    );
    i.bytesDownloaded = done;
    return i;
  }

  test('only what is still missing counts towards the requirement', () {
    expect(DownloadService.bytesOutstanding([]), 0);
    expect(DownloadService.bytesOutstanding([item(100)]), 100);
    // A cached file needs no room.
    expect(DownloadService.bytesOutstanding([item(100, done: 100)]), 0);
    // A partial one needs only the remainder.
    expect(DownloadService.bytesOutstanding([item(100, done: 40)]), 60);
    expect(
      DownloadService.bytesOutstanding([item(100, done: 40), item(50), item(7, done: 7)]),
      110,
    );
  });

  test('a queue that fits reports no shortfall', () async {
    final dir = Directory.systemTemp;
    final shortfall = await DownloadService.shortfallFor(
      [item(1024)],
      dir,
      headroomBytes: 0,
    );
    expect(shortfall, isNull);
  });

  test('a queue that cannot fit reports how much is missing', () async {
    final dir = Directory.systemTemp;
    const absurd = 1 << 60; // an exabyte; no test machine has this free
    final shortfall = await DownloadService.shortfallFor(
      [item(absurd)],
      dir,
      headroomBytes: 0,
    );
    expect(shortfall, isNotNull);
    expect(shortfall!, greaterThan(0));
  });

  test('headroom is required on top of the queue', () async {
    final dir = Directory.systemTemp;
    // Nothing to download, but a headroom bigger than any disk. The install
    // writes and unpacks after the download, so a cache that exactly fits is
    // still not enough.
    final shortfall = await DownloadService.shortfallFor(
      [],
      dir,
      headroomBytes: 1 << 60,
    );
    expect(shortfall, isNotNull, reason: 'headroom must be demanded too');
  });

  test('free space is readable on this platform', () async {
    // If this returns null the check silently passes everywhere, so a
    // regression in the df/PowerShell parsing has to fail loudly here.
    final free = await DownloadService.freeBytesFor(Directory.systemTemp);
    expect(free, isNotNull, reason: 'could not read free space');
    expect(free!, greaterThan(0));
  });
}
