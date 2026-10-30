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
  Map<int, int> _songIndices = const {};
  bool _loading = false;
  bool _disposed = false;

  List<SongModel> get songs => _visibleSongs;
  List<SongModel> get allSongs => _songs;
  bool get isEmpty => _songs.isEmpty;
  bool get isLoading => _loading;
  bool get isRefreshing => _loading && status == LibraryStatus.ready;

  int? indexOfSong(int id) => _songIndices[id];

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
    _songIndices = {
      for (var i = 0; i < _visibleSongs.length; i++) _visibleSongs[i].id: i,
    };
  }

  void _clearSongs() {
    _songs = const [];
    _filter();
    service.clearArtwork();
  }

  Future<void> load({bool requestPermission = false}) async {
    // O diálogo de permissão também dispara eventos de ciclo de vida.
    if (_loading || _disposed) return;
    _loading = true;
    if (status != LibraryStatus.ready) status = LibraryStatus.loading;
    actionError = null;
    notifyListeners();
    try {
      if (!service.isSupported) {
        _clearSongs();
        status = LibraryStatus.unsupported;
        return;
      }
      final access = await service.access(request: requestPermission);
      if (_disposed) return;
      permanentlyDenied = access == PermissionStatus.deniedForever;
      if (access != PermissionStatus.granted) {
        _clearSongs();
        status = LibraryStatus.denied;
        return;
      }
      final result = await service.songs();
      if (_disposed) return;
      // A permissão pode ter sido revogada enquanto a consulta estava pendente.
      final currentAccess = await service.access(request: false);
      if (_disposed) return;
      if (currentAccess != PermissionStatus.granted) {
        permanentlyDenied = currentAccess == PermissionStatus.deniedForever;
        _clearSongs();
        status = LibraryStatus.denied;
        return;
      }
      service.retainArtworkFor(result);
      _songs = List.unmodifiable(result);
      _filter();
      status = LibraryStatus.ready;
    } catch (_) {
      if (!_disposed) {
        _clearSongs();
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
    service.clearArtwork();
    _disposed = true;
    super.dispose();
  }
}
