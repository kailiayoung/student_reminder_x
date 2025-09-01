import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/services/session_manager.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> authStateChanged() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register({
    required String firstName,
    required String lastName,
    required String courseGroup, // 'web' | 'mobile'
    required String email,
    required String phone,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    await _db.collection('users').doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'courseGroup': courseGroup,
      'email': email,
      'phone': phone,
      'gender': null,
      'bio': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await SessionManager.onLoginSuccess();
    return cred;
  }

  //Login CODE
  Future<UserCredential> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await SessionManager.onLoginSuccess();
    return cred;
  }

  //Logout CODE
  Future<void> logout() async {
    await _auth.signOut();
    await SessionManager.clear();
  }

  // Password Reset CODE
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);
}
