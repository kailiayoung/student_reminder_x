import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/firebase_options.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/session_manager.dart';

Future<void> initFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (await SessionManager.isExpired()) {
    await AuthService.instance.logout();
  }
}
