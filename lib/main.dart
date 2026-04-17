import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // google-services.json handles config on Android — just call initializeApp()
  // with no options so it reads from the native config automatically.
  // Passing explicit options on top of google-services.json causes a
  // "duplicate-app" crash because the Android SDK auto-initializes first.
  await Firebase.initializeApp();

  runApp(
    const ProviderScope(
      child: TenMinRescueApp(),
    ),
  );
}
