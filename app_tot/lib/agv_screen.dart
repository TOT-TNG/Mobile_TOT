import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';

class AGVManagementScreen extends StatefulWidget {
  const AGVManagementScreen({super.key});

  @override
  _AGVManagementScreenState createState() => _AGVManagementScreenState();
}

class _AGVManagementScreenState extends State<AGVManagementScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _agvs = [];
  List<Map<String, dynamic>> _agvStatuses = [];
  List<Map<String, dynamic>> _newAGVs = [];
  List<String> _selectedTeams = [];
  bool _isLoading = false;
  bool _isEditing = false;
  String _lastUpdated = '';
  String _userId = '';
  String _siteId = ''; // lưu tên đơn vị
  final Map<String, String?> _selectedTeam = {};
  final Map<String, TextEditingController> _newIpControllers = {};
  final Map<String, TextEditingController> _newPortControllers = {};
  final Map<String, bool> _isCallSectionExpanded = {};
  final Map<String, String> _agvNotifications = {};
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, DateTime> _animationStartTimes = {};
  final Map<String, double> _textWidths = {};
  final Map<String, GlobalKey> _textKeys = {};
  final Map<String, bool> _animationStopped = {};
  final Map<String, AnimationController> _expandControllers = {};

  // Biến tạm lưu lựa chọn khi giải phóng ngã tư
  int? _selectedNgatuId;
  String? _selectedAgvForReset;

  /// ================= NORMALIZE VIETNAMESE → LATIN =================
/// Dùng để convert "ĐH" -> "DH", "Tổ ĐH 1" -> "TO DH 1"
String normalizeLatinKey(String input, {bool upper = true}) {
  var s = input.trim();

  // Đ/đ là ký tự riêng
  s = s.replaceAll('Đ', 'D').replaceAll('đ', 'd');

  const Map<String, String> vietnameseMap = {
    'á':'a','à':'a','ả':'a','ã':'a','ạ':'a',
    'ă':'a','ắ':'a','ằ':'a','ẳ':'a','ẵ':'a','ặ':'a',
    'â':'a','ấ':'a','ầ':'a','ẩ':'a','ẫ':'a','ậ':'a',
    'Á':'A','À':'A','Ả':'A','Ã':'A','Ạ':'A',
    'Ă':'A','Ắ':'A','Ằ':'A','Ẳ':'A','Ẵ':'A','Ặ':'A',
    'Â':'A','Ấ':'A','Ầ':'A','Ẩ':'A','Ẫ':'A','Ậ':'A',

    'é':'e','è':'e','ẻ':'e','ẽ':'e','ẹ':'e',
    'ê':'e','ế':'e','ề':'e','ể':'e','ễ':'e','ệ':'e',
    'É':'E','È':'E','Ẻ':'E','Ẽ':'E','Ẹ':'E',
    'Ê':'E','Ế':'E','Ề':'E','Ể':'E','Ễ':'E','Ệ':'E',

    'í':'i','ì':'i','ỉ':'i','ĩ':'i','ị':'i',
    'Í':'I','Ì':'I','Ỉ':'I','Ĩ':'I','Ị':'I',

    'ó':'o','ò':'o','ỏ':'o','õ':'o','ọ':'o',
    'ô':'o','ố':'o','ồ':'o','ổ':'o','ỗ':'o','ộ':'o',
    'ơ':'o','ớ':'o','ờ':'o','ở':'o','ỡ':'o','ợ':'o',
    'Ó':'O','Ò':'O','Ỏ':'O','Õ':'O','Ọ':'O',
    'Ô':'O','Ố':'O','Ồ':'O','Ổ':'O','Ỗ':'O','Ộ':'O',
    'Ơ':'O','Ớ':'O','Ờ':'O','Ở':'O','Ỡ':'O','Ợ':'O',

    'ú':'u','ù':'u','ủ':'u','ũ':'u','ụ':'u',
    'ư':'u','ứ':'u','ừ':'u','ử':'u','ữ':'u','ự':'u',
    'Ú':'U','Ù':'U','Ủ':'U','Ũ':'U','Ụ':'U',
    'Ư':'U','Ứ':'U','Ừ':'U','Ử':'U','Ữ':'U','Ự':'U',

    'ý':'y','ỳ':'y','ỷ':'y','ỹ':'y','ỵ':'y',
    'Ý':'Y','Ỳ':'Y','Ỷ':'Y','Ỹ':'Y','Ỵ':'Y',
  };

  final buffer = StringBuffer();
  for (final ch in s.split('')) {
    buffer.write(vietnameseMap[ch] ?? ch);
  }

  s = buffer.toString();
  s = s.replaceAll(RegExp(r'\s+'), ' ');

  return upper ? s.toUpperCase() : s;
}
  // Mapping cho SC3
  /*final Map<String, int> _sc3LineMapping = {
    "32":    1,
    "25":    2,
    "28-2":  3,
    "36-1":  4,
    "31-1":  5,
    "24":    6,
    "31-2":  7,
    "30":    8,
    "29":    9,
    "26":   10,
    "39":   11,
    "12":   12,
    "18":   13,
    "1-1":  14,
    "13":   15,
    "27":   16,
    "21":   17,
    "38-1": 18,
    "16":   19,
    "22":   20,
    "40-1": 21,
    "41-2": 22,
    "36-2": 23,
    "14":   24,
    "6":    25,
    "7":    26,
    "40-2": 27,
    "41-1": 28,
    "10":   29,
    "2":    30,
    "5":    31,
    "19":   32,
    "42-1": 33,
    "42-2": 34,
    "9":    35,
    "8":    36,
    "17":   37,
    "4":    38,
    "3":    39,
    "11":   40,
    "20-1": 41,
    "15":   42,
  };*/

  final Map<String, int> _sc3LineMapping = {
    "1":    1,
    "2":    2,
    "3":  3,
    "4":  4,
    "5":  5,
    "6":    6,
    "7":  7,
    "8":    8,
    "9":    9,
    "10":   10,
    "11":   11,
    "12":   12,
    "13":   13,
    "14":  14,
    "15":   15,
    "16":   16,
    "17":   17,
    "18": 18,
    "19":   19,
    "20":   20,
    "21": 21,
    "22": 22,
    "23": 23,
    "24":   24,
    "25":    25,
    "26":    26,
    "27": 27,
    "28": 28,
    "29":   29,
    "30":    30,
    "31":    31,
    "32":   32,
    "33": 33,
    "34": 34,
    "35":    35,
    "36":    36,
    "37":   37,
    "38":    38,
    "39":    39,
    "40":   40,
    "41": 41,
    "42":   42,
  };

  /*String _getApiLocation(String selectedTeam, String siteId) {
    if (siteId != "SC3") {
      return selectedTeam.trim().toLowerCase();
    }

    final lineNum = _sc3LineMapping[selectedTeam.trim()];
    if (lineNum != null) {
      return "line$lineNum";
    }

    print("Warning: No mapping for team $selectedTeam in SC3");
    return selectedTeam.trim().toLowerCase();
  }*/

  /*String _getApiLocation(String selectedTeam, String siteId) {
    if (siteId != "SC3") {
      return selectedTeam.trim().toLowerCase();
    }

    final lineNum = _sc3LineMapping[selectedTeam.trim()];
    if (lineNum != null) {
      return "line$lineNum";
    }

    print("Warning: No mapping for team $selectedTeam in SC3");
    return selectedTeam.trim().toLowerCase();
  }*/

