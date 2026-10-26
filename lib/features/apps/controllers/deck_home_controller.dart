import 'package:flutter/foundation.dart';

import '../models/deck_app.dart';
import '../repositories/deck_app_repository.dart';

/// MVC controller for the app launcher.
///
/// Owns app-list state, filtering and user actions. The View observes this
/// controller and renders its state; persistence is delegated to the repository.
class DeckHomeController extends ChangeNotifier {
  DeckHomeController({
    required DeckAppRepository repository,
    this.ownerId,
  }) : _repository = repository;

  final DeckAppRepository _repository;
  final String? ownerId;

  final List<DeckApp> _apps = <DeckApp>[];
  String _query = '';
  String _category = 'All apps';
  bool _favoritesOnly = false;
  bool _loading = false;
  bool _cloudError = false;

  List<DeckApp> get apps => List.unmodifiable(_apps);
  String get query => _query;
  String get category => _category;
  bool get favoritesOnly => _favoritesOnly;
  bool get loading => _loading;
  bool get cloudError => _cloudError;

  List<DeckApp> get filteredApps {
    final normalizedQuery = _query.trim().toLowerCase();
    return _apps.where((app) {
      final matchesCategory =
          _category == 'All apps' || app.category == _category;
      final matchesFavorite = !_favoritesOnly || app.favorite;
      final matchesQuery = normalizedQuery.isEmpty ||
          app.name.toLowerCase().contains(normalizedQuery) ||
          app.description.toLowerCase().contains(normalizedQuery) ||
          app.category.toLowerCase().contains(normalizedQuery);
      return matchesCategory && matchesFavorite && matchesQuery;
    }).toList();
  }

  Future<void> load() async {
    _loading = true;
    _cloudError = false;
    notifyListeners();
    try {
      final loaded = await _repository.load(ownerId: ownerId);
      _apps
        ..clear()
        ..addAll(loaded);
    } catch (_) {
      _cloudError = ownerId != null;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setCategory(String value) {
    if (_category == value) return;
    _category = value;
    notifyListeners();
  }

  void setFavoritesOnly(bool value) {
    if (_favoritesOnly == value) return;
    _favoritesOnly = value;
    notifyListeners();
  }

  Future<void> save(DeckApp app, {bool isNew = false}) async {
    final existingIndex = _apps.indexWhere((item) => item.id == app.id);
    final previous = existingIndex < 0 ? null : _apps[existingIndex];

    if (existingIndex < 0) {
      _apps.add(app);
    } else {
      _apps[existingIndex] = app;
    }
    notifyListeners();

    try {
      if (isNew && ownerId != null) {
        await _repository.insert(app, ownerId: ownerId);
      } else {
        await _repository.saveAll(_apps, ownerId: ownerId);
      }
    } catch (_) {
      if (existingIndex < 0) {
        _apps.removeWhere((item) => item.id == app.id);
      } else if (previous != null) {
        _apps[existingIndex] = previous;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleFavorite(DeckApp app) async {
    final previous = app.favorite;
    app.favorite = !previous;
    notifyListeners();
    try {
      await _repository.saveAll(_apps, ownerId: ownerId);
    } catch (_) {
      app.favorite = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> remove(DeckApp app) async {
    final index = _apps.indexWhere((item) => item.id == app.id);
    if (index < 0) return;
    final removed = _apps.removeAt(index);
    notifyListeners();
    try {
      if (ownerId != null) {
        await _repository.delete(app, ownerId: ownerId);
      } else {
        await _repository.saveAll(_apps, ownerId: ownerId);
      }
    } catch (_) {
      _apps.insert(index, removed);
      notifyListeners();
      rethrow;
    }
  }
}
