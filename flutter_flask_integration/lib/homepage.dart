import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:fl_chart/fl_chart.dart';
import 'user_model.dart';
import 'company_page.dart';
import 'registration_page.dart';
import 'config.dart';
import 'user_model.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const HomePage({Key? key, this.arguments}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, String>> _companies = [];
  bool _isLoggedIn = false;
  bool _isSA = false;
  bool _isEmulating = false;
  String _username = '';
  List<String> _usernames = [];
  List<String> _companyNames = [];
  String _statusMessage = '';
  String _selectedCategory = 'My Profile'; // Default category

  int _largeCompanies = 0;
  int _mediumCompanies = 0;
  int _smallCompanies = 0;

  @override
  void initState() {
    super.initState();
    if (widget.arguments != null && widget.arguments!.containsKey('username')) {
      _username = widget.arguments!['username'];
      _isLoggedIn = true;
    }
    _checkLoginStatus().then((_) {
      _loadCompanies();
    });
  }

  Future<void> _loadCompanies() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) {
      print('No token found');
      return; // Handle null token case
    }

    final url = Uri.parse('$BASE_URL/get_companies');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',  // Ensure the correct token is used
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('companies') && data['companies'] is List && (data['companies'] as List).isNotEmpty) {
        setState(() {
          _companies = List<Map<String, String>>.from(
            (data['companies'] as List).map(
              (company) => {
                'name': company['name'] as String? ?? '',
                'role': company['role'] as String? ?? ''
              },
            ),
          );
        });
        print('Companies loaded for token: $token');
      } else {
        setState(() {
          _companies = [];
        });
      }
    } else {
      setState(() {
        _companies = []; // Reset or show error
      });
      print('Failed to load companies: ${response.statusCode}');
    }
  }

  Future<void> _loadCompanySizes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) return; // Handle null token case

    final url = Uri.parse('$BASE_URL/company_sizes');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _largeCompanies = data['large_companies'];
        _mediumCompanies = data['medium_companies'];
        _smallCompanies = data['small_companies'];
      });
    } else {
      print('Failed to load company sizes: ${response.body}');
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token != null) {
      final decodedToken = JwtDecoder.decode(token);
      final isSA = decodedToken['is_sa'] == true;
      setState(() {
        _isLoggedIn = true;
        _isSA = isSA;
        _username = decodedToken['username'] ?? '';
        _isEmulating = decodedToken.containsKey('original_username');
      });
      prefs.setBool('isSA', isSA);  // Store the isSA flag in SharedPreferences
      Provider.of<UserProvider>(context, listen: false).setUser(User(username: _username, token: token));
    } else {
      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  Future<void> _removeCompany() async {
    final TextEditingController _companyController = TextEditingController();
    String _statusMessage = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Company'),
          content: TextField(
            controller: _companyController,
            decoration: const InputDecoration(labelText: 'Company Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('authToken');
                if (token == null) {
                  setState(() {
                    _statusMessage = 'No auth token found';
                  });
                  return;
                }

                final response = await http.post(
                  Uri.parse('$BASE_URL/remove_company'),
                  headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                  body: jsonEncode({'companyName': _companyController.text}),
                );

                if (response.statusCode == 200) {
                  final Map<String, dynamic> responseData = jsonDecode(response.body);
                  setState(() {
                    _statusMessage = responseData['message'];
                  });
                } else {
                  setState(() {
                    _statusMessage = 'Error removing company: ${response.reasonPhrase}';
                  });
                }

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_statusMessage)));
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getUsernames() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) return; // Handle null token case
    final url = Uri.parse('$BASE_URL/get_users');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _usernames = List<String>.from(data['usernames']);
      });
      _showUsernamesDialog();
    } else {
      print('Failed to load usernames');
    }
  }

  void _showUsernamesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Users'),
          content: SingleChildScrollView(
            child: ListBody(
              children: _usernames.map((username) {
                return ListTile(
                  title: Text(username),
                  onTap: () {
                    Navigator.of(context).pop();
                    _emulateUser(username);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _emulateUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) return; // Handle null token case
    await prefs.setString('originalToken', token); // Save original token
    final url = Uri.parse('$BASE_URL/emulate_user');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': username,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String newToken = data['token'];
      await prefs.setString('authToken', newToken);  // Save new token
      setState(() {
        _username = username;
        _isSA = false; // Emulated user is not an SA
        _isEmulating = true; // Indicate emulation
      });
      Provider.of<UserProvider>(context, listen: false).setEmulatedUser(username);
      Provider.of<UserProvider>(context, listen: false).updateToken(newToken); // Update token in provider
      _loadCompanies();
    } else {
      print('Failed to emulate user');
    }
  }

  Future<void> _logoutAndNavigateToHomePage(BuildContext context) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final originalToken = prefs.getString('originalToken'); // Get original token if exists
      final url = Uri.parse('$BASE_URL/logout');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'token': token}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final originalUsername = data['original_username'];
        await prefs.setString('authToken', originalToken ?? ''); // Restore original token if exists
        await userProvider.logout(); // Use updated logout
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
          arguments: {'username': originalUsername}, // Pass original username as argument
        );
      } else {
        print('Error logging out: ${response.statusCode}');
      }
    } catch (e) {
      print('Error logging out: $e');
    }
  }

  Future<void> _changeRole() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    final TextEditingController _usernameController = TextEditingController();
    final TextEditingController _companyController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: _companyController,
                decoration: const InputDecoration(labelText: 'Company Name'),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                String username = _usernameController.text;
                String company = _companyController.text;

                if (username.isEmpty || company.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username and company name are required')),
                  );
                  return;
                }

                Navigator.of(context).pop();
                await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Select New Role'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () => _updateRole(username, company, 'SA', token),
                            child: const Text('SA'),
                          ),
                          ElevatedButton(
                            onPressed: () => _updateRole(username, company, 'CA', token),
                            child: const Text('CA'),
                          ),
                          ElevatedButton(
                            onPressed: () => _updateRole(username, company, 'CO', token),
                            child: const Text('CO'),
                          ),
                          ElevatedButton(
                            onPressed: () => _updateRole(username, company, 'USR', token),
                            child: const Text('USR'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              child: const Text('Next'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateRole(String username, String company, String role, String? token) async {
    final url = Uri.parse('$BASE_URL/change_role');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': username,
        'company': company,
        'role': role,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role updated successfully')),
      );
    } else {
      final errorMsg = jsonDecode(response.body)['message'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update role: $errorMsg')),
      );
    }
  }

  Future<void> _enrollUser() async {
    final TextEditingController _usernameController = TextEditingController();
    final TextEditingController _companyNameController = TextEditingController();
    String _selectedRole = 'USR';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Enroll User'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: _usernameController, decoration: InputDecoration(labelText: 'Username')),
                    TextField(controller: _companyNameController, decoration: InputDecoration(labelText: 'Company Name')),
                    DropdownButton<String>(
                      value: _selectedRole,
                      icon: const Icon(Icons.arrow_downward),  // Add this line for the downward arrow
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedRole = newValue!;
                        });
                      },
                      items: <String>['SA', 'CA', 'CO', 'USR'].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('authToken');
                    final url = Uri.parse('$BASE_URL/enroll_user');
                    final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
                    final body = jsonEncode({
                      'username': _usernameController.text,
                      'companyName': _companyNameController.text,
                      'role': _selectedRole,
                      'current_user_role': 'SA'
                    });

                    final response = await http.post(url, headers: headers, body: body);

                    Navigator.of(context).pop(); // Chiudi la finestra di dialogo
                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
                    } else {
                      final errorMsg = jsonDecode(response.body)['message'];
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error during enrollment: $errorMsg')));
                    }
                  },
                  child: const Text('Enroll'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeUser() async {
    final TextEditingController _usernameController = TextEditingController();
    String _statusMessage = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove User'),
          content: TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('authToken');
                if (token == null) {
                  setState(() {
                    _statusMessage = 'No auth token found';
                  });
                  return;
                }

                final response = await http.post(
                  Uri.parse('$BASE_URL/remove_user'),
                  headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                  body: jsonEncode({'username': _usernameController.text}),
                );

                if (response.statusCode == 200) {
                  final Map<String, dynamic> responseData = jsonDecode(response.body);
                  setState(() {
                    _statusMessage = responseData['message'];
                  });
                } else {
                  setState(() {
                    _statusMessage = 'Error removing user: ${response.reasonPhrase}';
                  });
                }

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_statusMessage)));
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) return; // Handle null token case

    final url = Uri.parse('$BASE_URL/get_all_users');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _usernames = List<String>.from(data['usernames']);
      });
      _showUserListDialog();
    } else {
      print('Failed to load users: ${response.body}');
    }
  }

  void _showUserListDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('User List'),
          content: SingleChildScrollView(
            child: ListBody(
              children: _usernames.map((username) {
                return ListTile(
                  title: Text(username),
                  onTap: () {
                    Navigator.of(context).pop();
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    final emulatedUsername = userProvider.getEmulatedUsername();
                    final effectiveUsername = emulatedUsername ?? username;

                    // Utilizza effectiveUsername dove necessario
                    _getUserDetails(effectiveUsername);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getUserDetails(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) return; // Handle null token case

    final url = Uri.parse('$BASE_URL/get_user_details?username=$username');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Usa il token per l'autenticazione
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _showUserDetailsDialog(data['user_details']);
    } else {
      print('Failed to load user details: ${response.body}');
    }
  }

  void _showUserDetailsDialog(Map<String, dynamic> userDetails) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('User Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: userDetails.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text('${entry.key}: ${entry.value}'),
                );
              }).toList(),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getAllCompanies() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) {
      print('No token found');
      return; // Handle null token case
    }

    final url = Uri.parse('$BASE_URL/get_all_companies');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _companyNames = List<String>.from(data['company_names']);
        });
        _showCompanyListDialog();
      } else {
        print('Failed to load companies: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching companies: $e');
    }
  }

  void _showCompanyListDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Company List'),
          content: SingleChildScrollView(
            child: ListBody(
              children: _companyNames.map((companyName) {
                return ListTile(
                  title: Text(companyName),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    if (userProvider.emulatedUser != null) {
                      userProvider.stopEmulation();
                    }
                    await _getCompanyDetails(companyName);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getCompanyDetails(String companyName) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) return; // Handle null token case

    final url = Uri.parse('$BASE_URL/get_company_details?companyName=$companyName');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _showCompanyDetailsDialog(data['company_details']);
    } else {
      print('Failed to load company details: ${response.body}');
    }
  }

  void _showCompanyDetailsDialog(Map<String, dynamic> companyDetails) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Company Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: companyDetails.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text('${entry.key}: ${entry.value}'),
                );
              }).toList(),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatisticsChart() {
  return BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: (_largeCompanies > _mediumCompanies ? _largeCompanies : _mediumCompanies).toDouble() + 1,
      barGroups: [
        BarChartGroupData(
          x: 0,
          barRods: [
            BarChartRodData(toY: _smallCompanies.toDouble(), color: Colors.blue, width: 22),
          ],
          showingTooltipIndicators: [0],
        ),
        BarChartGroupData(
          x: 1,
          barRods: [
            BarChartRodData(toY: _mediumCompanies.toDouble(), color: Colors.orange, width: 22),
          ],
          showingTooltipIndicators: [0],
        ),
        BarChartGroupData(
          x: 2,
          barRods: [
            BarChartRodData(toY: _largeCompanies.toDouble(), color: Colors.red, width: 22),
          ],
          showingTooltipIndicators: [0],
        ),
      ],
      borderData: FlBorderData(
        show: false,
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (double value, TitleMeta meta) {
              if (value == value.toInt()) {
                return Text(value.toInt().toString());
              } else {
                return Container();
              }
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (double value, TitleMeta meta) {
              switch (value.toInt()) {
                case 0:
                  return Text('Small Compnay');
                case 1:
                  return Text('Medium Company');
                case 2:
                  return Text('Large Company');
                default:
                  return Text('');
              }
            },
          ),
        ),
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await userProvider.logout();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar
              NavigationRail(
                selectedIndex: _getCategoryIndex(),
                onDestinationSelected: (int index) {
                  setState(() {
                    _selectedCategory = _getCategoryFromIndex(index);
                    if (_selectedCategory == 'Statistics') {
                      _loadCompanySizes();
                    }
                  });
                },
                labelType: NavigationRailLabelType.all,
                destinations: _isSA
                    ? const [
                        NavigationRailDestination(
                          icon: Icon(Icons.person),
                          label: Text('My Profile'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.details),
                          label: Text('Details'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.account_box),
                          label: Text('User Actions'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.business),
                          label: Text('Company Actions'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.bar_chart),
                          label: Text('Statistics'),
                        ),
                      ]
                    : const [
                        NavigationRailDestination(
                          icon: Icon(Icons.person),
                          label: Text('My Profile'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.business),
                          label: Text('Company Actions'),
                        ),
                      ],
              ),
              // Main content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _getCategoryIndex() {
    List<String> categories = _isSA
        ? ['My Profile', 'Details', 'User Actions', 'Company Actions', 'Statistics']
        : ['My Profile', 'Company Actions'];
    int index = categories.indexOf(_selectedCategory);
    return (index != -1) ? index : 0;
  }

  void _showCompaniesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Companies'),
          content: SingleChildScrollView(
            child: _companies.isEmpty
                ? const Text('No companies available')
                : ListBody(
                    children: _companies.asMap().entries.map((entry) {
                      final index = entry.key;
                      final company = entry.value;
                      return Column(
                        children: [
                          ElevatedButton(
                            onPressed: company['name']!.isEmpty
                                ? null
                                : () async {
                                    Provider.of<UserProvider>(context, listen: false)
                                        .user
                                        ?.setCurrentCompany(company['name']!);
                                    Provider.of<UserProvider>(context, listen: false)
                                        .user
                                        ?.setCurrentRole(company['role']!);
                                    SharedPreferences.getInstance().then(
                                      (prefs) {
                                        prefs.setString('currentCompany', company['name']!);
                                        prefs.setString('currentRole', company['role']!);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CompanyPage(
                                              companyName: company['name']!,
                                              companyRole: company['role']!,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                            child: Text(company['name']!),
                          ),
                          if (index != _companies.length - 1) SizedBox(height: 8.0), // Add spacing between buttons
                        ],
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _getCategoryFromIndex(int index) {
    List<String> categories = _isSA
        ? ['My Profile', 'Details', 'User Actions', 'Company Actions', 'Statistics']
        : ['My Profile', 'Company Actions'];
    return categories[index];
  }

  Widget _buildContent() {
    switch (_selectedCategory) {
      case 'My Profile':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _showCompaniesDialog,  // Modificato per chiamare _showCompaniesDialog
                child: const Text('Companies'),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/modifyProfile');
                },
                child: const Text('Modify Profile'),
              ),
              const SizedBox(height: 16.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isLoggedIn ? 'Welcome $_username' : 'Welcome',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'Details':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _getAllUsers,
                child: const Text('User List'),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _getAllCompanies,
                child: const Text('Company List'),
              ),
            ],
          ),
        );
      case 'User Actions':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSA)
                ElevatedButton(
                  onPressed: _getUsernames,
                  child: const Text('Emulate User'),
                ),
              const SizedBox(height: 16.0),
              if (_isSA)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegistrationPage()),
                    );
                  },
                  child: const Text('Register User'),
                ),
              const SizedBox(height: 16.0),
              if (_isSA)
                ElevatedButton(
                  onPressed: _removeUser,
                  child: const Text('Remove User'),
                ),
            ],
          ),
        );
      case 'Company Actions':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/registerCompany');
                },
                child: const Text('Register Company'),
              ),
              if (_isSA) ...[
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _enrollUser,
                  child: const Text('Enroll'),
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _changeRole,
                  child: const Text('Change Role'),
                ),
              ],
            ],
          ),
        );
      case 'Statistics':
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildStatisticsChart(),
          ),
        );
      default:
        return Container();
    }
  }
}
