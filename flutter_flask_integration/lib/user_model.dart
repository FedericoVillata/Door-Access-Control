import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String username;
  String token;
  String? currentCompany;
  String? currentRole;
  String? userRole;
  String? emulatedRole;

  User({
    required this.username,
    required this.token,
    this.currentCompany,
    this.currentRole,
    this.userRole,
    this.emulatedRole,
  });

  void setCurrentCompany(String company) {
    currentCompany = company;
  }

  void setCurrentRole(String role) {
    currentRole = role;
  }

  void setEmulatedRole(String role) {
    emulatedRole = role;
  }
}

class UserProvider with ChangeNotifier {
  User? _user;
  User? _emulatedUser;
  String? _originalUsername;
  String? _originalToken;
  List<String> _companies = [];
  String? _selectedCompany;

  User? get user => _user;
  User? get emulatedUser => _emulatedUser;
  List<String> get companies => _companies;
  String? get selectedCompany => _selectedCompany;

  UserProvider() {
    _loadUserFromPreferences();
  }

  void setUser(User user) async {
    _user = user;
    _emulatedUser = null;
    _originalUsername = null;
    _originalToken = null;
    notifyListeners();
    await _saveUserToPreferences();
  }

  void setEmulatedUser(String username, [String? role]) async {
    final prefs = await SharedPreferences.getInstance();
    _originalUsername = _user?.username;
    _originalToken = _user?.token;
    final token = prefs.getString('authToken');
    _emulatedUser = User(username: username, token: token ?? '', emulatedRole: role);
    notifyListeners();
    await _saveUserToPreferences();
  }

  void updateToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (_user != null) {
      _user!.token = token;
    }
    if (_emulatedUser != null) {
      _emulatedUser!.token = token;
    }
    await prefs.setString('authToken', token);
    notifyListeners();
  }

  void stopEmulation() async {
    final prefs = await SharedPreferences.getInstance();
    if (_originalToken != null) {
      await prefs.setString('authToken', _originalToken!);
      _user = User(username: _originalUsername!, token: _originalToken!);
      _emulatedUser = null;
      _originalUsername = null;
      _originalToken = null;
      notifyListeners();
      await _saveUserToPreferences();
    }
  }

  String? getEmulatedUsername() {
    return _emulatedUser?.username;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    if (_emulatedUser != null && _originalToken != null) {
      await prefs.setString('authToken', _originalToken!);
      _user = User(username: _originalUsername!, token: _originalToken!);
      _emulatedUser = null;
      _originalUsername = null;
      _originalToken = null;
      notifyListeners();
    } else {
      _user = null;
      _emulatedUser = null;
      _originalUsername = null;
      _originalToken = null;
      await prefs.remove('authToken');
      await prefs.remove('currentCompany');
      await prefs.remove('currentRole');
      notifyListeners();
    }
    await _saveUserToPreferences();
  }

  void setSelectedCompany(String company) {
    _selectedCompany = company;
    notifyListeners();
  }

  Future<void> _saveUserToPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user != null) {
      prefs.setString('authToken', _user!.token);
      prefs.setString('username', _user!.username);
    } else {
      prefs.remove('authToken');
      prefs.remove('username');
    }
    if (_emulatedUser != null) {
      prefs.setString('emulatedUsername', _emulatedUser!.username);
      prefs.setString('emulatedRole', _emulatedUser!.emulatedRole ?? '');
    } else {
      prefs.remove('emulatedUsername');
      prefs.remove('emulatedRole');
    }
  }

  Future<void> _loadUserFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    final username = prefs.getString('username');
    final emulatedUsername = prefs.getString('emulatedUsername');
    final emulatedRole = prefs.getString('emulatedRole');
    if (token != null && username != null) {
      _user = User(username: username, token: token);
      if (emulatedUsername != null) {
        _emulatedUser = User(username: emulatedUsername, token: token, emulatedRole: emulatedRole);
      }
      notifyListeners();
    }
  }
}
