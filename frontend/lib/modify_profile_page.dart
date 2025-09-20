import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ModifyProfilePage extends StatefulWidget {
  @override
  _ModifyProfilePageState createState() => _ModifyProfilePageState();
}

class _ModifyProfilePageState extends State<ModifyProfilePage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController fiscalCodeController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController flagPhoneController = TextEditingController();
  final TextEditingController flagMailController = TextEditingController();
  final TextEditingController googleAuthenticatorController = TextEditingController();
  final TextEditingController RFIDnumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    final url = Uri.parse('$BASE_URL/get_details');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == true) {
        final userDetails = data['user_details'];
        setState(() {
          nameController.text = userDetails['nome'] ?? '';
          surnameController.text = userDetails['cognome'] ?? '';
          fiscalCodeController.text = userDetails['fiscal_code'] ?? '';
          phoneNumberController.text = (userDetails['phone_number'] ?? '').toString();
          emailController.text = userDetails['mail'] ?? '';
          addressController.text = userDetails['address'] ?? '';
          birthDateController.text = userDetails['birth_date'] ?? '';
          genderController.text = userDetails['gender'] ?? '';
          flagPhoneController.text = (userDetails['flag_phone'] ?? '').toString();
          flagMailController.text = (userDetails['flag_mail'] ?? '').toString();
          googleAuthenticatorController.text = userDetails['google_authenticator'] ?? '';
          RFIDnumberController.text = userDetails['token'] ?? '';
        });
      } else {
        _showErrorDialog(data['message']);
      }
    } else {
      _showErrorDialog('Error loading user details: ${response.statusCode}');
    }
  }

  Future<void> updateProfile() async {
    if (!_validateForm()) {
      _showErrorDialog('Please correct the errors in the form.');
      return;
    }

    final url = Uri.parse('$BASE_URL/update_user');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final response = await http.post(url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': userProvider.emulatedUser?.username ?? userProvider.user?.username,
        'nome': nameController.text,
        'cognome': surnameController.text,
        'fiscal_code': fiscalCodeController.text,
        'phone_number': phoneNumberController.text,
        'mail': emailController.text,
        'address': addressController.text,
        'birth_date': birthDateController.text,
        'gender': genderController.text,
        'flag_phone': flagPhoneController.text,
        'flag_mail': flagMailController.text,
        'google_authenticator': googleAuthenticatorController.text,
        'token': RFIDnumberController.text,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['status'] == true) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Success'),
            content: Text('Profile updated successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      } else {
        _showErrorDialog(responseData['message']);
      }
    } else {
      _showErrorDialog('Error during update: ${response.statusCode}');
    }
  }

  bool _validateForm() {
    bool isValid = true;

    if (!emailController.text.contains('@')) {
      isValid = false;
      // Show error message for email field
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid email format')),
      );
    }
    if (phoneNumberController.text.isNotEmpty && phoneNumberController.text.length != 10) {
      isValid = false;
      // Show error message for phone number field
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must be 10 digits')),
      );
    }

    return isValid;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  TextField _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        contentPadding: const EdgeInsets.all(12.0),
      ),
    );
  }

  Future<void> _changePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Change Password'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildTextField(oldPasswordController, 'Old Password'),
                SizedBox(height: 8.0),
                _buildTextField(newPasswordController, 'New Password'),
                SizedBox(height: 8.0),
                _buildTextField(confirmPasswordController, 'Confirm Password'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Submit'),
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  _showErrorDialog('Passwords do not match.');
                } else {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('authToken');
                  final response = await http.post(
                    Uri.parse('$BASE_URL/change_password'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token',
                    },
                    body: jsonEncode({
                      'old_password': oldPasswordController.text,
                      'new_password': newPasswordController.text,
                    }),
                  );

                  if (response.statusCode == 200) {
                    final responseData = jsonDecode(response.body);
                    if (responseData['status'] == true) {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Success'),
                          content: Text('Password changed successfully.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('OK'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      _showErrorDialog(responseData['message']);
                    }
                  } else {
                    _showErrorDialog('Error during password change: ${response.statusCode}');
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Modify Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTextField(nameController, 'Name'),
            SizedBox(height: 8.0),
            _buildTextField(surnameController, 'Surname'),
            SizedBox(height: 8.0),
            _buildTextField(fiscalCodeController, 'Fiscal code'),
            SizedBox(height: 8.0),
            _buildTextField(phoneNumberController, 'Phone number'),
            SizedBox(height: 8.0),
            _buildTextField(emailController, 'Mail'),
            SizedBox(height: 8.0),
            _buildTextField(addressController, 'Address'),
            SizedBox(height: 8.0),
            _buildTextField(birthDateController, 'Birth date'),
            SizedBox(height: 8.0),
            _buildTextField(genderController, 'Gender'),
            SizedBox(height: 8.0),
            _buildTextField(RFIDnumberController, 'token'),
            SizedBox(height: 8.0),
            // _buildTextField(flagPhoneController, 'Flag phone'),
            // SizedBox(height: 8.0),
            // _buildTextField(flagMailController, 'Flag mail'),
            // SizedBox(height: 8.0),
            // _buildTextField(googleAuthenticatorController, 'Google Authenticator'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _changePasswordDialog,
              child: Text('Modify Password'),
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: updateProfile, child: Text('Update Profile')),
          ],
        ),
      ),
    );
  }
}
