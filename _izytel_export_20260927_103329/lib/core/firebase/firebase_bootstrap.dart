import 'package:cabine_flow/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    _configureMobileFirestorePersistence();
  }

  static void _configureMobileFirestorePersistence() {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    // Android/iOS disposent deja d'un cache Firestore persistant par defaut,
    // mais la Phase 3 le rend explicite afin qu'une future configuration ne
    // puisse pas le desactiver silencieusement. Sur le Web, on garde le cache
    // memoire par defaut : un cache persistant navigateur survit aux sessions
    // et ne doit pas etre active implicitement sur un appareil partage.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }
}
