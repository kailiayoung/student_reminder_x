import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _key = 'loginState';
  static const maxAge = Duration(minutes: 35);

  //Mark that the user has  logged in
  static Future<void> onLoginSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  //Has Login State Expired
  static Future<bool> isExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_key);
    if (ts == null) return false;
    final loginTime = DateTime.fromMicrosecondsSinceEpoch(ts);
    return DateTime.now().difference(loginTime) > maxAge;
  }
}
