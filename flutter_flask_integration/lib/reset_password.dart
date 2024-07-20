import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({Key? key}) : super(key: key);

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _temporaryPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  String _resetPasswordMessage = '';

  Future<void> _resetPassword() async {
    final url = Uri.parse('$BASE_URL/reset_password');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'email': _emailController.text,
      'temporaryPassword': _temporaryPasswordController.text,
      'newPassword': _newPasswordController.text,
    });

    print('Sending request to: $url');
    print('Request body: $body');

    final response = await http.post(url, headers: headers, body: body);

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _resetPasswordMessage = data['message'];
      });
    } else {
      setState(() {
        _resetPasswordMessage = 'Error resetting password: ${response.statusCode}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _temporaryPasswordController,
              decoration: const InputDecoration(
                labelText: 'Temporary Password',
              ),
              obscureText: false, // Rendi visibile la password temporanea
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _resetPassword,
              child: const Text('Reset Password'),
            ),
            const SizedBox(height: 16.0),
            Text(_resetPasswordMessage),
          ],
        ),
      ),
    );
  }
}
