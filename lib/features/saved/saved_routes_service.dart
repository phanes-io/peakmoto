import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'saved_route.dart';

class SavedRoutesService {
  static const _fileName = 'saved_routes.json';

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<SavedRoute>> loadAll() async {
    try {
      final file = await _file;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      return list
          .map((e) => SavedRoute.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> save(SavedRoute route) async {
    final routes = await loadAll();
    routes.removeWhere((r) => r.id == route.id);
    routes.insert(0, route);
    await _writeAll(routes);
  }

  Future<void> delete(String id) async {
    final routes = await loadAll();
    routes.removeWhere((r) => r.id == id);
    await _writeAll(routes);
  }

  Future<void> _writeAll(List<SavedRoute> routes) async {
    final file = await _file;
    final json = jsonEncode(routes.map((r) => r.toJson()).toList());
    await file.writeAsString(json);
  }
}
