import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'registration_page.dart';
import 'forgot_password.dart';
import 'homepage.dart';
import 'package:virtual_keyboard_multi_language/virtual_keyboard_multi_language.dart';
import 'user_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_company.dart';
import 'statistics_page.dart';
import 'modify_profile_page.dart';
import 'config.dart';
import 'util.dart';
import 'theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/modifyProfile': (context) => ModifyProfilePage(),
        '/registration': (context) => const RegistrationPage(),
        '/forgotPassword': (context) => const ForgotPasswordPage(),
        '/registerCompany': (context) => const RegistrationCompanyPage(),
        '/statistics': (context) => const StatisticsPage(company: ''),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoggedIn = false;
  String _loginMessage = '';
  bool _showVirtualKeyboard = false;
  late TextEditingController _activeController;
  bool _passwordVisible = false;
  bool _isShiftEnabled = false;

  @override
  void initState() {
    super.initState();
    _activeController = _usernameController;
    _passwordVisible = false;
    _isShiftEnabled = false;
  }

  Future<void> _login() async {
    final url = Uri.parse('$BASE_URL/login');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'username': _usernameController.text,
      'password': _passwordController.text,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _loginMessage = data['message'];
      });
      if (data['status']) {
        final String token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', token);
        Provider.of<UserProvider>(context, listen: false).setUser(
          User(username: _usernameController.text, token: token),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      setState(() {
        _loginMessage = 'Error during login: ${response.statusCode}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  onTap: () => _setActiveController(_usernameController),
                ),
                const SizedBox(height: 8.0),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_passwordVisible,
                  onTap: () => _setActiveController(_passwordController),
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _isLoggedIn ? null : _login,
                  child: const Text('Login'),
                ),
                const SizedBox(height: 16.0),
                Text(_loginMessage),
                if (!_isLoggedIn)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/registration');
                    },
                    child: const Text('Register'),
                  ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/forgotPassword');
                  },
                  child: const Text('Forgot Password'),
                ),
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

  void _onKeyPress(VirtualKeyboardKey key) {
    if (key.keyType == VirtualKeyboardKeyType.String) {
      setState(() {
        String text = _isShiftEnabled
            ? (key.capsText ?? key.text?.toUpperCase() ?? '')
            : (key.text ?? '');
        _activeController.text += text;
      });
    } else if (key.keyType == VirtualKeyboardKeyType.Action) {
      switch (key.action) {
        case VirtualKeyboardKeyAction.Backspace:
          setState(() {
            if (_activeController.text.isNotEmpty) {
              _activeController.text = _activeController.text
                  .substring(0, _activeController.text.length - 1);
            }
          });
          break;
        case VirtualKeyboardKeyAction.Space:
          setState(() {
            _activeController.text += ' ';
          });
          break;
        case VirtualKeyboardKeyAction.Shift:
          setState(() {
            _isShiftEnabled = !_isShiftEnabled;
          });
          break;
        default:
          break;
      }
    }
  }

  void _setActiveController(TextEditingController controller) {
    setState(() {
      _activeController = controller;
    });
  }
}
