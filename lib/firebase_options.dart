// File generated manually for web testing.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // Pre mobilné platformy vrátime dočasnú webovú konfiguráciu,
    // aby sa predišlo chybám pri kompilácii.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return web;
      case TargetPlatform.iOS:
        return web;
      case TargetPlatform.macOS:
        return web;
      default:
        return web;
    }
  }

  // TOTO SÚ VAŠE FINÁLNE KONFIGURAČNÉ ÚDAJE
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyBhGZE2Zp1fsfrbCIDA_EkxiwpbaA3y8gE",
    appId: "1:709796458721:web:840af4dc4277f05b9c07a0",
    messagingSenderId: "709796458721",
    projectId: "parentfyapp",
    authDomain: "parentfyapp.firebaseapp.com",
    storageBucket: "parentfyapp.firebasestorage.app",
    measurementId: "G-C4EC6XNL73",
  );
}

