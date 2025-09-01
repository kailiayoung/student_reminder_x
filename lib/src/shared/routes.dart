import 'package:flutter/material.dart';
import 'package:students_reminder/src/features/auth/login_page.dart';
import 'package:students_reminder/src/features/auth/register_page.dart';
import 'package:students_reminder/src/features/profile/student_profile_page.dart';
import 'package:students_reminder/src/shared/main_layout.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const main = '/main';

  static Route<dynamic> onGenerateRoute(RouteSettings setting) {
      //Expecting /student/:uid
      //              /student/12345
      //              /student/
    final url = Uri.parse(setting.name ?? '');
    if (url.pathSegments.isNotEmpty && url.pathSegments[0] == 'student') {
      final uid = url.pathSegments.length > 1 ? url.pathSegments[1] : '';
      return MaterialPageRoute(builder: (_) => StudentProfilePage(uid: uid));
    }

    switch (setting.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case main:
        return MaterialPageRoute(builder: (_) => const MainLayoutPage());
      default:
        return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }
}
