import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Temporary Firebase options used when running on web.
///
/// These values are sourced from `android/app/google-services.json` so web can
/// initialize Firebase instead of crashing with a null-options assertion.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAqJpCnVpFigv6zUcNWLIcFcyOpxpi6QdY',
    appId: '1:703234097428:web:c0ea165bdb4e476f47c201',
    messagingSenderId: '703234097428',
    projectId: 'smse-management',
    storageBucket: 'smse-management.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAqJpCnVpFigv6zUcNWLIcFcyOpxpi6QdY',
    appId: '1:703234097428:android:c0ea165bdb4e476f47c201',
    messagingSenderId: '703234097428',
    projectId: 'smse-management',
    storageBucket: 'smse-management.firebasestorage.app',
  );
}
