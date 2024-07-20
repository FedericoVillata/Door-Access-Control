import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:virtual_keyboard_multi_language/virtual_keyboard_multi_language.dart';
import 'config.dart';

class RegistrationCompanyPage extends StatefulWidget {
  const RegistrationCompanyPage({Key? key}) : super(key: key);

  @override
  _RegistrationCompanyPageState createState() => _RegistrationCompanyPageState();
}

class _RegistrationCompanyPageState extends State<RegistrationCompanyPage> {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _vatNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _PECController = TextEditingController();
  final TextEditingController _flagPhoneController = TextEditingController();
  final TextEditingController _flagMailController = TextEditingController();
  final TextEditingController _subscriptionController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  late TextEditingController _activeController;
  String _registrationCompanyMessage = '';
  bool _showVirtualKeyboard = false;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _activeController = _companyNameController;  // Default active controller
    _loadUsernameFromToken();
  }

  Future<void> _loadUsernameFromToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token != null) {
      final decodedToken = JwtDecoder.decode(token);
      setState(() {
        _username = decodedToken['username'] ?? '';
      });
    }
  }

Future<void> _completeRegistrationCompany() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    final isSA = prefs.getBool('isSA') ?? false;  // Get the isSA flag from shared preferences

    final url = Uri.parse('$BASE_URL/register_company');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'companyName': _companyNameController.text,
      'VAT_number': _vatNumberController.text,
      'phone_number': _phoneNumberController.text,
      'PEC': _emailController.text,
      'address': _addressController.text,
      'flag_phone': _flagPhoneController.text,
      'flag_mail': _flagMailController.text,
      'subscription': _subscriptionController.text,
      'country': _countryController.text,
      'username': _username,  // Use the username from the token
      'isSA': isSA,  // Pass the isSA flag to the server
    });

    final response = await http.post(url, headers: headers, body: body);

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _registrationCompanyMessage = data['message'];
      });
    } else {
      try {
        final data = jsonDecode(response.body);
        setState(() {
          _registrationCompanyMessage = data['error'] ?? 'Error during registration';
        });
      } catch (e) {
        setState(() {
          _registrationCompanyMessage = 'Unexpected error: ${response.body}';
        });
      }
    }
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
                          _buildTextField(_companyNameController, 'companyName'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_vatNumberController, 'VAT_number'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_phoneNumberController, 'phone_number'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_emailController, 'Email'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_addressController, 'address'),
                          const SizedBox(height: 8.0),
                          _buildTextField(_PECController, 'PEC'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // _buildTextField(_flagPhoneController, 'flag_phone'),
                          // const SizedBox(height: 8.0),
                          _buildTextField(_subscriptionController, 'subscription'),
                          const SizedBox(height: 8.0),
                          // _buildTextField(_flagMailController, 'flag_mail'),
                          // const SizedBox(height: 8.0),
                          _buildTextField(_countryController, 'country'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _completeRegistrationCompany,
                  child: const Text('Register'),
                ),
                const SizedBox(height: 16.0),
                Text(_registrationCompanyMessage),
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
