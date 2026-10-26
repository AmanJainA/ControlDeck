import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/deck_app.dart';

/// Data access layer for ControlDeck app shortcuts.
///
/// This class contains persistence only. Widgets should not call Supabase or
/// SharedPreferences directly when this repository is used by a feature.
class DeckAppRepository {
  DeckAppRepository({
    SupabaseClient? client,
    SharedPreferences? preferences,
  })  : _client = client,
        _preferences = preferences;

  static const String _localStorageKey = 'controldeck.apps';
  final SupabaseClient? _client;
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  SupabaseClient? get _cloudClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<DeckApp>> load({String? ownerId}) async {
    if (ownerId != null) {
      final client = _cloudClient;
      if (client == null) {
        throw StateError('Supabase is not initialized.');
      }

      final rows = await client
          .from('controldeck_apps')
          .select()
          .eq('owner_id', ownerId)
          .order('sort_order')
          .order('name');

      if (rows.isNotEmpty) {
        return rows
            .map((row) => DeckApp.fromJson(Map<String, dynamic>.from(row)))
            .toList();
      }

      final defaults = starterApps();
      await client.from('controldeck_apps').insert(
            defaults.map((app) => app.toJson(ownerId: ownerId)).toList(),
          );
      return defaults;
    }

    final prefs = await _prefs;
    final raw = prefs.getString(_localStorageKey);
    if (raw == null || raw.isEmpty) return starterApps();

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved app shortcuts must be a list.');
    }

    return decoded
        .map((row) => DeckApp.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> saveAll(List<DeckApp> apps, {String? ownerId}) async {
    if (ownerId != null) {
      final client = _cloudClient;
      if (client == null) {
        throw StateError('Supabase is not initialized.');
      }

      for (final app in apps) {
        await client
            .from('controldeck_apps')
            .update(app.toJson(ownerId: ownerId))
            .eq('id', app.id)
            .eq('owner_id', ownerId);
      }
      return;
    }

    final prefs = await _prefs;
    await prefs.setString(
      _localStorageKey,
      jsonEncode(apps.map((app) => app.toJson()).toList()),
    );
  }

  Future<void> insert(DeckApp app, {String? ownerId}) async {
    if (ownerId == null) return;
    final client = _cloudClient;
    if (client == null) throw StateError('Supabase is not initialized.');
    await client.from('controldeck_apps').insert(app.toJson(ownerId: ownerId));
  }

  Future<void> delete(DeckApp app, {String? ownerId}) async {
    if (ownerId == null) return;
    final client = _cloudClient;
    if (client == null) throw StateError('Supabase is not initialized.');
    await client
        .from('controldeck_apps')
        .delete()
        .eq('id', app.id)
        .eq('owner_id', ownerId);
  }
}
