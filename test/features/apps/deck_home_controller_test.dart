import 'package:flutter_test/flutter_test.dart';
import 'package:controldeck/features/apps/controllers/deck_home_controller.dart';
import 'package:controldeck/features/apps/models/deck_app.dart';
import 'package:controldeck/features/apps/repositories/deck_app_repository.dart';

void main() {
  group('DeckHomeController', () {
    late FakeDeckAppRepository repository;
    late DeckHomeController controller;

    setUp(() {
      repository = FakeDeckAppRepository(seed: [
        DeckApp(
          id: 'notes',
          name: 'Notes',
          description: 'Capture ideas',
          category: 'Personal',
          url: '',
        ),
        DeckApp(
          id: 'railways',
          name: 'Railways',
          description: 'Railway operations',
          category: 'Professional',
          url: '',
        ),
      ]);
      controller = DeckHomeController(repository: repository);
    });

    tearDown(() => controller.dispose());

    test('loads records and filters by search query', () async {
      await controller.load();

      expect(controller.apps, hasLength(2));
      controller.setQuery('ideas');

      expect(controller.filteredApps, hasLength(1));
      expect(controller.filteredApps.single.id, 'notes');
    });

    test('rolls back a new app when persistence fails', () async {
      await controller.load();
      repository.failWrites = true;
      final newApp = DeckApp(
        id: 'portfolio',
        name: 'Portfolio',
        description: 'Projects',
        category: 'Creative',
        url: '',
      );

      await expectLater(
        controller.save(newApp, isNew: true),
        throwsA(isA<StateError>()),
      );

      expect(controller.apps.map((app) => app.id), ['notes', 'railways']);
    });

    test('rolls back favorite state when persistence fails', () async {
      await controller.load();
      final notes = controller.apps.first;
      repository.failWrites = true;

      await expectLater(
        controller.toggleFavorite(notes),
        throwsA(isA<StateError>()),
      );

      expect(notes.favorite, isFalse);
    });
  });
}

class FakeDeckAppRepository extends DeckAppRepository {
  FakeDeckAppRepository({required this.seed});

  final List<DeckApp> seed;
  bool failWrites = false;

  @override
  Future<List<DeckApp>> load({String? ownerId}) async => List.of(seed);

  @override
  Future<void> saveAll(List<DeckApp> apps, {String? ownerId}) async {
    if (failWrites) throw StateError('Simulated persistence failure');
  }

  @override
  Future<void> insert(DeckApp app, {String? ownerId}) async {
    if (failWrites) throw StateError('Simulated persistence failure');
  }

  @override
  Future<void> delete(DeckApp app, {String? ownerId}) async {
    if (failWrites) throw StateError('Simulated persistence failure');
  }
}
