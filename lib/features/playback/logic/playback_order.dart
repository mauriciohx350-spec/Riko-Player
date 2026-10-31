import 'dart:math';

/// Navegação por índices: nunca altera a fila original nem o banco.
class PlaybackOrder {
  PlaybackOrder({Random? random}) : _random = random ?? Random();
  final Random _random;
  int _length = 0;
  bool _shuffle = false;
  final List<int> _history = [];
  final Set<int> _visited = {};
  List<int> _remaining = [];
  int _cursor = -1;

  bool get shuffle => _shuffle;
  int? get current => _cursor < 0 ? null : _history[_cursor];
  bool get hasNext => _cursor + 1 < _history.length || _remaining.isNotEmpty;

  void reset(int length, int start) {
    if (length < 1 || start < 0 || start >= length) {
      throw ArgumentError('Fila ou índice inválido');
    }
    _length = length;
    _history
      ..clear()
      ..add(start);
    _cursor = 0;
    _visited
      ..clear()
      ..add(start);
    _rebuildRemaining();
  }

  void setShuffle(bool enabled) {
    if (_shuffle == enabled) return;
    _shuffle = enabled;
    _rebuildRemaining();
  }

  void _rebuildRemaining() {
    if (_history.isEmpty) return;
    // Preserva também o futuro já percorrido ao voltar pelo histórico.
    final frontier = _history.last;
    _remaining = [
      for (var i = 0; i < _length; i++)
        if (_shuffle ? !_visited.contains(i) : i > frontier) i,
    ];
    if (_shuffle) _remaining.shuffle(_random);
  }

  int? next({bool repeatAll = false}) {
    if (current == null) return null;
    if (_cursor + 1 < _history.length) return _history[++_cursor];
    if (_remaining.isEmpty) {
      if (!repeatAll) return null;
      final last = current!;
      _visited.clear();
      _remaining = List.generate(_length, (index) => index);
      if (_shuffle) {
        _remaining.shuffle(_random);
        if (_length > 1 && _remaining.first == last) {
          final first = _remaining[0];
          _remaining[0] = _remaining[1];
          _remaining[1] = first;
        }
      }
    }
    final selected = _remaining.removeAt(0);
    _visited.add(selected);
    _history.add(selected);
    _cursor++;
    return selected;
  }

  int? previous() {
    if (_cursor > 0) {
      _cursor--;
    } else if (!_shuffle && current != null && current! > 0) {
      // Mantém Anterior sequencial quando a seleção começou no meio da fila.
      final selected = current! - 1;
      _history.insert(0, selected);
      _visited.add(selected);
    }
    return current;
  }
}
