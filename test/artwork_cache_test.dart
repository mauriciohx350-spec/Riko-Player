import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/features/library/data/artwork_cache.dart';

void main() {
  test('Compartilha consultas pendentes e resultados sem capa', () async {
    final cache = ArtworkCache<int>();
    final pending = Completer<Uint8List?>();
    var calls = 0;
    Future<Uint8List?> loader() {
      calls++;
      return pending.future;
    }

    final first = cache.get(1, loader);
    final second = cache.get(1, loader);
    expect(identical(first, second), isTrue);
    expect(calls, 1);
    pending.complete(null);
    expect(await first, isNull);
    expect(await cache.get(1, loader), isNull);
    expect(calls, 1);
  });

  test('Descarta a entrada menos recentemente utilizada', () async {
    final cache = ArtworkCache<int>(maxEntries: 2);
    final calls = <int, int>{};
    Future<Uint8List?> load(int id) => cache.get(id, () async {
      calls[id] = (calls[id] ?? 0) + 1;
      return Uint8List(1);
    });
    await load(1);
    await load(2);
    await load(1);
    await load(3);
    expect(cache.entryCount, 2);
    await load(2);
    expect(calls[1], 1);
    expect(calls[2], 2);
  });

  test('Limita bytes e não retém capas maiores que o orçamento', () async {
    final cache = ArtworkCache<int>(maxBytes: 4);
    await cache.get(1, () async => Uint8List(3));
    await cache.get(2, () async => Uint8List(3));
    expect(cache.byteCount, 3);
    expect(cache.entryCount, 1);
    final large = await cache.get(3, () async => Uint8List(10));
    expect(large!.length, 10);
    expect(cache.byteCount, 0);
    expect(cache.entryCount, 0);
  });

  test('Expiração renova capas e resultados ausentes', () async {
    var now = DateTime(2026);
    final cache = ArtworkCache<int>(now: () => now);
    var calls = 0;
    Future<Uint8List?> loader() async {
      calls++;
      return null;
    }

    await cache.get(1, loader);
    now = now.add(const Duration(minutes: 4));
    await cache.get(1, loader);
    expect(calls, 1);
    now = now.add(const Duration(minutes: 1));
    await cache.get(1, loader);
    expect(calls, 2);
  });

  test('Limpeza impede que consultas antigas repovoem o cache', () async {
    final cache = ArtworkCache<int>();
    final old = Completer<Uint8List?>();
    final first = cache.get(1, () => old.future);
    cache.clear();
    expect(await first, isNull);
    final current = Uint8List.fromList([2]);
    await cache.get(1, () async => current);
    old.complete(Uint8List.fromList([1]));
    await Future<void>.delayed(Duration.zero);
    expect(await cache.get(1, () async => null), same(current));
    expect(cache.byteCount, 1);
  });

  test('Retém apenas entradas de músicas presentes e inalteradas', () async {
    final cache = ArtworkCache<(int, int)>();
    var calls = 0;
    Future<Uint8List?> loader() async {
      calls++;
      return Uint8List(1);
    }

    await cache.get((1, 10), loader);
    await cache.get((2, 10), loader);
    cache.retainKeys({(1, 10), (2, 20)});
    expect(cache.entryCount, 1);
    await cache.get((1, 10), loader);
    await cache.get((2, 20), loader);
    expect(calls, 3);
  });

  test(
    'Limita consultas concorrentes e descarta pendências excedentes',
    () async {
      final cache = ArtworkCache<int>(maxEntries: 2, maxConcurrent: 1);
      final pending = Completer<Uint8List?>();
      final first = cache.get(1, () => pending.future);
      var calls = 0;
      final second = cache.get(2, () async {
        calls++;
        return null;
      });
      final third = cache.get(3, () async {
        calls++;
        return null;
      });
      expect(cache.entryCount, 2);
      expect(calls, 0);
      expect(await first, isNull);
      pending.complete(null);
      await second;
      await third;
      expect(calls, 2);
    },
  );

  test('Falha na leitura não bloqueia a fila e também é memorizada', () async {
    final cache = ArtworkCache<int>(maxConcurrent: 1);
    var calls = 0;
    Future<Uint8List?> fail() async {
      calls++;
      throw StateError('capa');
    }

    expect(await cache.get(1, fail), isNull);
    expect(await cache.get(1, fail), isNull);
    expect(calls, 1);
    expect(await cache.get(2, () async => Uint8List(1)), isNotNull);
  });
}
