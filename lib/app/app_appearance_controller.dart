import 'package:flutter/material.dart';

import 'app_appearance_state.dart';
import 'app_appearance_storage.dart';
import 'app_palette.dart';

class AppAppearanceController extends ChangeNotifier {
  AppAppearanceController({required AppAppearanceStorage storage})
    : this._(storage: storage);

  AppAppearanceController._({required this._storage});

  final AppAppearanceStorage _storage;
  AppAppearanceState _state = AppAppearanceState.initial;
  bool _disposed = false;

  AppAppearanceState get state => _state;

  Future<void> load() async {
    try {
      final stored = await _storage.load();
      _setState(
        _state.copyWith(
          themeMode: stored?.themeMode ?? ThemeMode.system,
          palette: stored?.palette ?? AppPalette.ocean,
          isLoaded: true,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[Appearance] step=load-failed '
        'errorType=${error.runtimeType} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _setState(_state.copyWith(isLoaded: true));
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_state.themeMode == mode) {
      return;
    }
    _setState(_state.copyWith(themeMode: mode, isLoaded: true));
    await _persist();
  }

  Future<void> setPalette(AppPalette palette) async {
    if (_state.palette == palette) {
      return;
    }
    _setState(_state.copyWith(palette: palette, isLoaded: true));
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _storage.save(
        StoredAppAppearance(
          themeMode: _state.themeMode,
          palette: _state.palette,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[Appearance] step=save-failed '
        'errorType=${error.runtimeType} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void _setState(AppAppearanceState value) {
    _state = value;
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
