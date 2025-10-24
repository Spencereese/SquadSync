import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-key',
    appId: '1:demo:web:demo',
    messagingSenderId: 'demo',
    projectId: 'demo-project',
    authDomain: 'demo-project.firebaseapp.com',
    storageBucket: 'demo-project.appspot.com',
    measurementId: 'G-DEMO',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'demo-key',
    appId: '1:demo:android:demo',
    messagingSenderId: 'demo',
    projectId: 'demo-project',
    storageBucket: 'demo-project.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'demo-key',
    appId: '1:demo:ios:demo',
    messagingSenderId: 'demo',
    projectId: 'demo-project',
    storageBucket: 'demo-project.appspot.com',
    iosBundleId: 'com.example.codSquadApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'demo-key',
    appId: '1:demo:macos:demo',
    messagingSenderId: 'demo',
    projectId: 'demo-project',
    storageBucket: 'demo-project.appspot.com',
    iosBundleId: 'com.example.codSquadApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'demo-key',
    appId: '1:demo:windows:demo',
    messagingSenderId: 'demo',
    projectId: 'demo-project',
    storageBucket: 'demo-project.appspot.com',
  );
}
