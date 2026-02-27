import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'package:intl/intl.dart';

class SignalRService {
  final Function(String, String, Map<String, dynamic>) onMessageReceived;
  HubConnection? _hubConnection;

  SignalRService({required this.onMessageReceived});

  Future<void> start() async {
    try {
      _hubConnection = HubConnectionBuilder()
          .withUrl('http://103.179.191.249:7000/statusHub')
          .withAutomaticReconnect()
          .build();

      _hubConnection?.on('SendMaterialUpdate', (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          final data = arguments[0] as Map<String, dynamic>;
          final senderRole = data['Role']?.toString() ?? '';
          final message = 'SendMaterialUpdate';
          debugPrint('SignalR message received: $data');
          onMessageReceived(senderRole, message, data);
        }
      });

      await _hubConnection?.start();
      debugPrint('SignalR connection started');
    } catch (e) {
      debugPrint('Lỗi khởi tạo SignalR: $e');
    }
  }

  void stop() {
    _hubConnection?.stop();
    debugPrint('SignalR connection stopped');
  }
}

class ReceiveGoodsScreen extends StatefulWidget {
  const ReceiveGoodsScreen({Key? key}) : super(key: key);

  @override
  _ReceiveGoodsScreenState createState() => _ReceiveGoodsScreenState();
}

