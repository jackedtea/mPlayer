// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/features/admin/admin_api_keys_page.dart';
import 'package:mplayer/features/admin/admin_logs_page.dart';
import 'package:mplayer/features/admin/admin_session_sheet.dart';
import 'package:mplayer/features/admin/admin_storage_page.dart';

void main() {
  test('a key shows its ends only', () {
    expect(maskKey('abcd1234efgh5678'), 'abcd••••5678');
    // Too short to show any of it safely.
    expect(maskKey('abc'), '•••');
  });

  test('log lines are coloured by their level bracket', () {
    expect(logLineLevel('[t] [ERR] [1] x'), LogLineLevel.error);
    expect(logLineLevel('[t] [FTL] [1] x'), LogLineLevel.error);
    expect(logLineLevel('[t] [WRN] [1] x'), LogLineLevel.warning);
    expect(logLineLevel('[t] [INF] [1] x'), LogLineLevel.other);
    // A stack trace line under an error carries no level of its own.
    expect(logLineLevel('   at Jellyfin.Server.Main()'), LogLineLevel.other);
  });

  test('filtering drops blank lines and matches without case', () {
    const text = '[t] [INF] [1] Started\n\n[t] [ERR] [1] Disk FULL\n';
    expect(filterLogLines(text), hasLength(2));
    expect(filterLogLines(text, query: 'disk'), <String>['[t] [ERR] [1] Disk FULL']);
    expect(filterLogLines(text, problemsOnly: true), hasLength(1));
  });

  test('bitrates read in the unit that fits', () {
    expect(formatBitrate(8400000), '8.4 Mbps');
    expect(formatBitrate(120000000), '120 Mbps');
    expect(formatBitrate(640000), '640 kbps');
  });

  test('disk share needs both halves', () {
    expect(diskShareUsed(free: 75, used: 25), 0.25);
    expect(diskShareUsed(free: null, used: 25), isNull);
    expect(isLowSpace(5 * 1024 * 1024 * 1024), isTrue);
    expect(isLowSpace(50 * 1024 * 1024 * 1024), isFalse);
  });
}
