import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

// Firebase config — matches google-services.json in android/app/
const _firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAJY7qQju0400c8_w8gc4PGE89VJJ9wfL0',
  // Replace appId after registering the Android app in Firebase Console
  // Project Settings > Your apps > click the Android app > App ID
  appId: '1:120065917182:android:57b351d933deb0c632a5af',
  messagingSenderId: '120065917182',
  projectId: 'min-rescue',
  storageBucket: 'min-rescue.firebasestorage.app',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _firebaseOptions);

  runApp(
    const ProviderScope(
      child: TenMinRescueApp(),
    ),
  );
}