String _getApiLocation(String selectedTeam, String siteId) {
  final normalizedSite = normalizeLatinKey(siteId);
  final teamRaw = selectedTeam.trim();

  // Chuẩn hoá team để xử lý trường hợp có dấu/space
  final team = normalizeLatinKey(teamRaw, upper: false).trim();

  // Nếu team là số (1..42...) thì build "line{team}"
  final teamNum = int.tryParse(team);
  if (teamNum != null) {
    return 'line$teamNum';
  }

  // Nếu site SC3 và team không phải số, thử mapping (trường hợp team dạng 28-2...)
  if (normalizedSite == 'SC3') {
    final lineNum = _sc3LineMapping[team];
    if (lineNum != null) return 'line$lineNum';
  }

  // fallback cuối: trả về team dạng text (nhưng nhiều khả năng server vẫn reject)
  return team.toLowerCase();
}

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (FlutterErrorDetails details) {
      print('Flutter error: ${details.exceptionAsString()}');
      print(details.stack);
    };
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserInfo();
    await _loadSelectedTeams();
    await _loadSiteId();
    await _loadAGVs();
    await _fetchAGVsAndStatus();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('maNS') ?? '';
    });
    print('Loaded userId: $_userId');
  }

  Future<void> _loadSiteId() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSiteId = prefs.getString('tenDonVi') ?? '';
    setState(() {
      //_siteId = prefs.getString('tenDonVi') ?? '';
      _siteId = normalizeLatinKey(rawSiteId, upper: false);
    });
    print('Loaded siteId (tenDonVi): $_siteId');
  }

  Future<void> _loadSelectedTeams() async {
    if (_userId.isEmpty) {
      print('UserId is empty, attempting to reload user info');
      await _loadUserInfo();
      if (_userId.isEmpty) {
        print('UserId still empty, navigating to login');
        _navigateToLogin();
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final savedTeams = prefs.getStringList('confirmed_teams_$_userId') ?? [];
    setState(() {
      _selectedTeams = savedTeams
    .map((t) => normalizeLatinKey(t, upper: false).trim())
    .where((t) => t.isNotEmpty)
    .toList();
    });
    print('Loaded selected teams for user $_userId: $_selectedTeams');
  }

  Future<void> _navigateToLogin() async {
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _loadAGVs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? agvsJson = prefs.getString(_agvPrefsKey);
    print('SharedPreferences agvs ($_agvPrefsKey): $agvsJson');

    if (agvsJson != null) {
      final List<dynamic> agvsList = jsonDecode(agvsJson);
      setState(() {
        _agvs.clear();
        for (var agv in agvsList) {
          final agvMap = Map<String, dynamic>.from(agv);
          final agvName = agvMap['name']?.toString();
          if (agvName != null &&
              agvName.isNotEmpty &&
              agvName != 'Unknown' &&
              !_agvs.any((existing) => existing['name'] == agvName)) {
            _agvs.add(agvMap);
            _isCallSectionExpanded[agvName] = false;
            _textKeys[agvName] = GlobalKey();
            _animationStopped[agvName] = true;
            _expandControllers[agvName] = AnimationController(
              vsync: this,
              duration: const Duration(milliseconds: 400),
            );
            _selectedTeam[agvName] = null;
          }
        }
      });
      print('Loaded AGVs from SharedPreferences for site $_siteId: $_agvs');
    }
  }

  String get _agvPrefsKey {
    final sid = _siteId.isNotEmpty ? _siteId : 'default';
    return 'agvs_$sid';
  }

  Future<void> _fetchAGVsAndStatus() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final rawSiteId = prefs.getString('tenDonVi') ?? 'SC3';
      final siteId = normalizeLatinKey(rawSiteId, upper: false);
      final url = 'http://160.187.229.51:7000/api/agv/get-agv-status?siteId=${Uri.encodeComponent(siteId)}';
      print('Fetch status rawSiteId="$rawSiteId" normalizedSiteId="$siteId" url=$url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'JWT $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('AGV status API response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          final List<dynamic> statusData = jsonData['data'] ?? [];

          setState(() {
            _agvStatuses = List<Map<String, dynamic>>.from(statusData);

            _agvs = _agvStatuses
                .map<Map<String, dynamic>>((s) {
                  final name = s['agvName']?.toString() ?? '';
                  return {
                    'name': name,
                    'ip': 'Unknown',
                    'port': 'Unknown',
                  };
                })
                .where((agv) {
                  final name = agv['name'] as String?;
                  return name != null && name.isNotEmpty && name != 'Unknown';
                })
                .toList();

            _isCallSectionExpanded.clear();
            _textKeys.clear();
            _animationStopped.clear();
            _expandControllers.forEach((_, c) => c.dispose());
            _expandControllers.clear();

            for (var agv in _agvs) {
              final agvName = agv['name'] as String;
              _isCallSectionExpanded[agvName] = false;
              _textKeys[agvName] = GlobalKey();
              _animationStopped[agvName] = true;
              _expandControllers[agvName] = AnimationController(
                vsync: this,
                duration: const Duration(milliseconds: 400),
              );
              _selectedTeam.putIfAbsent(agvName, () => null);
            }

            _lastUpdated = DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now());
            _isLoading = false;

            final idleCount      = _agvStatuses.where((s) => s['status'] == 'Idle').length;
            final executingCount = _agvStatuses.where((s) => s['status'] == 'Executing').length;
            final waitingCount   = _agvStatuses.where((s) => s['status'] == 'Waiting').length;
            final unknownCount   = _agvStatuses.where((s) => s['status'] == 'Unknown').length;

            print('AGV statuses: $_agvStatuses');
            print('Data: Idle=$idleCount, Executing=$executingCount, Waiting=$waitingCount, Unknown=$unknownCount');
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_agvPrefsKey, jsonEncode(_agvs));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi lấy trạng thái AGV: ${jsonData['message'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
          );
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi gọi API trạng thái AGV: ${response.statusCode}'), backgroundColor: Colors.red),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching AGV status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lấy trạng thái AGV: $e'), backgroundColor: Colors.red),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _callAGV(String agvName, String selectedTeam) async {
    try {
      if (selectedTeam.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn tổ'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return false;
      }

      if (_siteId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy mã đơn vị (siteId). Vui lòng kiểm tra lại trong phần hồ sơ.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return false;
      }

      final apiLocation = _getApiLocation(selectedTeam, _siteId);
      print('Raw selectedTeam: "$selectedTeam"');
      print('Cleaned apiLocation: "$apiLocation"');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final url = 'http://160.187.229.51:7000/api/agv/call-agv';
      final body = {
        'Location': apiLocation.toLowerCase(),
        'AgvName': agvName,
        'SiteId' : _siteId,
      };
      print('Calling AGV API: $url with body: ${jsonEncode(body)}');

      setState(() {
        _agvNotifications[agvName] = '$agvName đang xử lý lệnh...';
        _isCallSectionExpanded[agvName] = false;
        _textKeys[agvName] = GlobalKey();
        if (!_animationControllers.containsKey(agvName)) {
          _animationControllers[agvName] = AnimationController(
            vsync: this,
            duration: const Duration(seconds: 4),
          )..repeat();
          print('Created animation controller for $agvName');
        } else {
          _animationControllers[agvName]!.repeat();
        }
        _animationStartTimes[agvName] = DateTime.now();
        _animationStopped[agvName] = false;
        print('Started animation for $agvName');
      });

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'JWT $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      print('AGV call response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          final command = jsonData['command']?.toString() ?? apiLocation;
          final taskStatus = jsonData['status']?.toString() ?? 'Unknown';
          final message = jsonData['message']?.toString() ?? 'Task added successfully';
          print('Calling AGV: agvName=$agvName, selectedTeam=$selectedTeam, mapped command=$command');
          setState(() {
            if (taskStatus == 'Executing' || taskStatus == 'Waiting') {
              _agvNotifications[agvName] = '$agvName đang di chuyển tới chuyền $selectedTeam';
              final existingStatusIndex = _agvStatuses.indexWhere((status) => status['agvName'] == agvName);
              if (existingStatusIndex != -1) {
                _agvStatuses[existingStatusIndex] = {'agvName': agvName, 'status': taskStatus};
              } else {
                _agvStatuses.add({'agvName': agvName, 'status': taskStatus});
              }
              _animationControllers[agvName]?.stop();
              _animationControllers[agvName]?.reset();
              _animationStopped[agvName] = true;
              print('Stopped and reset animation for $agvName due to API success');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$message (chuyền $selectedTeam, ánh xạ: ${command.replaceFirst('line', 'chuyền ')})'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          });
          await _fetchAGVsAndStatus();
          print('Notification for $agvName: ${_agvNotifications[agvName]}');
          print('Updated status for $agvName: $taskStatus');
          print('After call, statuses: $_agvStatuses');
          print('After call, notifications: $_agvNotifications');
          print('Animation stopped: $_animationStopped');
          return true;
        } else {
          setState(() {
            _agvNotifications[agvName] = '$agvName không thể di chuyển: ${jsonData['message'] ?? 'Lỗi không xác định'}';
            _animationControllers[agvName]?.stop();
            _animationControllers[agvName]?.reset();
            _animationStopped[agvName] = true;
            print('Stopped and reset animation for $agvName due to API failure');
          });
          Future.delayed(const Duration(seconds: 5), () {
            setState(() {
              _agvNotifications.remove(agvName);
              _textWidths.remove(agvName);
              if (_animationControllers.containsKey(agvName)) {
                _animationControllers[agvName]?.dispose();
                _animationControllers.remove(agvName);
              }
              _animationStartTimes.remove(agvName);
              _animationStopped.remove(agvName);
            });
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi gọi AGV: ${jsonData['message'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return false;
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _agvNotifications[agvName] = '$agvName không thể di chuyển: ${errorData['message'] ?? 'Lỗi API ${response.statusCode}'}';
          _animationControllers[agvName]?.stop();
          _animationControllers[agvName]?.reset();
          _animationStopped[agvName] = true;
          print('Stopped and reset animation for $agvName due to API failure');
        });
        Future.delayed(const Duration(seconds: 5), () {
          setState(() {
            _agvNotifications.remove(agvName);
            _textWidths.remove(agvName);
            if (_animationControllers.containsKey(agvName)) {
              _animationControllers[agvName]?.dispose();
              _animationControllers.remove(agvName);
            }
            _animationStartTimes.remove(agvName);
            _animationStopped.remove(agvName);
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi gọi API AGV: ${errorData['message'] ?? 'HTTP ${response.statusCode}'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return false;
      }
    } catch (e) {
      print('Error calling AGV: $e');
      setState(() {
        _agvNotifications[agvName] = '$agvName không thể di chuyển: $e';
        _animationControllers[agvName]?.stop();
        _animationControllers[agvName]?.reset();
        _animationStopped[agvName] = true;
        print('Stopped and reset animation for $agvName due to error');
      });
      Future.delayed(const Duration(seconds: 5), () {
        setState(() {
          _agvNotifications.remove(agvName);
          _textWidths.remove(agvName);
          if (_animationControllers.containsKey(agvName)) {
            _animationControllers[agvName]?.dispose();
            _animationControllers.remove(agvName);
          }
          _animationStartTimes.remove(agvName);
          _animationStopped.remove(agvName);
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gọi AGV: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return false;
    }
  }

  Future<void> _saveAGV(int index) async {
    final agv = _newAGVs[index];
    final name = agv['name'] as String;
    final ipController = _newIpControllers[name]!;
    final portController = _newPortControllers[name]!;

    final ip = ipController.text.trim();
    final port = portController.text.trim();

    final ipRegExp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
    final portValue = int.tryParse(port);

    if (!ipRegExp.hasMatch(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Định dạng IP không hợp lệ')),
      );
      return;
    }
    if (port.isEmpty || portValue == null || portValue < 0 || portValue > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Port phải nằm trong khoảng 0 đến 65535')),
      );
      return;
    }

    setState(() {
      _agvs.add({
        'name': name,
        'ip': ip,
        'port': port,
      });
      _newAGVs.removeAt(index);
      _isCallSectionExpanded[name] = false;
      _textKeys[name] = GlobalKey();
      _animationStopped[name] = true;
      _expandControllers[name] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _selectedTeam[name] = null;
      _newIpControllers.remove(name)?.dispose();
      _newPortControllers.remove(name)?.dispose();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_agvPrefsKey, jsonEncode(_agvs));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lưu AGV thành công')),
    );

    await _fetchAGVsAndStatus();
  }

  Future<void> _deleteAGV(int index) async {
    final agvName = _agvs[index]['name']!;
    setState(() {
      _agvs.removeAt(index);
      _isCallSectionExpanded.remove(agvName);
      _agvNotifications.remove(agvName);
      if (_animationControllers.containsKey(agvName)) {
        _animationControllers[agvName]?.stop();
        _animationControllers[agvName]?.dispose();
        _animationControllers.remove(agvName);
      }
      if (_expandControllers.containsKey(agvName)) {
        _expandControllers[agvName]?.dispose();
        _expandControllers.remove(agvName);
      }
      _animationStartTimes.remove(agvName);
      _textWidths.remove(agvName);
      _textKeys.remove(agvName);
      _animationStopped.remove(agvName);
      _selectedTeam.remove(agvName);
      _agvStatuses.removeWhere((status) => status['agvName'] == agvName);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_agvPrefsKey, jsonEncode(_agvs));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Xóa AGV thành công')),
    );

    await _fetchAGVsAndStatus();
  }

  void _addAGV() {
    setState(() {
      final agvCount = _agvs.length + _newAGVs.length + 1;
      final name = 'AGV$agvCount';
      _newAGVs.add({
        'name': name,
      });
      _newIpControllers[name] = TextEditingController();
      _newPortControllers[name] = TextEditingController();
    });
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  // === CHỨC NĂNG GIẢI PHÓNG NGÃ TƯ - ĐÃ THÊM BƯỚC CHỌN AGV ===

  // Bước 1: Dropdown chọn ngã tư
  void _showResetNgatuDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chọn ngã tư cần giải phóng'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: 10,
              itemBuilder: (context, index) {
                final ngatuId = index + 1;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Text('$ngatuId', style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text('Ngã tư $ngatuId'),
                  onTap: () {
                    setState(() {
                      _selectedNgatuId = ngatuId;
                    });
                    Navigator.pop(context);
                    _showSelectAgvDialog(); // Chuyển sang chọn AGV
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
          ],
        );
      },
    );
  }

  // Bước 2: Dialog chọn AGV
  void _showSelectAgvDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chọn AGV đang kẹt'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: _agvStatuses.isEmpty
                ? const Center(child: Text('Không có AGV nào'))
                : ListView.builder(
                    itemCount: _agvStatuses.length,
                    itemBuilder: (context, index) {
                      final status = _agvStatuses[index];
                      final agvName = status['agvName']?.toString() ?? 'Unknown';
                      final agvStatus = status['status']?.toString() ?? 'Unknown';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: agvStatus == 'Executing' ? Colors.blue : Colors.grey,
                          child: Text(agvName.substring(agvName.length - 2), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(agvName),
                        subtitle: Text('Trạng thái: $agvStatus'),
                        onTap: () {
                          setState(() {
                            _selectedAgvForReset = agvName;
                          });
                          Navigator.pop(context);
                          _showConfirmResetDialog(_selectedNgatuId!, agvName);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedNgatuId = null;
                  _selectedAgvForReset = null;
                });
              },
              child: const Text('Hủy'),
            ),
          ],
        );
      },
    );
  }

  // Bước 3: Confirm dialog
  void _showConfirmResetDialog(int ngatuId, String agvName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Xác nhận giải phóng ngã tư $ngatuId'),
          content: Text(
            'Bạn chắc chắn muốn giải phóng ngã tư $ngatuId cho AGV **$agvName**?\n\n'
            'Lệnh SET_${ngatuId}_${agvName}_OK sẽ được gửi để AGV được phép đi vào.',
            style: TextStyle(color: Colors.red[800], height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _forceResetIntersection(ngatuId, agvName);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Gọi API reset với AgvName
  Future<bool> _forceResetIntersection(int ngatuId, String agvName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final rawSiteId = prefs.getString('tenDonVi') ?? 'SC3';
      final siteId = normalizeLatinKey(rawSiteId, upper: false);

      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa đăng nhập'), backgroundColor: Colors.red),
        );
        return false;
      }

      final url = 'http://160.187.229.51:7000/api/intersection/reset';
      final body = {
        'SiteId': siteId,
        'NgatuId': ngatuId,
        'AgvName': agvName, // Gửi AGV để cloud lưu AGV_ID và tạo Command đúng
      };

      print('Force reset API: $url body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'JWT $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      print('Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã yêu cầu giải phóng ngã tư $ngatuId cho $agvName!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _selectedNgatuId = null;
            _selectedAgvForReset = null;
          });
          Future.delayed(const Duration(seconds: 3), _fetchAGVsAndStatus);
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi server: ${jsonData['message'] ?? 'Unknown'}'), backgroundColor: Colors.red),
          );
          return false;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi API: ${response.statusCode}'), backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      print('Error reset: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final validAGVs = _agvs.where((agv) => agv['name'] != null && agv['name'] != 'Unknown' && agv['name'].toString().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        title: const Text(
          'Quản lý AGV',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.settings, color: Colors.white),
          onSelected: (value) {
            if (value == 'add') {
              _addAGV();
            } else if (value == 'edit') {
              _toggleEditMode();
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'add',
              child: Text('Thêm AGV'),
            ),
            PopupMenuItem<String>(
              value: 'edit',
              child: Text(_isEditing ? 'Hủy sửa' : 'Sửa'),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue, Colors.lightBlue],
            ),
          ),
        ),
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
                    // Phần thêm AGV mới
                    ..._newAGVs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final agv = entry.value;
                      final name = agv['name'] as String;
                      final ipController = _newIpControllers[name]!;
                      final portController = _newPortControllers[name]!;

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Colors.grey[100]!],
                            ),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: ipController,
                                  decoration: InputDecoration(
                                    labelText: 'Địa chỉ IP',
                                    prefixIcon: const Icon(Icons.network_check),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: portController,
                                  decoration: InputDecoration(
                                    labelText: 'Port',
                                    prefixIcon: const Icon(Icons.settings_ethernet),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: () => _saveAGV(index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Lưu'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),

                    // Danh sách AGV - Đã sửa cú pháp spread operator
                    if (validAGVs.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Danh sách AGV',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, color: Colors.blue[800]),
                            onPressed: _fetchAGVsAndStatus,
                            tooltip: 'Làm mới trạng thái AGV',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cập nhật: $_lastUpdated',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: validAGVs.length,
                        itemBuilder: (context, index) {
                          final agv = validAGVs[index];
                          final agvName = agv['name']?.toString() ?? '';
                          final statusData = _agvStatuses.firstWhere(
                            (status) => status['agvName'] == agvName,
                            orElse: () => {'status': 'Unknown'},
                          );
                          final agvStatus = statusData['status']?.toString() ?? 'Unknown';
                          Color statusColor;
                          String statusText;

                          if (agvStatus == 'Idle') {
                            statusColor = Colors.green;
                            statusText = 'Sẵn sàng';
                          } else if (agvStatus == 'Waiting') {
                            statusColor = Colors.yellow[700]!;
                            statusText = 'Đang chờ';
                          } else {
                            statusColor = Colors.red;
                            statusText = agvStatus == 'Unknown' ? 'Không rõ' : 'Bận';
                          }

                          return RepaintBoundary(
                            child: VisibilityDetector(
                              key: Key(agvName),
                              onVisibilityChanged: (info) {
                                if (_animationControllers.containsKey(agvName) && agvStatus == 'Executing') {
                                  final startTime = _animationStartTimes[agvName];
                                  if (info.visibleFraction > 0 &&
                                      startTime != null &&
                                      DateTime.now().difference(startTime).inMinutes < 5 &&
                                      (!_animationStopped.containsKey(agvName) || !_animationStopped[agvName]!)) {
                                    if (!_animationControllers[agvName]!.isAnimating) {
                                      _animationControllers[agvName]!.repeat();
                                      print('Resumed animation for $agvName due to visibility');
                                    }
                                  } else {
                                    if (_animationControllers[agvName]!.isAnimating) {
                                      _animationControllers[agvName]!.stop();
                                      _animationControllers[agvName]!.reset();
                                      _animationStopped[agvName] = true;
                                      print('Stopped and reset animation for $agvName due to invisibility or time limit');
                                    }
                                  }
                                }
                              },
                              child: Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Colors.white, Colors.grey[100]!],
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  agvStatus == 'Idle'
                                                      ? Icons.check_circle
                                                      : agvStatus == 'Executing'
                                                          ? Icons.directions_run
                                                          : agvStatus == 'Waiting'
                                                              ? Icons.hourglass_top
                                                              : Icons.help,
                                                  color: statusColor,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  agvName,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (_isEditing)
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () => _deleteAGV(index),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Trạng thái: $statusText',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: statusColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Transform.translate(
                                              offset: const Offset(0, 0),
                                              child: Transform.rotate(
                                                angle: 0,
                                                child: Icon(
                                                  Icons.local_shipping,
                                                  color: Colors.green[700],
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                            if (_agvNotifications.containsKey(agvName)) ...[
                                              AnimatedOpacity(
                                                opacity: _agvNotifications[agvName] != null ? 1.0 : 0.0,
                                                duration: const Duration(milliseconds: 300),
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: _agvNotifications[agvName]!.contains('không thể')
                                                        ? Colors.red[100]
                                                        : Colors.green[100],
                                                    borderRadius: BorderRadius.circular(8),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.grey.withOpacity(0.2),
                                                        spreadRadius: 1,
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      if (!_agvNotifications[agvName]!.contains('không thể')) ...[
                                                        LayoutBuilder(
                                                          builder: (context, constraints) {
                                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                                              final textContext = _textKeys[agvName]?.currentContext;
                                                              if (textContext != null) {
                                                                final renderBox = textContext.findRenderObject() as RenderBox?;
                                                                final width = renderBox?.size.width ?? 200.0;
                                                                if (_textWidths[agvName] != width) {
                                                                  setState(() {
                                                                    _textWidths[agvName] = width;
                                                                    print('Text width for $agvName: $width');
                                                                  });
                                                                }
                                                              }
                                                            });
                                                            return _animationControllers.containsKey(agvName) &&
                                                                    _animationControllers[agvName]!.isAnimating &&
                                                                    (!_animationStopped.containsKey(agvName) || !_animationStopped[agvName]!)
                                                                ? AnimatedBuilder(
                                                                    animation: _animationControllers[agvName]!,
                                                                    builder: (context, child) {
                                                                      print('Animation value for $agvName: ${_animationControllers[agvName]!.value}');
                                                                      final textWidth = _textWidths[agvName] ?? 200.0;
                                                                      final animation = Tween<double>(begin: 0, end: textWidth).animate(
                                                                        CurvedAnimation(
                                                                          parent: _animationControllers[agvName]!,
                                                                          curve: Curves.linear,
                                                                        ),
                                                                      );
                                                                      return Transform.translate(
                                                                        offset: Offset(animation.value, 0),
                                                                        child: Transform.rotate(
                                                                          angle: 0,
                                                                          child: Icon(
                                                                            Icons.local_shipping,
                                                                            color: Colors.green[700],
                                                                            size: 24,
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                  )
                                                                : Transform.translate(
                                                                    offset: const Offset(100, 0),
                                                                    child: Transform.rotate(
                                                                      angle: 0,
                                                                      child: Icon(
                                                                        Icons.local_shipping,
                                                                        color: Colors.green[700],
                                                                        size: 24,
                                                                      ),
                                                                    ),
                                                                  );
                                                          },
                                                        ),
                                                        const SizedBox(height: 8),
                                                      ],
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          if (_agvNotifications[agvName]!.contains('không thể')) ...[
                                                            Icon(
                                                              Icons.error,
                                                              color: Colors.red[700],
                                                              size: 24,
                                                            ),
                                                            const SizedBox(width: 8),
                                                          ],
                                                          Expanded(
                                                            child: Center(
                                                              child: Text(
                                                                _agvNotifications[agvName]!,
                                                                key: _textKeys[agvName],
                                                                style: TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: _agvNotifications[agvName]!.contains('không thể')
                                                                      ? Colors.red[700]
                                                                      : Colors.green[700],
                                                                ),
                                                                textAlign: TextAlign.center,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ]
                                          ),
                                          const SizedBox(height: 12),
                                          if (!_isEditing) ...[
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: IconButton(
                                                icon: Icon(
                                                  _isCallSectionExpanded[agvName] == true
                                                      ? Icons.arrow_drop_up
                                                      : Icons.arrow_drop_down,
                                                  color: Colors.blue[800],
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _isCallSectionExpanded[agvName] =
                                                        !(_isCallSectionExpanded[agvName] ?? false);
                                                    print('Toggled expand for $agvName: ${_isCallSectionExpanded[agvName]}');
                                                    if (_isCallSectionExpanded[agvName]!) {
                                                      _expandControllers[agvName]?.forward();
                                                    } else {
                                                      _expandControllers[agvName]?.reverse();
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                            ClipRect(
                                              child: SizeTransition(
                                                sizeFactor: CurvedAnimation(
                                                  parent: _expandControllers[agvName]!,
                                                  curve: Curves.easeInOut,
                                                ),
                                                child: ConstrainedBox(
                                                  constraints: const BoxConstraints(maxHeight: 120),
                                                  child: Column(
                                                    children: [
                                                      DropdownButtonFormField<String>(
                                                        decoration: InputDecoration(
                                                          labelText: 'Vị trí gọi AGV (tổ may)',
                                                          prefixIcon: const Icon(Icons.location_on),
                                                          border: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          filled: true,
                                                          fillColor: Colors.grey[200],
                                                        ),
                                                        value: _selectedTeam[agvName],
                                                        hint: Text(_selectedTeams.isEmpty ? 'Chưa có tổ được chọn' : 'Chọn tổ'),
                                                        isExpanded: true,
                                                        items: _selectedTeams.isEmpty
                                                            ? [
                                                                DropdownMenuItem<String>(
                                                                  value: null,
                                                                  child: Text('Chưa có tổ được chọn'),
                                                                  enabled: false,
                                                                ),
                                                              ]
                                                            : _selectedTeams.map((team) {
                                                                return DropdownMenuItem<String>(
                                                                  value: team,
                                                                  child: Text('Tổ $team'),
                                                                );
                                                              }).toList(),
                                                        onChanged: (value) {
                                                          setState(() {
                                                            _selectedTeam[agvName] = value;
                                                          });
                                                          print('Selected team for $agvName: $value');
                                                        },
                                                      ),
                                                      const SizedBox(height: 12),
                                                      Align(
                                                        alignment: Alignment.centerRight,
                                                        child: ElevatedButton(
                                                          onPressed: agvStatus == 'Executing' || _selectedTeam[agvName] == null
                                                              ? null
                                                              : () {
                                                                  final selectedTeam = _selectedTeam[agvName];
                                                                  if (selectedTeam == null || selectedTeam.isEmpty) {
                                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                                      const SnackBar(content: Text('Vui lòng chọn tổ'), backgroundColor: Colors.red),
                                                                    );
                                                                    return;
                                                                  }
                                                                  _callAGV(agvName, selectedTeam);
                                                                },
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.blue,
                                                            foregroundColor: Colors.white,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                          ),
                                                          child: const Text('Gọi AGV'),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],

                    const SizedBox(height: 32),

                    // === PHẦN GIẢI PHÓNG NGÃ TƯ ===
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange[300]!, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange[800],
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Giải phóng ngã tư',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Chọn ngã tư cần giải phóng khi AGV bị kẹt hoặc lỗi hệ thống',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButton<int>(
                            isExpanded: true,
                            hint: Text(
                              'Chọn ngã tư cần giải phóng',
                              style: TextStyle(fontSize: 16, color: Colors.orange[900]),
                            ),
                            value: null,
                            underline: Container(
                              height: 2,
                              color: Colors.orange[700],
                            ),
                            icon: Icon(Icons.arrow_drop_down_circle, color: Colors.orange[800], size: 32),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            items: List.generate(10, (index) {
                              final ngatuId = index + 1;
                              return DropdownMenuItem<int>(
                                value: ngatuId,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Colors.orange[300]!, Colors.orange[100]!],
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$ngatuId',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Ngã tư $ngatuId',
                                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            onChanged: (ngatuId) {
                              if (ngatuId != null) {
                                _showResetNgatuDialog(); // Gọi hàm chọn ngã tư
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}