class _ReceiveGoodsScreenState extends State<ReceiveGoodsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> goodsList = [];
  List<Map<String, dynamic>> filteredGoodsList = [];
  bool isLoading = true;
  String? role;
  String? tenPhongBan;
  String? teamNumber;
  String? maNhanSu;
  late SignalRService signalRService;

  String _formatIssuedTime(String? isoDateTime) {
    if (isoDateTime == null || isoDateTime == 'N/A') return 'N/A';
    try {
      final dateTime = DateTime.parse(isoDateTime);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } catch (e) {
      debugPrint('Lỗi định dạng issuedTime: $isoDateTime, lỗi: $e');
      return 'N/A';
    }
  }

  String _ensureValidIssuedTime(String? issuedTime) {
    if (issuedTime == null || issuedTime == 'N/A') {
      debugPrint('IssuedTime is null or N/A, using current time');
      return DateFormat('yyyy-MM-dd HH:mm:ss.000').format(DateTime.now());
    }
    try {
      if (RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}$').hasMatch(issuedTime)) {
        return issuedTime;
      }
      if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?$').hasMatch(issuedTime)) {
        final dateTime = DateTime.parse(issuedTime);
        return DateFormat('yyyy-MM-dd HH:mm:ss.000').format(dateTime);
      }
      final dateTime = DateTime.parse(issuedTime);
      return DateFormat('yyyy-MM-dd HH:mm:ss.000').format(dateTime);
    } catch (e) {
      debugPrint('Invalid IssuedTime format: $issuedTime, lỗi: $e');
      debugPrint('Falling back to current time');
      return DateFormat('yyyy-MM-dd HH:mm:ss.000').format(DateTime.now());
    }
  }

  String _mapStatus(String status) {
    switch (status) {
      case 'Pending':
        return 'Đang tiến hành';
      case 'Completed':
        return 'Hoàn thành';
      case 'Rejected':
        return 'Từ chối';
      default:
        return status;
    }
  }

  String _normalizeKey(String materialCode, String size, String team, String color, String issuedTime) {
    final normalizedMaterialCode = materialCode.replaceAll(' ', '-').toUpperCase().trim();
    final normalizedSize = size.trim();
    final normalizedTeam = RegExp(r'\d+').firstMatch(team)?.group(0) ?? team;
    final normalizedColor = color.trim();
    final normalizedIssuedTime = _ensureValidIssuedTime(issuedTime);
    final key = '$normalizedMaterialCode|$normalizedSize|$normalizedTeam|$normalizedColor|$normalizedIssuedTime';
    debugPrint('Normalized key: input=($materialCode, $size, $team, $color, $issuedTime), output=$key');
    return key;
  }

  String _normalizeGroupKey(String materialCode, String size, String team, String color) {
    final normalizedMaterialCode = materialCode.replaceAll(' ', '-').toUpperCase().trim();
    final normalizedSize = size.trim();
    final normalizedTeam = RegExp(r'\d+').firstMatch(team)?.group(0) ?? team;
    final normalizedColor = color.trim();
    final key = '$normalizedMaterialCode|$normalizedSize|$normalizedTeam|$normalizedColor';
    debugPrint('Normalized group key: input=($materialCode, $size, $team, $color), output=$key');
    return key;
  }

  Future<List<Map<String, dynamic>>?> fetchFinishedProduct(String materialCode, String size, String team, String color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        debugPrint('JWT token is empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JWT token không hợp lệ'), backgroundColor: Colors.red),
        );
        return null;
      }

      final normalizedMaterialCode = materialCode.replaceAll(' ', '-').toUpperCase().trim();
      final normalizedSize = size.trim();
      final normalizedTeam = RegExp(r'\d+').firstMatch(team)?.group(0) ?? team;
      final normalizedColor = color.trim();

      final queryParameters = {
        'materialCode': normalizedMaterialCode,
        'mSizes': normalizedSize,
        'teamName': normalizedTeam,
        'mColors': normalizedColor,
      };
      final uri = Uri.parse('http://103.179.191.249:7000/api/agv/get-finished-product')
          .replace(queryParameters: queryParameters);
      debugPrint('Fetching get-finished-product with URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'JWT $token',
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('Timeout when calling get-finished-product for materialCode=$materialCode, size=$size, team=$team, color=$color');
        throw TimeoutException('Không thể kết nối tới API get-finished-product!');
      });

      debugPrint('get-finished-product response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final records = (responseData['data'] as List<dynamic>).map((record) {
            final standardizedRecord = Map<String, dynamic>.from(record);
            standardizedRecord['materialCode'] = standardizedRecord['materialCode']?.toString().replaceAll(' ', '-').toUpperCase().trim() ?? 'N/A';
            standardizedRecord['size'] = standardizedRecord['mSizes']?.toString().trim() ?? 'N/A';
            standardizedRecord['team'] = standardizedRecord['team']?.toString().trim() ?? 'N/A';
            standardizedRecord['color'] = standardizedRecord['mColors']?.toString().trim() ?? 'N/A';
            standardizedRecord['status'] = standardizedRecord['mStatus']?.toString() ?? 'Pending';
            standardizedRecord['issuedTime'] = _ensureValidIssuedTime(standardizedRecord['issuedTime']?.toString() ?? 'N/A');
            standardizedRecord['totalQuantity'] = (standardizedRecord['totalQuantity'] as num?)?.toInt() ?? 0;
            standardizedRecord['issuedQuantity'] = int.tryParse(standardizedRecord['issuedQuantity']?.toString() ?? '0') ?? 0;
            standardizedRecord['totalIssuedQuantity'] = int.tryParse(standardizedRecord['totalIssuedQuantity']?.toString() ?? '0') ?? 0;
            standardizedRecord['isProcessingComplaint'] = standardizedRecord['isProcessingComplaint'] ?? false;
            return standardizedRecord;
          }).where((record) => record['status'] == 'Pending').toList();

          debugPrint('Fetched records: ${jsonEncode(records)} for materialCode=$materialCode, size=$size, team=$team, color=$color');
          return records;
        } else {
          debugPrint('Không tìm thấy dữ liệu get-finished-product hợp lệ: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không lấy được dữ liệu cho $materialCode, cỡ $size, màu $color'), backgroundColor: Colors.red),
          );
          return null;
        }
      } else {
        debugPrint('Lỗi khi lấy get-finished-product: HTTP ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi API get-finished-product: HTTP ${response.statusCode}'), backgroundColor: Colors.red),
        );
        return null;
      }
    } catch (e) {
      debugPrint('Lỗi khi lấy get-finished-product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lấy dữ liệu: $e'), backgroundColor: Colors.red),
      );
      return null;
    }
  }

  Future<void> _loadRoleAndTenPhongBan() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString('role') ?? 'receive';
      maNhanSu = prefs.getString('maNS');
      tenPhongBan = prefs.getString('tenPhongBan') ?? 'Không có';
      if (tenPhongBan != null && tenPhongBan!.toLowerCase().contains('tổ may')) {
        final match = RegExp(r'\d+').firstMatch(tenPhongBan!);
        teamNumber = match != null ? match.group(0) : null;
      } else {
        teamNumber = null;
      }
    });

    await fetchGoods();
  }

  Future<void> fetchGoods() async {
    setState(() => isLoading = true);
    try {
      final query = _searchController.text.isNotEmpty ? '?materialCode=${Uri.encodeComponent(_searchController.text.replaceAll(' ', '-').toUpperCase())}' : '';
      final url = 'http://103.179.191.249:7000/api/agv/receive-finished-goods$query';
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        debugPrint('JWT token is empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JWT token không hợp lệ'), backgroundColor: Colors.red),
        );
        setState(() => isLoading = false);
        return;
      }

      debugPrint('Fetching receive-finished-goods with URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'JWT $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Không thể kết nối tới API receive-finished-goods!'),
      );

      debugPrint('Receive-finished-goods response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null && (responseData['data'] as List).isNotEmpty) {
          final newGoodsList = (responseData['data'] as List).map((item) {
            try {
              final standardizedItem = Map<String, dynamic>.from(item);
              standardizedItem['materialCode'] = standardizedItem['materialCode']?.toString().replaceAll(' ', '-').toUpperCase().trim() ?? 'N/A';
              standardizedItem['size'] = standardizedItem['mSizes']?.toString().trim() ?? 'N/A';
              standardizedItem['team'] = standardizedItem['team']?.toString().trim() ?? 'N/A';
              standardizedItem['color'] = standardizedItem['mColors']?.toString().trim() ?? 'N/A';
              standardizedItem['status'] = standardizedItem['mStatus']?.toString() ?? 'Pending';
              standardizedItem['issuedTime'] = _ensureValidIssuedTime(standardizedItem['issuedTime']?.toString() ?? 'N/A');
              standardizedItem['totalQuantity'] = (standardizedItem['totalQuantity'] as num?)?.toInt() ?? 0;
              standardizedItem['issuedQuantity'] = int.tryParse(standardizedItem['issuedQuantity']?.toString() ?? '0') ?? 0;
              standardizedItem['totalIssuedQuantity'] = int.tryParse(standardizedItem['totalIssuedQuantity']?.toString() ?? '0') ?? 0;
              standardizedItem['isProcessingComplaint'] = standardizedItem['isProcessingComplaint'] ?? false;
              debugPrint('Standardized item: ${jsonEncode(standardizedItem)}');
              return standardizedItem;
            } catch (e) {
              debugPrint('Lỗi khi chuẩn hóa item: $item, lỗi: $e');
              return <String, dynamic>{};
            }
          }).where((item) => item.isNotEmpty && item['status'] == 'Pending').toList();

          debugPrint('fetchGoods processed: ${jsonEncode(newGoodsList)}');

          if (newGoodsList.isEmpty) {
            debugPrint('newGoodsList is empty after processing');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dữ liệu đơn hàng rỗng sau khi xử lý'), backgroundColor: Colors.red),
            );
          }

          setState(() {
            goodsList = newGoodsList;
            filteredGoodsList = _groupGoods(newGoodsList);
            debugPrint('After fetchGoods - goodsList: ${jsonEncode(goodsList)}');
            debugPrint('After fetchGoods - filteredGoodsList: ${jsonEncode(filteredGoodsList)}');
          });
        } else {
          debugPrint('API response invalid: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi tải danh sách: ${responseData['message'] ?? 'Dữ liệu không hợp lệ'}'), backgroundColor: Colors.red),
          );
        }
      } else {
        debugPrint('Lỗi khi tải danh sách: HTTP ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải danh sách: HTTP ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Lỗi khi tải danh sách: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải danh sách: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> _groupGoods(List<Map<String, dynamic>> goods) {
    final standardizedList = goods.where((item) => item['status'] == 'Pending').map((item) {
      final standardizedItem = Map<String, dynamic>.from(item);
      standardizedItem['materialCode'] = standardizedItem['materialCode']?.toString().replaceAll(' ', '-').toUpperCase().trim() ?? 'N/A';
      standardizedItem['size'] = standardizedItem['size']?.toString().trim() ?? 'N/A';
      standardizedItem['team'] = standardizedItem['team']?.toString().trim() ?? 'N/A';
      standardizedItem['color'] = standardizedItem['color']?.toString().trim() ?? 'N/A';
      standardizedItem['status'] = standardizedItem['status']?.toString() ?? 'Pending';
      standardizedItem['issuedTime'] = _ensureValidIssuedTime(standardizedItem['issuedTime']?.toString() ?? 'N/A');
      standardizedItem['totalQuantity'] = (standardizedItem['totalQuantity'] as num?)?.toInt() ?? 0;
      standardizedItem['issuedQuantity'] = int.tryParse(standardizedItem['issuedQuantity']?.toString() ?? '0') ?? 0;
      standardizedItem['totalIssuedQuantity'] = int.tryParse(standardizedItem['totalIssuedQuantity']?.toString() ?? '0') ?? 0;
      standardizedItem['isProcessingComplaint'] = standardizedItem['isProcessingComplaint'] ?? false;
      debugPrint('Standardized item in _groupGoods: ${jsonEncode(standardizedItem)}');
      return standardizedItem;
    }).toList();

    debugPrint('Filtered goods (Pending only): ${jsonEncode(standardizedList)}');
    return standardizedList;
  }

  void _filterGoods() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      final filtered = goodsList.where((item) {
        final materialCode = item['materialCode']?.toString().toLowerCase() ?? '';
        final color = item['color']?.toString().toLowerCase() ?? '';
        final size = item['size']?.toString().toLowerCase() ?? '';
        return item['status'] == 'Pending' && (query.isEmpty || materialCode.contains(query) || color.contains(query) || size.contains(query));
      }).toList();
      filteredGoodsList = _groupGoods(filtered);
      debugPrint('After _filterGoods - filteredGoodsList: ${jsonEncode(filteredGoodsList)}');
    });
  }

  Future<void> _confirmReceive(int index, Map<String, dynamic> item) async {
    if (isLoading) return;

    setState(() => isLoading = true);
    debugPrint('Xác nhận đơn hàng tại index $index: ${jsonEncode(item)}');

    try {
      final materialCode = item['materialCode']?.toString() ?? 'N/A';
      final size = item['size']?.toString() ?? 'N/A';
      final team = item['team']?.toString() ?? 'N/A';
      final color = item['color']?.toString() ?? 'N/A';
      final issuedTime = item['issuedTime']?.toString() ?? 'N/A';
      final issuedQuantity = item['issuedQuantity'] as int? ?? 0;
      final key = _normalizeKey(materialCode, size, team, color, issuedTime);
      final normalizedTeam = RegExp(r'\d+').firstMatch(team)?.group(0) ?? team;

      if (materialCode == 'N/A' || size == 'N/A' || color == 'N/A' || issuedTime == 'N/A' || issuedQuantity == 0) {
        debugPrint('Dữ liệu không hợp lệ: ${jsonEncode(item)}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dữ liệu đơn hàng không hợp lệ'), backgroundColor: Colors.red),
        );
        setState(() => isLoading = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        debugPrint('JWT token is empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JWT token không hợp lệ'), backgroundColor: Colors.red),
        );
        setState(() => isLoading = false);
        return;
      }

      final formattedIssuedTime = _ensureValidIssuedTime(issuedTime);
      final payload = {
        'MaterialCode': materialCode.replaceAll(' ', '-').toUpperCase().trim(),
        'MSizes': size.trim(),
        'MColors': color.trim(),
        'Team': normalizedTeam,
        'IssuedTime': formattedIssuedTime,
        'ConfirmTime': DateFormat('yyyy-MM-dd HH:mm:ss.000').format(DateTime.now()),
        'IssuedQuantity': issuedQuantity,
      };

      debugPrint('Gửi xác nhận với payload: ${jsonEncode(payload)}');
      final response = await http.put(
        Uri.parse('http://103.179.191.249:7000/api/agv/confirm-finished-goods'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'JWT $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Yêu cầu xác nhận hết thời gian chờ!');
      });

      debugPrint('Phản hồi xác nhận: ${response.statusCode} - ${response.body}');
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        setState(() {
          goodsList.removeWhere(
            (g) => _normalizeKey(
              g['materialCode']?.toString() ?? 'N/A',
              g['size']?.toString() ?? 'N/A',
              g['team']?.toString() ?? 'N/A',
              g['color']?.toString() ?? 'N/A',
              g['issuedTime']?.toString() ?? 'N/A',
            ) == key,
          );
          _filterGoods();
          debugPrint('Removed confirmed item: ${jsonEncode(item)}');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xác nhận đơn hàng ${item['materialCode']} thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorMessage = responseData['message'] ?? 'Lỗi không xác định';
        debugPrint('Xác nhận thất bại: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $errorMessage'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Lỗi khi xác nhận đơn hàng: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _rejectItem(int index, List<String> reasons) async {
    if (role != 'receive') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không có quyền từ chối hàng hóa!'), backgroundColor: Colors.red),
      );
      return;
    }

    final item = filteredGoodsList[index];
    final status = item['status']?.toString() ?? 'Pending';
    if (status != 'Pending') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đơn hàng không ở trạng thái Đang tiến hành!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => isLoading = true);

    try {
      final materialCode = item['materialCode']?.toString() ?? 'N/A';
      final size = item['size']?.toString() ?? 'N/A';
      final team = item['team']?.toString() ?? 'N/A';
      final color = item['color']?.toString() ?? 'N/A';
      final issuedTime = item['issuedTime']?.toString() ?? 'N/A';
      final totalQuantity = item['totalQuantity'] ?? 0;
      final normalizedTeam = RegExp(r'\d+').firstMatch(team)?.group(0) ?? team;

      if (materialCode == 'N/A' || reasons.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng cung cấp mã hàng và lý do từ chối!'), backgroundColor: Colors.red),
        );
        setState(() => isLoading = false);
        return;
      }

      final formattedIssuedTime = _ensureValidIssuedTime(issuedTime);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final body = {
        'materialCode': materialCode.replaceAll(' ', '-').toUpperCase().trim(),
        'color': color.trim(),
        'size': size.trim(),
        'totalQuantity': totalQuantity,
        'errorDetails': reasons,
        'team': normalizedTeam,
        'issuedTime': formattedIssuedTime,
      };

      debugPrint('Reject request: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('http://103.179.191.249:7000/api/agv/materials/log-error'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'JWT $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Yêu cầu hết thời gian chờ, vui lòng thử lại!');
      });

      debugPrint('Reject response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 && jsonDecode(response.body)['success'] == true) {
        setState(() {
          final key = _normalizeKey(materialCode, size, team, color, issuedTime);
          goodsList.removeWhere(
            (g) => _normalizeKey(
              g['materialCode']?.toString() ?? 'N/A',
              g['size']?.toString() ?? 'N/A',
              g['team']?.toString() ?? 'N/A',
              g['color']?.toString() ?? 'N/A',
              g['issuedTime']?.toString() ?? 'N/A',
            ) == key,
          );
          _filterGoods();
          debugPrint('Removed rejected item: ${jsonEncode(item)}');
        });

        String reasonsString = reasons.join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã từ chối $materialCode (Cỡ: $size, Giờ: $issuedTime) với lý do: $reasonsString'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        final responseData = jsonDecode(response.body);
        final errorMessage = responseData['message'] ?? 'Lỗi không xác định';
        debugPrint('Lỗi khi ghi lỗi giao hàng: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi ghi lỗi giao hàng: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Lỗi khi ghi lỗi giao hàng: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _showRejectDialog(int index) async {
    List<String> selectedReasons = [];
    TextEditingController customReasonController = TextEditingController();
    final List<String> reasons = [
      'Sai màu',
      'Sai kích cỡ',
      'Số lượng không đúng',
      'Hàng lỗi',
      'Khác',
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Lý do từ chối'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...reasons.map((reason) => CheckboxListTile(
                          title: Text(reason),
                          value: selectedReasons.contains(reason),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedReasons.add(reason);
                              } else {
                                selectedReasons.remove(reason);
                              }
                            });
                          },
                        )),
                    if (selectedReasons.contains('Khác'))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextField(
                          controller: customReasonController,
                          decoration: const InputDecoration(
                            labelText: 'Nhập lý do khác',
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                List<String> reasonsToSend = List.from(selectedReasons);
                if (reasonsToSend.contains('Khác')) {
                  if (customReasonController.text.trim().isNotEmpty) {
                    reasonsToSend.remove('Khác');
                    reasonsToSend.add(customReasonController.text.trim());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập lý do khác!'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                }
                Navigator.pop(context);
                _rejectItem(index, reasonsToSend);
              },
              child: const Text('Gửi'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadRoleAndTenPhongBan();
    _searchController.addListener(_filterGoods);

    signalRService = SignalRService(
      onMessageReceived: (senderRole, message, data) {
        if ((senderRole == "delivery" || senderRole == "receive") && role == "receive" && message == 'SendMaterialUpdate') {
          final materialCode = data['MaterialCode']?.toString() ?? 'N/A';
          final size = data['mSizes']?.toString() ?? data['Size']?.toString() ?? 'N/A';
          final team = data['Line']?.toString() ?? data['team']?.toString() ?? 'N/A';
          final color = data['mColors']?.toString() ?? data['Color']?.toString() ?? 'N/A';
          final issuedTime = data['Timestamp']?.toString() ?? 'N/A';
          final status = data['Status']?.toString() ?? 'Pending';
          final totalQuantity = (data['TotalQuantity'] as num?)?.toInt() ?? 0;
          final issuedQuantity = int.tryParse(data['IssuedQuantity']?.toString() ?? '0') ?? 0;
          final totalIssuedQuantity = int.tryParse(data['totalIssuedQuantity']?.toString() ?? '0') ?? 0;

          debugPrint('SignalR received: $data');

          setState(() {
            final key = _normalizeKey(materialCode, size, team, color, issuedTime);
            final existingItems = goodsList.where(
              (item) => _normalizeKey(
                item['materialCode']?.toString() ?? 'N/A',
                item['size']?.toString() ?? 'N/A',
                item['team']?.toString() ?? 'N/A',
                item['color']?.toString() ?? 'N/A',
                item['issuedTime']?.toString() ?? 'N/A',
              ) == key,
            ).toList();

            if (status != 'Pending') {
              goodsList.removeWhere(
                (item) => _normalizeKey(
                  item['materialCode']?.toString() ?? 'N/A',
                  item['size']?.toString() ?? 'N/A',
                  item['team']?.toString() ?? 'N/A',
                  item['color']?.toString() ?? 'N/A',
                  item['issuedTime']?.toString() ?? 'N/A',
                ) == key,
              );
              _filterGoods();
              debugPrint('Removed non-Pending item from SignalR: ${jsonEncode(data)}');
              return;
            }

            if (existingItems.isNotEmpty) {
              for (var existingItem in existingItems) {
                existingItem['status'] = status;
                existingItem['totalQuantity'] = totalQuantity;
                existingItem['issuedQuantity'] = issuedQuantity;
                existingItem['totalIssuedQuantity'] = totalIssuedQuantity;
                existingItem['size'] = size;
                existingItem['color'] = color;
                existingItem['issuedTime'] = _ensureValidIssuedTime(issuedTime);
                debugPrint('Updated existing item: ${jsonEncode(existingItem)}');
              }
            } else {
              final newItem = {
                'materialCode': materialCode,
                'size': size,
                'color': color,
                'totalQuantity': totalQuantity,
                'team': team,
                'issuedQuantity': issuedQuantity,
                'totalIssuedQuantity': totalIssuedQuantity,
                'status': status,
                'issuedTime': _ensureValidIssuedTime(issuedTime),
                'isProcessingComplaint': false,
              };
              goodsList.add(newItem);
              debugPrint('Added new item: ${jsonEncode(newItem)}');
            }

            _filterGoods();
          });
        }
      },
    );

    signalRService.start();
  }

  @override
  void dispose() {
    _searchController.dispose();
    signalRService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building ReceiveGoodsScreen with ${filteredGoodsList.length} items');
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          //icon: const Icon(Icons.arrow_back, color: Colors.white),
          icon: const Icon(Icons.home, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nhận Hàng',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              enabled: role == 'receive',
              decoration: InputDecoration(
                hintText: 'Tìm mã hàng, màu sắc, kích cỡ...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                  borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                  borderSide: const BorderSide(color: Colors.blue, width: 2.0),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 4.0),
              child: Text(
                tenPhongBan ?? 'Không có phòng ban',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text(
                'Danh sách đơn hàng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredGoodsList.isEmpty
                    ? const Center(child: Text('Không có đơn hàng để nhận'))
                    : ListView.builder(
                        key: ValueKey('listview-${filteredGoodsList.length}'),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        itemCount: filteredGoodsList.length,
                        itemBuilder: (context, index) {
                          final item = filteredGoodsList[index];
                          final materialCode = item['materialCode']?.toString() ?? 'N/A';
                          final size = item['size']?.toString() ?? 'N/A';
                          final team = item['team']?.toString() ?? 'N/A';
                          final color = item['color']?.toString() ?? 'N/A';
                          final issuedTime = item['issuedTime']?.toString() ?? 'N/A';
                          final totalQuantity = (item['totalQuantity'] as int?) ?? 0;
                          final issuedQuantity = item['issuedQuantity'] as int? ?? 0;
                          final totalIssuedQuantity = item['totalIssuedQuantity'] as int? ?? 0;
                          final status = item['status']?.toString() ?? 'Pending';
                          final isProcessingComplaint = item['isProcessingComplaint'] ?? false;

                          debugPrint(
                              'Rendering item $index: materialCode=$materialCode, size=$size, team=$team, color=$color, issuedTime=$issuedTime, status=$status, issuedQuantity=$issuedQuantity, totalIssuedQuantity=$totalIssuedQuantity');

                          final opacityValue = (status != 'Pending' || isProcessingComplaint) ? 0.5 : 1.0;
                          final bool canInteract = status == 'Pending' && !isProcessingComplaint && role == 'receive';

                          return Opacity(
                            opacity: opacityValue,
                            child: Card(
                              key: ValueKey('$index-$materialCode-$size-$team-$color-$issuedTime-$status'),
                              elevation: 4,
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            materialCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.blue,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          status == 'Pending' && isProcessingComplaint
                                              ? Icons.warning
                                              : Icons.access_time,
                                          color: isProcessingComplaint ? Colors.red : Colors.blue,
                                          size: 24.0,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text('Thời gian phát hành: ${_formatIssuedTime(issuedTime)}',
                                        style: const TextStyle(fontSize: 14)),
                                    Text('Kích cỡ: $size', style: const TextStyle(fontSize: 14)),
                                    Text('Màu: $color', style: const TextStyle(fontSize: 14)),
                                    Text('Tổng số lượng: $totalQuantity', style: const TextStyle(fontSize: 14)),
                                    Text('Số lượng đã phát: $issuedQuantity/$totalIssuedQuantity', style: const TextStyle(fontSize: 14)),
                                    Text('Tổ nhận: $team', style: const TextStyle(fontSize: 14)),
                                    Text(
                                      'Trạng thái: ${_mapStatus(status)}',
                                      style: TextStyle(
                                        color: status == 'Rejected' ? Colors.red : Colors.black,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (isProcessingComplaint)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'Đang xử lý khiếu nại',
                                          style: TextStyle(color: Colors.red, fontSize: 14),
                                        ),
                                      ),
                                    if (canInteract)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            ElevatedButton(
                                              onPressed: () => _confirmReceive(index, item),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8.0),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                              ),
                                              child: const Text(
                                                'Xác nhận',
                                                style: TextStyle(fontSize: 14, color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 8.0),
                                            ElevatedButton(
                                              onPressed: () => _showRejectDialog(index),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8.0),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                              ),
                                              child: const Text(
                                                'Từ chối',
                                                style: TextStyle(fontSize: 14, color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (role == 'receive')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: ElevatedButton(
                onPressed: filteredGoodsList.any((item) {
                  final status = item['status']?.toString() ?? 'Pending';
                  final isProcessingComplaint = item['isProcessingComplaint'] ?? false;
                  return status == 'Pending' && !isProcessingComplaint;
                })
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chức năng xác nhận tất cả đã bị xóa khỏi AppBar'), backgroundColor: Colors.red),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: filteredGoodsList.any((item) {
                    final status = item['status']?.toString() ?? 'Pending';
                    final isProcessingComplaint = item['isProcessingComplaint'] ?? false;
                    return status == 'Pending' && !isProcessingComplaint;
                  })
                      ? Colors.blue
                      : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Xác Nhận Tất Cả',
                    style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}