import 'package:flutter/material.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/shared/misc.dart';
import 'package:students_reminder/src/shared/routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      await AuthService.instance.login(_email.text.trim(), _password.text);
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.main);
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, 'Login Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Login')),
      body: Padding(
        padding: EdgeInsetsGeometry.all(16),
        child: Center(
          child: Column(
            children: [
              //Email
              TextField(controller: _email, decoration: InputDecoration(labelText: 'Email'),),
              SizedBox(height: 12,),
              //Password
              TextField(controller: _password, decoration: InputDecoration(labelText: 'Password'), obscureText: true,),
              SizedBox(height: 20,),
              ElevatedButton(
                onPressed: _busy ? null : _login, 
                child: _busy ? CircularProgressIndicator() : Text('Login'),
                ),
              SizedBox(height: 12,),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.register), 
                child: _busy ? CircularProgressIndicator() : Text('No Account? Register'),
                ),
            ],
          ),
        ),
        ),
    );
  }
}
