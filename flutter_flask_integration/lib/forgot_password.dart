import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'reset_password.dart';
import 'config.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  String _forgotPasswordMessage = '';
  bool _isCodeSent = false;

  Future<void> _sendResetCode() async {
    final url = Uri.parse('$BASE_URL/forgot_password');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'email': _emailController.text,
    });

    print('Sending request to: $url');
    print('Request body: $body');

    final response = await http.post(url, headers: headers, body: body);

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _forgotPasswordMessage = data['message'];
        _isCodeSent = true;
      });
    } else {
      setState(() {
        _forgotPasswordMessage = 'Error sending reset code: ${response.statusCode}';
        _isCodeSent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
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
            ElevatedButton(
              onPressed: _sendResetCode,
              child: const Text('Send Reset Code'),
            ),
            const SizedBox(height: 16.0),
            Text(_forgotPasswordMessage),
            const SizedBox(height: 16.0),
            if (_isCodeSent)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ResetPasswordPage(),
                    ),
                  );
                },
                child: const Text('Reset Password'),
              ),
          ],
        ),
      ),
    );
  }
}
