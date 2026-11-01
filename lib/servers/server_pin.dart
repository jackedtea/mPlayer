// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// The PIN that guards a server on this device.
///
/// **A lock on the app's door, not encryption.** It keeps someone holding the
/// unlocked phone out of a server's library; the token it guards sits in the
/// same keychain, and anyone who can read the keychain needs no PIN. What it
/// must not do is make the PIN itself recoverable from storage, so only a
/// salted, stretched hash is kept — never the digits.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// How long a PIN may be. Four is the least anyone accepts from a lock
/// screen; eight is as many digits as anyone types twice a day.
const int minPinLength = 4;
const int maxPinLength = 8;

/// Whether [pin] is the right shape to be set.
bool isValidPin(String pin) =>
    pin.length >= minPinLength &&
    pin.length <= maxPinLength &&
    RegExp(r'^\d+$').hasMatch(pin);

/// Rounds of SHA-256. Enough that trying all ten thousand four-digit PINs
/// against a copied hash is a noticeable job rather than an instant one,
/// little enough that checking one on a slow phone is not a visible pause.
const int _rounds = 20000;

/// The stored form of [pin]: `v1:<salt>:<hash>`, both base64.
///
/// [salt] is for tests; left out, a fresh random one is drawn, so two servers
/// guarded by the same PIN do not store the same string.
String hashPin(String pin, {List<int>? salt}) {
  final s = salt ?? _randomSalt();
  return 'v1:${base64Encode(s)}:${base64Encode(_stretch(pin, s))}';
}

/// Whether [pin] matches [stored], as written by [hashPin].
///
/// False for anything it cannot read, so a damaged entry locks rather than
/// opens — and the way out of a lock is signing in to the server again.
bool verifyPin(String pin, String stored) {
  final parts = stored.split(':');
  if (parts.length != 3 || parts[0] != 'v1') return false;

  try {
    final salt = base64Decode(parts[1]);
    final expected = base64Decode(parts[2]);
    return _equal(_stretch(pin, salt), expected);
  } on FormatException {
    return false;
  }
}

List<int> _stretch(String pin, List<int> salt) {
  var digest = sha256.convert(<int>[...salt, ...utf8.encode(pin)]).bytes;
  for (var i = 1; i < _rounds; i++) {
    digest = sha256.convert(<int>[...salt, ...digest]).bytes;
  }
  return digest;
}

List<int> _randomSalt() {
  final random = Random.secure();
  return List<int>.generate(16, (_) => random.nextInt(256));
}

/// Compares every byte whatever the first difference, so the time a check
/// takes says nothing about how much of a guess was right.
bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
