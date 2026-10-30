// Generado por tool/generar_firebase_options.dart.
// Para regenerarlo, vuelve a ejecutar ese comando.
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError('StockPyme no está configurado para esta plataforma.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAcfr6Xq_VfJQdsZGbN-zo5Bvbts1VuvOk',
    appId: '1:942296066625:android:8384d58930ce33f6d074c0',
    messagingSenderId: '942296066625',
    projectId: 'stockpyme',
    storageBucket: 'stockpyme.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD2qmtJHMSiRBn3gdMZRghMEfqfe1EG2Tg',
    appId: '1:942296066625:web:f219a4320c713e99d074c0',
    messagingSenderId: '942296066625',
    projectId: 'stockpyme',
    authDomain: 'stockpyme.firebaseapp.com',
    storageBucket: 'stockpyme.firebasestorage.app',
    measurementId: 'G-Z7PSBM1V3T',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD2qmtJHMSiRBn3gdMZRghMEfqfe1EG2Tg',
    appId: '1:942296066625:web:f219a4320c713e99d074c0',
    messagingSenderId: '942296066625',
    projectId: 'stockpyme',
    authDomain: 'stockpyme.firebaseapp.com',
    storageBucket: 'stockpyme.firebasestorage.app',
    measurementId: 'G-Z7PSBM1V3T',
  );
}
