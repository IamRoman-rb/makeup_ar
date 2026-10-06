import 'package:flutter/material.dart';

import 'features/ar/presentation/engine_spike_screen.dart';

/// Entrypoint del spike P1 del motor AR, separado de la app (sin Firebase ni
/// RevenueCat). Medir siempre en profile:
///   `flutter run --profile -t lib/main_spike.dart -d <id>`
void main() {
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: EngineSpikeScreen()));
}
