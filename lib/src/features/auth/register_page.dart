import 'package:flutter/material.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/shared/misc.dart';
import 'package:students_reminder/src/shared/routes.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _group = 'mobile'; //    'mobile'  |  'web'
  bool _busy = false;

  Future<void> _register() async {
    setState(() => _busy = true);
    try {
      await AuthService.instance.register(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        courseGroup: _group,
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.main);
    } catch (e) {
      displaySnackBar(context, 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Registration')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _first,
              decoration: InputDecoration(labelText: 'First name'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _last,
              decoration: InputDecoration(labelText: 'Last name'),
            ),
            SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'mobile', label: Text('Mobile')),
                ButtonSegment(value: 'web', label: Text('Web')),
              ],
              selected: {_group},
              onSelectionChanged: (sel) => setState(() => _group = sel.first),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _email,
              decoration: InputDecoration(labelText: 'Email address'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _phone,
              decoration: InputDecoration(labelText: 'Phone #'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: InputDecoration(labelText: 'Password'),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy ? null : _register,
              child: _busy
                  ? CircularProgressIndicator()
                  : Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
