import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'saved_route.dart';
import 'saved_routes_service.dart';

final savedRoutesServiceProvider = Provider((_) => SavedRoutesService());

final savedRoutesProvider =
    StateNotifierProvider<SavedRoutesNotifier, List<SavedRoute>>((ref) {
  return SavedRoutesNotifier(ref.read(savedRoutesServiceProvider));
});

class SavedRoutesNotifier extends StateNotifier<List<SavedRoute>> {
  final SavedRoutesService _service;

  SavedRoutesNotifier(this._service) : super([]);

  Future<void> load() async {
    state = await _service.loadAll();
  }

  Future<void> save(SavedRoute route) async {
    await _service.save(route);
    state = await _service.loadAll();
  }

  Future<void> delete(String id) async {
    await _service.delete(id);
    state = await _service.loadAll();
  }
}
