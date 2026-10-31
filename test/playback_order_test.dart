import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/features/playback/logic/playback_order.dart';

void main() {
  test(
    'sequential previous from a middle selection preserves legacy navigation',
    () {
      final order = PlaybackOrder(random: Random(1))..reset(5, 3);
      expect(order.previous(), 2);
      expect(order.previous(), 1);
      expect(order.next(), 2);
      expect(order.next(), 3);
      expect(order.next(), 4);
      expect(order.next(), isNull);
    },
  );

  test('empty order is safe; invalid resets are rejected', () {
    final order = PlaybackOrder(random: Random(7));
    order.setShuffle(true);
    expect(order.next(repeatAll: true), isNull);
    expect(order.previous(), isNull);
    expect(order.hasNext, isFalse);
    expect(() => order.reset(0, 0), throwsArgumentError);
  });

  test('shuffle visits every index once, including before selected index', () {
    for (var seed = 0; seed < 40; seed++) {
      final order = PlaybackOrder(random: Random(seed))..setShuffle(true);
      order.reset(8, 4);
      final cycle = [order.current];
      while (order.hasNext) {
        cycle.add(order.next());
      }
      expect(cycle.length, 8);
      expect(cycle.toSet(), {0, 1, 2, 3, 4, 5, 6, 7});
      expect(order.next(), isNull);
    }
  });

  test('same seed reproduces order and previous retraces actual history', () {
    final a = PlaybackOrder(random: Random(31))..setShuffle(true);
    final b = PlaybackOrder(random: Random(31))..setShuffle(true);
    a.reset(6, 2);
    b.reset(6, 2);
    final path = [a.current, a.next(), a.next(), a.next()];
    expect([b.current, b.next(), b.next(), b.next()], path);
    expect(a.previous(), path[2]);
    expect(a.previous(), path[1]);
    expect(a.next(), path[2]);
    expect(a.next(), path[3]);
    final rest = [a.next(), a.next()];
    expect({...path, ...rest}.length, 6);
    expect(a.hasNext, isFalse);
  });

  test('toggle preserves history and shuffles only unvisited entries', () {
    final order = PlaybackOrder(random: Random(8))..reset(5, 0);
    expect(order.next(), 1);
    expect(order.next(), 2);
    expect(order.previous(), 1);
    order.setShuffle(true);
    expect(order.current, 1);
    expect(order.next(), 2);
    expect(<int?>{order.next(), order.next()}, {3, 4});
    expect(order.hasNext, isFalse);
    order.setShuffle(false);
    expect(order.current, isNotNull);
  });

  test('disabling shuffle resumes original sequence from current frontier', () {
    final order = PlaybackOrder(random: Random(2))..setShuffle(true);
    order.reset(5, 2);
    order.setShuffle(false);
    expect(order.current, 2);
    expect(order.next(), 3);
    expect(order.next(), 4);
    expect(order.next(), isNull);
  });

  test('repeat all cycles avoid adjacent repetition and preserve history', () {
    for (var seed = 0; seed < 40; seed++) {
      final order = PlaybackOrder(random: Random(seed))..setShuffle(true);
      order.reset(5, 0);
      var last = order.current!;
      for (var cycle = 0; cycle < 12; cycle++) {
        final entries = <int>[];
        if (cycle == 0) entries.add(last);
        while (entries.length < 5) {
          final next = order.next(repeatAll: true)!;
          expect(next, isNot(last));
          entries.add(next);
          last = next;
        }
        expect(entries.toSet().length, 5);
      }
      final previous = order.previous();
      expect(order.next(), last);
      expect(previous, isNot(last));
    }
  });

  test('one entry repeats only when repeat all is requested', () {
    final order = PlaybackOrder(random: Random(1))..setShuffle(true);
    order.reset(1, 0);
    expect(order.next(), isNull);
    expect(order.next(repeatAll: true), 0);
    expect(order.previous(), 0);
  });

  test('reset drops old history and preserves shuffle preference', () {
    final order = PlaybackOrder(random: Random(3))..setShuffle(true);
    order.reset(6, 0);
    order.next();
    order.reset(2, 1);
    expect(order.previous(), 1);
    expect(order.next(), 0);
    expect(order.hasNext, isFalse);
  });
}
