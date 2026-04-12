import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init tile caching backend
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('peakmoto_tiles').manage.create();

  runApp(
    const ProviderScope(
      child: PeakMotoApp(),
    ),
  );
}
