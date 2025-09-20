import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'user_model.dart';
import 'config.dart';

class StatisticsPage extends StatefulWidget {
  final String company;

  const StatisticsPage({Key? key, required this.company}) : super(key: key);

  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<dynamic> statisticsData = [];
  List<dynamic> filteredStatistics = [];
  Map<String, double> roomDurations = {};

  @override
  void initState() {
    super.initState();
    fetchStatistics();
  }

  Future<void> fetchStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.emulatedUser?.token ?? prefs.getString('authToken');
      final company = widget.company;

      print('Token being used: $token');

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/get_statistics?company=$company'),
        headers: {
          'Current-Company': company,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Response data: $responseData');
        final data = responseData['statistics'];
        setState(() {
          filteredStatistics = data;
          print('Filtered Statistics: $filteredStatistics');
          calculateRoomDurations();
        });
      } else {
        print('Failed to load statistics: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching statistics: $e');
    }
  }

  void calculateRoomDurations() {
    roomDurations.clear();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    String displayedUsername = userProvider.emulatedUser?.username ?? userProvider.user?.username ?? '';

    for (var stat in filteredStatistics) {
      if (stat['username'] == displayedUsername) {
        String room = stat['room'];
        double duration = (stat['duration'] is int) ? stat['duration'].toDouble() : stat['duration'];
        if (duration > 0) { // Filtra le stanze con durata zero
          if (roomDurations.containsKey(room)) {
            roomDurations[room] = roomDurations[room]! + duration;
          } else {
            roomDurations[room] = duration;
          }
        }
      }
    }
  }

  String formatDuration(double seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = (seconds % 60).toInt();
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    String displayedUsername = userProvider.emulatedUser?.username ?? userProvider.user?.username ?? '';

    print('Displayed Username: $displayedUsername');

    return Scaffold(
      appBar: AppBar(
        title: Text('Statistics'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Time spent in each room',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Spacer(),
                Expanded(
                  flex: 4,
                  child: PieChart(
                    PieChartData(
                      sections: roomDurations.entries.map((entry) {
                        return PieChartSectionData(
                          value: entry.value,
                          color: _getColor(entry.key),
                          radius: 50,
                          title: '',
                          titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
                Spacer(),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: roomDurations.keys.map((room) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              color: _getColor(room),
                            ),
                            SizedBox(width: 8),
                            Text(room),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Spacer(),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredStatistics.length,
              itemBuilder: (context, index) {
                final stat = filteredStatistics[index];
                if (stat['username'] == displayedUsername) {
                  double duration = (stat['duration'] is int) ? stat['duration'].toDouble() : stat['duration'];
                  if (duration > 0) { // Filtra le stanze con durata zero
                    return ListTile(
                      title: Text('Room: ${stat['room']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Check-ins: ${stat['checkins']}'),
                          Text('Duration: ${formatDuration(duration)}'),
                          Text('Date: ${stat['date']}'),
                        ],
                      ),
                    );
                  }
                }
                return Container();
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(String room) {
    switch (room) {
      case 'hall':
        return Colors.blue;
      case 'presidence':
        return Colors.green;
      case 'expo':
        return Colors.red;
      case 'office':
        return Colors.orange;
      case 'entrance':
        return Colors.purple;
      case 'SRL':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}
