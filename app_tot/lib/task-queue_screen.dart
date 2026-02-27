import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Danh Sách Lệnh',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const TaskQueueScreen(),
    );
  }
}

class TaskQueueScreen extends StatefulWidget {
  const TaskQueueScreen({super.key});

  @override
  _TaskQueueScreenState createState() => _TaskQueueScreenState();
}

class Task {
  final String agvId;
  final String command;
  final String status;
  final int priority;

  Task({
    required this.agvId,
    required this.command,
    required this.status,
    required this.priority,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      agvId: json['agV_ID']?.toString() ?? 'Unknown',
      command: json['command']?.toString() ?? 'Unknown',
      status: json['status']?.toString() ?? 'Unknown',
      priority: (json['priority'] as num?)?.toInt() ?? 999,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agV_ID': agvId,
      'command': command,
      'status': status,
      'priority': priority,
    };
  }

  String getLocalizedStatus() {
    switch (status) {
      case 'Idle':
        return 'Đang chờ';
      case 'Executing':
        return 'Đang thực hiện';
      case 'Waiting':
        return 'Chờ xử lý';
      case 'Cancelled':
        return 'Đã hủy';
      case 'Completed':
        return 'Hoàn thành';
      default:
        return 'Không xác định';
    }
  }
}

class _TaskQueueScreenState extends State<TaskQueueScreen> {
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  bool _isLoading = false;
  String _lastUpdated = '';
  String _errorMessage = '';
  String _selectedAGV = 'Tất cả';
  String _selectedStatus = 'Chờ xử lý';

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _tasks = [];
      _filteredTasks = [];
    });

    try {
      final uri = Uri.parse('http://192.168.0.59:7000/api/agv/tasksQueue');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      print('API Response: ${response.body}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          final data = (jsonData['data'] as List<dynamic>?)?.map((item) => Task.fromJson(item)).toList() ?? [];
          print('Parsed Tasks: ${data.map((e) => e.toJson()).toList()}');
          setState(() {
            _tasks = data;
            _filteredTasks = _applyFilters();
            _lastUpdated = DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now());
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = jsonData['message']?.toString() ?? 'Lỗi không xác định';
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $_errorMessage'), backgroundColor: Colors.red),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Lỗi khi gọi API: ${response.statusCode}';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('Lỗi khi gọi API: $e');
      setState(() {
        _errorMessage = 'Lỗi: $e';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cancelTask(String agvId, String command) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse('http://192.168.0.59:7000/api/agv/cancel-task');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'AGV_ID': agvId,
          'Command': command,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Cancel Task Response: ${response.body}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hủy lệnh thành công'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchTasks(); // Làm mới danh sách và bộ lọc
        } else {
          setState(() {
            _errorMessage = jsonData['message']?.toString() ?? 'Lỗi khi hủy lệnh';
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $_errorMessage'), backgroundColor: Colors.red),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Lỗi khi gọi API hủy lệnh: ${response.statusCode}';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('Lỗi khi hủy lệnh: $e');
      setState(() {
        _errorMessage = 'Lỗi: $e';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  List<Task> _applyFilters() {
    List<Task> filtered = _tasks.where((task) {
      final agvMatch = _selectedAGV == 'Tất cả' || task.agvId == _selectedAGV;
      final statusMatch = _selectedStatus == 'Tất cả' || task.getLocalizedStatus() == _selectedStatus;
      return agvMatch && statusMatch;
    }).toList();

    // Sắp xếp theo priority cho trạng thái Waiting
    if (_selectedStatus == 'Chờ xử lý') {
      filtered.sort((a, b) => a.priority.compareTo(b.priority));
    }

    return filtered;
  }

  List<String> _getAGVOptions() {
    final agvs = _tasks.map((task) => task.agvId).toSet().toList();
    return ['Tất cả', ...agvs];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        leading: IconButton(
          //icon: const Icon(Icons.arrow_back, color: Colors.white),
          icon: const Icon(Icons.home, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Danh Sách Lệnh AGV',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue, Colors.lightBlue],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchTasks,
            tooltip: 'Làm mới dữ liệu',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cập nhật: $_lastUpdated',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedAGV,
                            decoration: InputDecoration(
                              labelText: 'Lọc theo AGV',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[600]!),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: _getAGVOptions().map((agv) {
                              return DropdownMenuItem<String>(
                                value: agv,
                                child: Text(agv),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedAGV = value ?? 'Tất cả';
                                _filteredTasks = _applyFilters();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: InputDecoration(
                              labelText: 'Lọc theo trạng thái',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[600]!),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: [
                              'Tất cả',
                              'Đang thực hiện',
                              'Chờ xử lý',
                              'Hoàn thành',
                              'Đã hủy',
                            ].map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedStatus = value ?? 'Chờ xử lý';
                                _filteredTasks = _applyFilters();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage.isNotEmpty)
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    AnimationLimiter(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredTasks.isEmpty ? 1 : _filteredTasks.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (_filteredTasks.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Không có lệnh nào',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final task = _filteredTasks[index];
                          final statusColor = task.status == 'Idle' || task.status == 'Cancelled'
                              ? Colors.grey[600]!
                              : task.status == 'Executing'
                                  ? Colors.red[800]!
                                  : task.status == 'Waiting'
                                      ? Colors.yellow[800]!
                                      : task.status == 'Completed'
                                          ? Colors.green[800]!
                                          : Colors.grey[600]!;
                          final statusIcon = task.status == 'Idle'
                              ? Icons.pause
                              : task.status == 'Executing'
                                  ? Icons.play_arrow
                                  : task.status == 'Waiting'
                                      ? Icons.hourglass_empty
                                      : task.status == 'Cancelled'
                                          ? Icons.cancel
                                          : Icons.check_circle;

                          // Làm nổi bật top 3 lệnh Waiting
                          String statusLabel;
                          BorderSide cardBorder = BorderSide.none;
                          Widget? rankBadge;

                          if (task.status == 'Waiting') {
                            if (index == 0) {
                              statusLabel = 'Sắp thực hiện';
                              cardBorder = BorderSide(color: Colors.yellow[900]!, width: 2);
                              rankBadge = ScaleAnimation(
                                scale: 0.5,
                                duration: const Duration(milliseconds: 600),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.yellow[900],
                                    border: Border.all(color: Colors.yellow[900]!, width: 2),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '1',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            } else if (index == 1) {
                              statusLabel = 'Ưu tiên 2';
                              rankBadge = ScaleAnimation(
                                scale: 0.5,
                                duration: const Duration(milliseconds: 600),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[300],
                                    border: Border.all(color: Colors.grey[600]!, width: 1),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '2',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            } else if (index == 2) {
                              statusLabel = 'Ưu tiên 3';
                              rankBadge = ScaleAnimation(
                                scale: 0.5,
                                duration: const Duration(milliseconds: 600),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.orange[300],
                                    border: Border.all(color: Colors.orange[600]!, width: 1),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '3',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              statusLabel = task.getLocalizedStatus();
                              rankBadge = null;
                            }
                          } else {
                            statusLabel = task.getLocalizedStatus();
                            rankBadge = null;
                          }

                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 600),
                            child: SlideAnimation(
                              horizontalOffset: 50.0,
                              child: FadeInAnimation(
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: cardBorder,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Colors.white, Colors.grey[100]!],
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border(
                                        left: BorderSide(color: statusColor, width: 4),
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16.0, 40.0, 16.0, 16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'AGV: ${task.agvId}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Lệnh: ${task.command}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    statusIcon,
                                                    size: 20,
                                                    color: statusColor,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Trạng thái: ${task.getLocalizedStatus()}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: statusColor.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: statusColor, width: 1),
                                                    ),
                                                    child: Text(
                                                      statusLabel,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: statusColor,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (task.status == 'Waiting')
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: TextButton(
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('Xác nhận hủy lệnh'),
                                                    content: Text(
                                                        'Bạn có chắc muốn hủy lệnh ${task.command} của ${task.agvId}?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        child: const Text('Hủy'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(context);
                                                          _cancelTask(task.agvId, task.command);
                                                        },
                                                        child: const Text('Xác nhận'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.grey[600],
                                                backgroundColor: Colors.grey[100],
                                                textStyle: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  side: BorderSide(color: Colors.grey[600]!),
                                                ),
                                              ),
                                              child: const Text('Hủy lệnh'),
                                            ),
                                          ),
                                        if (rankBadge != null)
                                          Positioned(
                                            top: 8,
                                            left: 8,
                                            child: rankBadge,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}