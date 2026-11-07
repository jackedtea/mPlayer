// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:math' show Random;

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/sources/media_source.dart';

MediaRef _ref(String id) => MediaRef(sourceId: 'p1', itemId: id, title: id);

/// Songs a to e, on [index].
PlaybackQueue _queue({int index = 0}) => PlaybackQueue(
  items: <MediaRef>[for (final String id in 'abcde'.split('')) _ref(id)],
  index: index,
  kind: PlaybackQueueKind.music,
);

String _order(PlaybackQueue queue) =>
    queue.items.map((r) => r.itemId).join();

void main() {
  group('how a queue ends', () {
    test('music rolls on with auto-play off, episodes do not', () {
      // The setting is about binging. Turning it off must not stop an album
      // after its first song.
      expect(_queue().rollsOn(autoPlay: false), isTrue);

      final episodes = PlaybackQueue(
        items: <MediaRef>[_ref('e1'), _ref('e2')],
        kind: PlaybackQueueKind.series,
      );
      expect(episodes.rollsOn(autoPlay: false), isFalse);
      expect(episodes.rollsOn(autoPlay: true), isTrue);
    });

    test('nothing rolls on from the last item', () {
      expect(_queue(index: 4).rollsOn(autoPlay: true), isFalse);
    });

    test('music offers no next-up pill, episodes do', () {
      PlaybackState nearTheEnd(PlaybackQueue queue) => PlaybackState(
        queue: queue,
        duration: const Duration(minutes: 3),
        position: const Duration(minutes: 2, seconds: 59),
      );

      expect(nearTheEnd(_queue()).nextUpDue, isFalse);
      expect(
        nearTheEnd(
          PlaybackQueue(
            items: <MediaRef>[_ref('e1'), _ref('e2')],
            kind: PlaybackQueueKind.series,
          ),
        ).nextUpDue,
        isTrue,
      );
    });
  });

  group('stepping', () {
    test('keeps the kind and the way back from shuffle', () {
      final stepped = _queue().shuffled(Random(1)).stepTo(2)!;

      expect(stepped.isMusic, isTrue);
      expect(stepped.isShuffled, isTrue);
      expect(stepped.index, 2);
    });
  });

  group('changing the queue', () {
    test('play next goes straight after what is playing', () {
      final next = _queue(index: 1).playingNext(_ref('x'));

      expect(_order(next), 'abxcde');
      expect(next.current?.itemId, 'b');
    });

    test('play next on an empty queue is the queue', () {
      expect(_order(const PlaybackQueue().playingNext(_ref('x'))), 'x');
    });

    test('add to queue goes at the end', () {
      expect(_order(_queue(index: 1).appended(_ref('x'))), 'abcdex');
    });

    test('moving keeps the current item current', () {
      for (final (int from, int to, String order, int index)
          in <(int, int, String, int)>[
            // The current item itself.
            (2, 0, 'cabde', 0),
            // From before it to after it.
            (0, 4, 'bcdea', 1),
            // From after it to before it.
            (4, 0, 'eabcd', 3),
            // Both on one side of it.
            (3, 4, 'abced', 2),
          ]) {
        final moved = _queue(index: 2).moved(from, to);
        expect(_order(moved), order);
        expect(moved.index, index);
        expect(moved.current?.itemId, 'c');
      }
    });

    test('a move off the end changes nothing', () {
      final queue = _queue();
      expect(queue.moved(0, 9), same(queue));
      expect(queue.moved(-1, 2), same(queue));
      expect(queue.moved(2, 2), same(queue));
    });

    test('removing keeps the current item current', () {
      final before = _queue(index: 2).removedAt(0);
      expect(_order(before), 'bcde');
      expect(before.current?.itemId, 'c');

      final after = _queue(index: 2).removedAt(4);
      expect(_order(after), 'abcd');
      expect(after.current?.itemId, 'c');
    });

    test('what is playing cannot be removed', () {
      final queue = _queue(index: 2);
      expect(queue.removedAt(2), same(queue));
      expect(queue.removedAt(9), same(queue));
    });
  });

  group('shuffle', () {
    test('turning it on leaves the current item playing, first', () {
      final shuffled = _queue(index: 2).shuffled(Random(1));

      expect(shuffled.index, 0);
      expect(shuffled.current?.itemId, 'c');
      expect(shuffled.items, unorderedEquals(_queue().items));
    });

    test('turning it off goes back to the order, on the same item', () {
      final shuffled = _queue().shuffled(Random(1));
      final song = shuffled.stepTo(3)!;

      final restored = song.inOriginalOrder();

      expect(_order(restored), 'abcde');
      expect(restored.current, song.current);
      expect(restored.isShuffled, isFalse);
      expect(restored.isMusic, isTrue);
    });

    test('shuffling again keeps the first order to go back to', () {
      final twice = _queue().shuffled(Random(1)).shuffled(Random(2));
      expect(_order(twice.inOriginalOrder()), 'abcde');
    });

    test('what is added while shuffled survives turning it off', () {
      final queue = _queue(index: 1)
          .shuffled(Random(1))
          .playingNext(_ref('x'))
          .appended(_ref('y'));

      // Second in the deal, and after b once the order comes back.
      expect(queue.items[1].itemId, 'x');
      expect(_order(queue.inOriginalOrder()), 'abxcdey');
    });

    test('what is removed while shuffled stays gone', () {
      final queue = _queue().shuffled(Random(1));
      final removed = queue.removedAt(1);

      expect(
        removed.inOriginalOrder().items,
        isNot(contains(queue.items[1])),
      );
    });

    test('a Shuffle button deals everything, and keeps the order', () {
      final queue = PlaybackQueue.shuffledFrom(
        _queue().items,
        kind: PlaybackQueueKind.music,
        random: Random(3),
      );

      expect(queue.index, 0);
      expect(queue.isMusic, isTrue);
      expect(queue.items, unorderedEquals(_queue().items));
      expect(_order(queue.inOriginalOrder()), 'abcde');
    });
  });
}
