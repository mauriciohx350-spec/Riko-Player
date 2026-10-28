import 'dart:async';

import 'dart:typed_data';

/// LRU limitado por entradas (incluindo ausências e pendências) e bytes.
/// No máximo quatro consultas nativas simultâneas. Entradas descartadas não
/// voltam ao cache quando uma consulta antiga termina.
class ArtworkCache<K> {
  ArtworkCache({
    this.maxEntries = 128,
    this.maxBytes = 8 * 1024 * 1024,
    this.ttl = const Duration(minutes: 5),
    this.maxConcurrent = 4,
    DateTime Function()? now,
  }) : assert(maxEntries > 0),
       assert(maxBytes > 0),
       assert(maxConcurrent > 0),
       _now = now ?? DateTime.now;

  final int maxEntries;
  final int maxBytes;
  final Duration ttl;
  final int maxConcurrent;
  final DateTime Function() _now;
  final _entries = <K, _ArtworkEntry>{};
  int _bytes = 0;
  int _running = 0;

  int get entryCount => _entries.length;
  int get byteCount => _bytes;

  Future<Uint8List?> get(K key, Future<Uint8List?> Function() loader) {
    var entry = _entries.remove(key);
    if (entry != null &&
        entry.expires != null &&
        !_now().isBefore(entry.expires!)) {
      _bytes -= entry.bytes;
      entry = null;
    }
    if (entry != null) {
      _entries[key] = entry;
      return entry.result.future;
    }
    final created = _ArtworkEntry(loader);
    _entries[key] = created;
    _trim();
    _pump();
    return created.result.future;
  }

  void retainKeys(Set<K> keys) {
    for (final key in _entries.keys.toList()) {
      if (!keys.contains(key)) _remove(key);
    }
  }

  void clear() {
    for (final key in _entries.keys.toList()) {
      _remove(key);
    }
  }

  void _remove(K key) {
    final entry = _entries.remove(key);
    if (entry == null) return;
    _bytes -= entry.bytes;
    if (!entry.result.isCompleted) entry.result.complete(null);
  }

  void _trim() {
    while (_entries.length > maxEntries || _bytes > maxBytes) {
      _remove(_entries.keys.first);
    }
  }

  void _pump() {
    while (_running < maxConcurrent) {
      final waiting = _entries.entries.where(
        (item) => !item.value.started && !item.value.result.isCompleted,
      );
      if (waiting.isEmpty) return;
      final item = waiting.first;
      final entry = item.value;
      entry.started = true;
      _running++;
      _load(item.key, entry);
    }
  }

  Future<void> _load(K key, _ArtworkEntry entry) async {
    Uint8List? data;
    try {
      data = await entry.loader();
    } catch (_) {
      // Falhas de capa também são temporariamente memorizadas.
    }
    if (identical(_entries[key], entry)) {
      if (data != null && data.isEmpty) data = null;
      entry.bytes = data?.lengthInBytes ?? 0;
      _bytes += entry.bytes;
      entry.expires = _now().add(ttl);
      entry.result.complete(data);
      _trim();
    }
    _running--;
    _pump();
  }
}

class _ArtworkEntry {
  _ArtworkEntry(this.loader);
  final Future<Uint8List?> Function() loader;
  final result = Completer<Uint8List?>();
  bool started = false;
  int bytes = 0;
  DateTime? expires;
}
