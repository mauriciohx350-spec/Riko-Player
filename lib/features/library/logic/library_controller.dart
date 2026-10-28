import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/foundation.dart';

import '../data/music_library_service.dart';
import 'song_details.dart';

enum LibraryStatus { loading, ready, denied, error, unsupported }

class LibraryController extends ChangeNotifier {
  LibraryController(this.service);

  final MusicLibraryService service;
  LibraryStatus status = LibraryStatus.loading;
  bool permanentlyDenied = false;
  String? actionError;
  List<SongModel> _songs = const [];
  List<SongModel> _visibleSongs = const [];
  String _search = '';
  bool _loading = false;
  bool _disposed = false;

  List<SongModel> get songs => _visibleSongs;
  bool get isEmpty => _songs.isEmpty;

  void search(String value) {
    _search = value.trim().toLowerCase();
    _filter();
    notifyListeners();
  }

  void _filter() {
    _visibleSongs = List.unmodifiable(
      _songs.where(
        (song) =>
            song.displayTitle.toLowerCase().contains(_search) ||
            song.displayArtist.toLowerCase().contains(_search),
      ),
    );
  }

  Future<void> load({bool requestPermission = false}) async {
    // O diálogo de permissão também dispara eventos de ciclo de vida.
    if (_loading || _disposed) return;
    _loading = true;
    status = LibraryStatus.loading;
    actionError = null;
    notifyListeners();
    try {
      if (!service.isSupported) {
        status = LibraryStatus.unsupported;
        return;
      }
      final access = await service.access(request: requestPermission);
      if (_disposed) return;
      permanentlyDenied = access == PermissionStatus.deniedForever;
      if (access != PermissionStatus.granted) {
        _songs = const [];
        _filter();
        status = LibraryStatus.denied;
        return;
      }
      final result = await service.songs();
      if (_disposed) return;
      _songs = List.unmodifiable(result);
      _filter();
      status = LibraryStatus.ready;
    } catch (_) {
      if (!_disposed) {
        _songs = const [];
        _filter();
        status = LibraryStatus.error;
      }
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> openSettings() async {
    try {
      final opened = await service.openSettings();
      if (!_disposed && !opened) {
        actionError = 'Não foi possível abrir as configurações do Android.';
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed) {
        actionError = 'Não foi possível abrir as configurações do Android.';
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
