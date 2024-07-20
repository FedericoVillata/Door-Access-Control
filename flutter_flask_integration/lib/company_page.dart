import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_model.dart';
import 'statistics_page.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'config.dart';

class CompanyPage extends StatefulWidget {
  final String companyName;
  final String companyRole;

  const CompanyPage({Key? key, required this.companyName, required this.companyRole}) : super(key: key);

  @override
  _CompanyPageState createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  late UserProvider userProvider;
  List<dynamic> companyUsers = [];
  String emulatedRole = '';
  bool isEmulating = false;
  String? selectedRoom;
  List<String> rooms = [];
  String displayedSection = ''; // Aggiunto per gestire la sezione visibile
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    userProvider = Provider.of<UserProvider>(context, listen: false);
    isEmulating = userProvider.emulatedUser != null;
    _checkEmulationStatusAndFetchUsers();
  }

  Future<void> _checkEmulationStatusAndFetchUsers() async {
    if (isEmulating) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      if (token != null) {
        final decodedToken = JwtDecoder.decode(token);
        emulatedRole = decodedToken['role'] ?? '';
        if (emulatedRole != 'SA') {
          await fetchCompanyUsers();
        } else {
          setState(() {
            emulatedRole = 'SA';
          });
        }
      }
    } else {
      await fetchCompanyUsers();
    }
  }

  Future<void> fetchCompanyUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = userProvider.emulatedUser?.token ?? prefs.getString('authToken'); // Usa il token dell'utente emulato se esiste
      final company = widget.companyName;
      final response = await http.get(
        Uri.parse('$BASE_URL/get_company_users?company=$company'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          companyUsers = data['users'] ?? [];
          emulatedRole = data['role'] ?? widget.companyRole;
          print('Emulated Role: $emulatedRole');
        });
      } else {
        print('Failed to load company users: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching company users: $e');
    }
  }

  Future<void> checkIn(String room) async {
    final prefs = await SharedPreferences.getInstance();
    final token = userProvider.emulatedUser?.token ?? prefs.getString('authToken'); // Usa il token dell'utente emulato se esiste
    final role = userProvider.emulatedUser?.emulatedRole ?? userProvider.user?.currentRole;
    final username = userProvider.emulatedUser?.username ?? userProvider.user?.username;
    final url = Uri.parse('$BASE_URL/check_room_access');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': username,
        'companyName': widget.companyName,
        'roomName': room,
        'role': role,
      }),
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final checkInUrl = Uri.parse('$BASE_URL/check_in');
      final checkInResponse = await http.post(
        checkInUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'username': username,
          'companyName': widget.companyName,
          'room': room,
        }),
      );

      if (checkInResponse.statusCode == 200) {
        setState(() {
          selectedRoom = room;
        });
        print('Check-in recorded/updated successfully');
      } else {
        print('Failed to check-in: ${checkInResponse.statusCode}');
      }
    } else {
      print(responseData['message']);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData['message'])));
    }
  }

  Future<void> fetchRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = userProvider.emulatedUser?.token ?? prefs.getString('authToken'); // Usa il token dell'utente emulato se esiste
      final response = await http.get(
        Uri.parse('$BASE_URL/get_rooms'),
        headers: {
          'Authorization': 'Bearer $token',
          'Current-Company': widget.companyName,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          rooms = List<String>.from(data['rooms']);
        });
      } else {
        print('Failed to fetch rooms: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching rooms: $e');
    }
  }

  Future<void> emulateUser(String username, String role) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    final url = Uri.parse('$BASE_URL/emulate_user');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': username,
        'company': widget.companyName,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String newToken = data['token'];
      await prefs.setString('authToken', newToken);
      userProvider.updateToken(newToken); // Aggiorna il token in UserProvider
      setState(() {
        userProvider.setEmulatedUser(username, role);
        isEmulating = true;
        emulatedRole = role;
      });
      print('New token after emulation: $newToken');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CompanyPage(companyName: widget.companyName, companyRole: role),
        ),
      );
    } else {
      print('Failed to emulate user: ${response.body}');
    }
  }

  void _showEmulateUserDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Emulate User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: companyUsers.map((user) {
              return ListTile(
                title: Text(user['username']),
                subtitle: Text(user['role']),
                onTap: () {
                  emulateUser(user['username'], user['role']); // Passa anche il ruolo
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
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

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
      switch (index) {
        case 0:
          displayedSection = '';
          break;
        case 1:
          displayedSection = 'room_management';
          break;
        case 2:
          displayedSection = 'user_management';
          break;
        case 3:
          displayedSection = 'company_management';
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String displayedUsername = userProvider.emulatedUser?.username ?? userProvider.user?.username ?? '';
    String displayedRole = userProvider.emulatedUser?.emulatedRole ?? userProvider.user?.currentRole ?? widget.companyRole;
    bool canEmulate = displayedRole != 'SA' && (displayedRole == 'CA' || displayedRole == 'CO');

    print('Displayed Username: $displayedUsername');
    print('Displayed Role: $displayedRole');
    print('Is Emulating: $isEmulating');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Page'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StatisticsPage(company: widget.companyName)),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          if (displayedRole != 'USR')
            NavigationRail(
  selectedIndex: _selectedIndex,
  onDestinationSelected: _onDestinationSelected,
  labelType: NavigationRailLabelType.all,
  destinations: [
    const NavigationRailDestination(
      icon: Icon(Icons.person),
      label: Text('My Profile'),
    ),
    if (['SA', 'CA', 'CO'].contains(displayedRole))
      const NavigationRailDestination(
        icon: Icon(Icons.meeting_room),
        label: Text('Room Management'),
      ),
    if (['SA', 'CA', 'CO'].contains(displayedRole))
      const NavigationRailDestination(
        icon: Icon(Icons.manage_accounts),
        label: Text('User Management'),
      ),
    if (['SA', 'CA', 'CO'].contains(displayedRole))
      const NavigationRailDestination(
        icon: Icon(Icons.business),
        label: Text('Company Management'),
      ),
  ],
  trailing: Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            print('logout');
            await _logoutAndNavigateToLoginPage(context);
          },
        ),
      ],
    ),
  ),
),

          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (displayedRole == 'USR') ...[
                      ElevatedButton(
                        onPressed: () async {
                          if (isEmulating) {
                            userProvider.stopEmulation();
                          }
                          Navigator.of(context).pop();
                        },
                        child: const Text('Back'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _showChangeCompanyDialog,
                        child: const Text('Change Company'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await fetchRooms();
                          _showRoomSelectionDialog();
                        },
                        child: const Text('Select Room'),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Logged as "$displayedUsername" for "${widget.companyName}" as "$displayedRole"',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (displayedRole != 'USR') ...[
                      if (displayedSection == '') ...[
                        ElevatedButton(
                          onPressed: () async {
                            if (isEmulating) {
                              userProvider.stopEmulation();
                            }
                            Navigator.of(context).pop();
                          },
                          child: const Text('Back'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _showChangeCompanyDialog,
                          child: const Text('Change Company'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            await fetchRooms();
                            _showRoomSelectionDialog();
                          },
                          child: const Text('Select Room'),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Logged as "$displayedUsername" for "${widget.companyName}" as "$displayedRole"',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (displayedSection == 'room_management' && ['SA', 'CA'].contains(displayedRole)) ...[
                        ElevatedButton(
                          onPressed: _showAddRoomDialog,
                          child: const Text('Add Room'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _showRemoveRoomDialog,
                          child: const Text('Remove Room'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _showPermissionRightsDialog,
                          child: const Text('Permission Rights'),
                        ),
                      ],
                      if (displayedSection == 'room_management' && displayedRole == 'CO') ...[
                        ElevatedButton(
                          onPressed: _showPermissionRightsDialog,
                          child: const Text('Permission Rights'),
                        ),
                      ],
                      if (displayedSection == 'user_management' && ['SA', 'CA', 'CO'].contains(displayedRole)) ...[
                        ElevatedButton(
                          onPressed: _showEmulateUserDialog,
                          child: const Text('Emulate User'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _showChangeRoleDialog,
                          child: const Text('Change Role'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _enrollUser,
                          child: const Text('Enroll'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _removeUser,
                          child: const Text('Remove User'),
                        ),
                      ],
                      if (displayedSection == 'company_management' && ['SA', 'CA', 'CO'].contains(displayedRole)) ...[
                        ElevatedButton(
                          onPressed: _showCompanyDetails,
                          child: const Text('Company Details'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRoomSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: rooms.map((room) {
              return ListTile(
                title: Text(room),
                onTap: () {
                  checkIn(room);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
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

  void _showCompanyDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = userProvider.emulatedUser?.token ?? prefs.getString('authToken'); // Usa il token dell'utente emulato se esiste
      final response = await http.get(
        Uri.parse('$BASE_URL/get_company_details?companyName=${widget.companyName}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['company_details'];
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Company Details'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: data.entries.map<Widget>((entry) {
                    return Text('${entry.key}: ${entry.value}');
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
      } else {
        print('Failed to load company details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching company details: $e');
    }
  }

  Future<void> _logoutAndNavigateToLoginPage(BuildContext context) async {
    try {
      print('Inizio processo di logout');
      final prefs = await SharedPreferences.getInstance();
      await userProvider.logout();
      await prefs.remove('authToken');
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print('Errore durante il logout: $e');
    }
  }

  Future<void> changeUserRole(String username, String newRole) async {
    final prefs = await SharedPreferences.getInstance();
    final token = userProvider.emulatedUser?.token ?? prefs.getString('authToken'); // Usa il token dell'utente emulato se esiste
    final response = await http.post(
      Uri.parse('$BASE_URL/change_user_role'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': username,
        'company': widget.companyName,
        'role': newRole,
      }),
    );

    final responseData = jsonDecode(response.body);
    
    if (response.statusCode == 200 && responseData['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role updated successfully')),
      );
      fetchCompanyUsers();
    } else {
      final errorMessage = responseData['message'] ?? 'Failed to change user role';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Future<void> _changeCompany(String companyName) async {
    final prefs = await SharedPreferences.getInstance();
    final token = userProvider.emulatedUser?.token ?? prefs.getString('authToken'); // Usa il token dell'utente emulato se esiste
    final response = await http.post(
      Uri.parse('$BASE_URL/change_company'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'company': companyName}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newToken = data['token'];
      await prefs.setString('authToken', newToken);
      // Ricarica la pagina CompanyPage con la nuova azienda
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CompanyPage(companyName: companyName, companyRole: data['role']),
        ),
      );
    } else {
      print('Failed to change company: ${response.statusCode}');
    }
  }

  Future<void> _showChangeCompanyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final token = userProvider.emulatedUser?.token ?? prefs.getString('authToken'); // Usa il token dell'utente emulato se esiste
    final response = await http.get(
      Uri.parse('$BASE_URL/get_companies'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<String> companyNames = List<String>.from(data['companies'].map((company) => company['name']));

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Company'),
            content: SingleChildScrollView(
              child: ListBody(
                children: companyNames.map((company) {
                  return ListTile(
                    title: Text(company),
                    onTap: () {
                      Navigator.of(context).pop();
                      _changeCompany(company);
                    },
                  );
                }).toList(),
              ),
            ),
          );
        },
      );
    } else {
      print('Failed to load companies: ${response.statusCode}');
    }
  }

  void _showChangeRoleDialog() {
    final TextEditingController _usernameController = TextEditingController();
    String? _selectedRole;

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
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'New Role'),
                items: _getRoleOptions().map((role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_usernameController.text.isNotEmpty && _selectedRole != null) {
                  changeUserRole(_usernameController.text, _selectedRole!);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  List<String> _getRoleOptions() {
    switch (widget.companyRole) {
      case 'SA':
        return ['SA', 'CA', 'CO', 'USR'];
      case 'CA':
        return ['CA', 'CO', 'USR'];
      case 'CO':
        return ['CO', 'USR'];
      default:
        return [];
    }
  }

  Future<void> _enrollUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    final TextEditingController _usernameController = TextEditingController();
    String _selectedRole = widget.companyRole == 'CA' ? 'CA' : 'CO';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enroll User'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: _usernameController, decoration: InputDecoration(labelText: 'Username')),
                DropdownButton<String>(
                  value: _selectedRole,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRole = newValue!;
                    });
                  },
                  items: (widget.companyRole == 'CA' ? ['CA', 'CO', 'USR'] : ['CO', 'USR']).map<DropdownMenuItem<String>>((String value) {
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
                  'companyName': widget.companyName,
                  'role': _selectedRole,
                });

                final response = await http.post(url, headers: headers, body: body);

                Navigator.of(context).pop(); // Chiudi la finestra di dialogo
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
                  await fetchCompanyUsers();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error during enrollment: ${response.statusCode}')));
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
  }

  Future<void> _removeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    final TextEditingController _usernameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove User'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: _usernameController, decoration: InputDecoration(labelText: 'Username')),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('authToken');
                final url = Uri.parse('$BASE_URL/remove_user_company');
                final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
                final body = jsonEncode({
                  'username': _usernameController.text,
                  'companyName': widget.companyName,
                });

                final response = await http.post(url, headers: headers, body: body);

                Navigator.of(context).pop(); // Chiudi la finestra di dialogo
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
                  await fetchCompanyUsers();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error during removing user: ${response.statusCode}')));
                }
              },
              child: const Text('Remove User'),
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
  }

  void _showAddRoomDialog() {
    final TextEditingController _roomNameController = TextEditingController();
    bool _allowedDenied = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _roomNameController,
                decoration: const InputDecoration(labelText: 'Name of the Room'),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<bool>(
                value: _allowedDenied,
                decoration: const InputDecoration(labelText: 'Allowed or Denied'),
                items: [
                  DropdownMenuItem(
                    value: true,
                    child: Text('Allowed'),
                  ),
                  DropdownMenuItem(
                    value: false,
                    child: Text('Denied'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _allowedDenied = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('authToken');
                final url = Uri.parse('$BASE_URL/add_room');
                final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
                final body = jsonEncode({
                  'roomName': _roomNameController.text,
                  'allowedDenied': _allowedDenied,
                  'companyName': widget.companyName,
                });

                final response = await http.post(url, headers: headers, body: body);

                Navigator.of(context).pop(); // Chiudi la finestra di dialogo
                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room added successfully')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding room: ${response.statusCode}')));
                }
              },
              child: const Text('Add Room'),
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
  }

  void _showPermissionRightsDialog() {
    final TextEditingController _roomNameController = TextEditingController();
    final TextEditingController _usernameController = TextEditingController();
    bool _allowedDenied = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Rights'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _roomNameController,
                decoration: const InputDecoration(labelText: 'Name of the Room'),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<bool>(
                value: _allowedDenied,
                decoration: const InputDecoration(labelText: 'Allowed or Denied'),
                items: [
                  DropdownMenuItem(
                    value: true,
                    child: Text('Allowed'),
                  ),
                  DropdownMenuItem(
                    value: false,
                    child: Text('Denied'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _allowedDenied = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('authToken');
                final url = Uri.parse('$BASE_URL/permission_rights');
                final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
                final body = jsonEncode({
                  'roomName': _roomNameController.text,
                  'username': _usernameController.text,
                  'allowedDenied': _allowedDenied ? 'allowed' : 'denied', // Convert boolean to string
                  'companyName': widget.companyName,
                });

                final response = await http.post(url, headers: headers, body: body);

                Navigator.of(context).pop(); // Chiudi la finestra di dialogo
                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permission rights updated successfully')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating permission rights: ${response.statusCode}')));
                }
              },
              child: const Text('Update Permission'),
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
  }

  void _showRemoveRoomDialog() {
    final TextEditingController _roomNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _roomNameController,
                decoration: const InputDecoration(labelText: 'Name of the Room'),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('authToken');
                final url = Uri.parse('$BASE_URL/remove_room');
                final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
                final body = jsonEncode({
                  'roomName': _roomNameController.text,
                  'companyName': widget.companyName,
                });

                final response = await http.post(url, headers: headers, body: body);

                Navigator.of(context).pop(); // Chiudi la finestra di dialogo
                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room removed successfully')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing room: ${response.statusCode}')));
                }
              },
              child: const Text('Remove Room'),
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
  }
}
