import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:virtual_keyboard_multi_language/virtual_keyboard_multi_language.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({Key? key}) : super(key: key);

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _fiscalCodeController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _RFIDnumberController = TextEditingController();
  final TextEditingController _flagPhoneController = TextEditingController();
  final TextEditingController _flagMailController = TextEditingController();
  final TextEditingController _googleAuthenticatorController = TextEditingController();

  late TextEditingController _activeController;
  String _registrationMessage = '';
  bool _showVirtualKeyboard = false;

  @override
  void initState() {
    super.initState();
    _activeController = _usernameController;  // Default active controller
  }

  Future<void> _completeRegistration() async {
    if (!_validateForm()) {
      setState(() {
        _registrationMessage = 'Please correct the errors in the form.';
      });
      return;
    }

    final url = Uri.parse('http://localhost:5000/api/register');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'username': _usernameController.text,
      'password': _passwordController.text,
      'nome': _nameController.text,
      'cognome': _surnameController.text,
      'fiscal_code': _fiscalCodeController.text,
      'phone_number': _phoneNumberController.text,
      'mail': _emailController.text,
      'address': _addressController.text,
      'birth_date': _birthDateController.text,
      'gender': _genderController.text,
      'token': _RFIDnumberController.text,
      "flag_phone": _flagPhoneController.text,
      'flag_mail': _flagMailController.text,
      'google_authenticator': _googleAuthenticatorController.text,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _registrationMessage = data['message'];
      });
    } else if (response.statusCode == 409) {
      setState(() {
        _registrationMessage = 'Username already exists';
      });
    } else {
      setState(() {
        _registrationMessage = 'Error during registration: ${response.statusCode}';
      });
    }
  }

  bool _validateForm() {
    bool isValid = true;

    if (!_emailController.text.contains('@')) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid email format')),
      );
    }
    if (_passwordController.text.length < 6) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
    }
    if (_phoneNumberController.text.length != 10) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must be 10 digits')),
      );
    }

    // Add more validations as needed

    return isValid;
  }

  TextField _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      onTap: () => _setActiveController(controller),
    );
  }

  void _setActiveController(TextEditingController controller) {
    setState(() {
      _activeController = controller;
    });
  }

  void _onKeyPress(VirtualKeyboardKey key) {
    if (key.keyType == VirtualKeyboardKeyType.String) {
      setState(() {
        String text = key.action == VirtualKeyboardKeyAction.Shift ? key.capsText ?? '' : key.text ?? '';
        _activeController.text += text;
      });
    } else if (key.keyType == VirtualKeyboardKeyType.Action) {
      switch (key.action) {
        case VirtualKeyboardKeyAction.Backspace:
          setState(() {
            if (_activeController.text.isNotEmpty) {
              _activeController.text = _activeController.text.substring(0, _activeController.text.length - 1);
            }
          });
          break;
        case VirtualKeyboardKeyAction.Space:
          setState(() {
            _activeController.text += ' ';
          });
          break;
        default:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _buildTextField(_usernameController, 'Username'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_passwordController, 'Password'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_nameController, 'Nome'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_surnameController, 'Cognome'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_fiscalCodeController, 'Fiscal Code'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_phoneNumberController, 'Phone Number'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _buildTextField(_emailController, 'Email'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_addressController, 'Address'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_birthDateController, 'Birth Date'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_genderController, 'Gender'),
                          const SizedBox(height: 8.0),
                           _buildTextField(_RFIDnumberController, 'token'),
                            const SizedBox(height: 8.0),
                          // _buildTextField(_flagPhoneController, 'Flag Phone'),
                          // const SizedBox(height: 8.0),
                          // _buildTextField(_flagMailController, 'Flag Mail'),
                          // const SizedBox(height: 8.0),
                          // _buildTextField(_googleAuthenticatorController, 'Google Authenticator'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _completeRegistration,
                  child: const Text('Register'),
                ),
                const SizedBox(height: 16.0),
                Text(_registrationMessage),
              ],
            ),
          ),
          if (_showVirtualKeyboard)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 300,
                color: Colors.blue,
                child: VirtualKeyboard(
                  type: VirtualKeyboardType.Alphanumeric,
                  onKeyPress: _onKeyPress,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showVirtualKeyboard = !_showVirtualKeyboard;
          });
        },
        child: const Icon(Icons.keyboard),
      ),
    );
  }
}
