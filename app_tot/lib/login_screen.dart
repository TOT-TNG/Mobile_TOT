import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
//import 'package:permission_handler/permission_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _rememberPassword = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _loadSavedCredentials();
  }

  // Tải thông tin tài khoản và mật khẩu đã lưu
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username') ?? '';
    final savedPassword = prefs.getString('password') ?? '';
    final savedRememberPassword = prefs.getBool('remember_password') ?? false;

    setState(() {
      _usernameController.text = savedUsername;
      _passwordController.text = savedPassword;
      _rememberPassword = savedRememberPassword;
    });
  }
  // Lưu thông tin tài khoản và mật khẩu nếu người dùng chọn "Lưu mật khẩu"
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _usernameController.text);
    if (_rememberPassword) {
      await prefs.setString('password', _passwordController.text);
      await prefs.setBool('remember_password', true);
    } else {
      await prefs.remove('password');
      await prefs.setBool('remember_password', false);
    }
  }

  // Lấy thông tin Wi-Fi (tên SSID và địa chỉ IP)
  Future<Map<String, String?>> _getWifiInfo() async {
    try {
      final networkInfo = NetworkInfo();
      final wifiName = await networkInfo.getWifiName(); // Lấy tên Wi-Fi (SSID)
      final wifiIP = await networkInfo.getWifiIP(); // Lấy địa chỉ IP
      return {
        'wifiName': wifiName,
        'wifiIP': wifiIP,
      };
    } catch (e) {
      print('Lỗi khi lấy thông tin Wi-Fi: $e');
      return {
        'wifiName': null,
        'wifiIP': null,
      };
    }
  }

  // Hiển thị dialog cài đặt IP và Port
  void _showSettingsDialog() {
    final ipAddressController = TextEditingController();
    final portController = TextEditingController();
    String? wifiName;
    String? deviceIp;

    // Tải giá trị IP và Port đã lưu, đồng thời lấy thông tin Wi-Fi
    SharedPreferences.getInstance().then((prefs) async {
      final savedIp = prefs.getString('ip_address');
      final savedPort = prefs.getString('port') ?? '';

      // Lấy thông tin Wi-Fi (SSID và IP)
      final wifiInfo = await _getWifiInfo();
      wifiName = wifiInfo['wifiName'];
      deviceIp = wifiInfo['wifiIP'];

      // Nếu không có IP đã lưu, tự động điền IP của thiết bị
      if (savedIp == null || savedIp.isEmpty) {
        ipAddressController.text = deviceIp ?? '';
      } else {
        ipAddressController.text = savedIp;
      }
      portController.text = savedPort;

      // Cập nhật giao diện dialog sau khi lấy được thông tin
      (context as Element).markNeedsBuild();
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cài đặt mạng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hiển thị tên Wi-Fi
                const Text(
                  'Tên Wi-Fi:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  wifiName ?? 'Không kết nối Wi-Fi',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                // Hiển thị địa chỉ IP của thiết bị
                const Text(
                  'Địa chỉ IP của thiết bị:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  deviceIp ?? 'Không xác định',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                // Trường IP Address (có thể chỉnh sửa)
                TextFormField(
                  controller: ipAddressController,
                  decoration: InputDecoration(
                    labelText: 'IP Address',
                    prefixIcon: const Icon(Icons.network_check),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập IP address';
                    }
                    final ipRegExp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
                    if (!ipRegExp.hasMatch(value)) {
                      return 'Định dạng IP không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Trường Port (có thể chỉnh sửa)
                TextFormField(
                  controller: portController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Port',
                    prefixIcon: const Icon(Icons.settings_ethernet),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập port';
                    }
                    final port = int.tryParse(value);
                    if (port == null || port < 0 || port > 65535) {
                      return 'Port phải nằm trong khoảng 0 đến 65535';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                final ipAddress = ipAddressController.text;
                final port = portController.text;

                // Kiểm tra định dạng IP và Port
                final ipRegExp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
                final portValue = int.tryParse(port);

                if (ipAddress.isEmpty || !ipRegExp.hasMatch(ipAddress)) {
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

                // Lưu IP và Port vào SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('ip_address', ipAddress);
                await prefs.setString('port', port);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã lưu cài đặt IP và Port')),
                );
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      if (_usernameController.text == 'admin' && _passwordController.text == 'TNG12345') {
        // Lưu thông tin tài khoản và mật khẩu
        await _saveCredentials();

        // Kiểm tra IP và Port đã được cài đặt chưa
        final prefs = await SharedPreferences.getInstance();
        final ipAddress = prefs.getString('ip_address');
        final port = prefs.getString('port');

        if (ipAddress == null || ipAddress.isEmpty || port == null || port.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng cài đặt IP và Port trước khi đăng nhập')),
          );
          _showSettingsDialog();
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng nhập thành công!')),
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tài khoản hoặc mật khẩu không đúng!')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = screenWidth * 0.08;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue, Colors.lightBlue],
              ),
            ),
          ),
          // Tiêu đề "Hệ thống giao nhận hàng"
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: FadeTransition(
              opacity: _animation,
              child: Text(
                'Hệ thống giao nhận hàng',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Login Card
          Center(
            child: FadeTransition(
              opacity: _animation,
              child: ScaleTransition(
                scale: _animation,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tiêu đề "Đăng Nhập"
                          Text(
                            'Đăng Nhập',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 2.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          // Username Field
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Tài khoản',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập tài khoản';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập mật khẩu';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          // Checkbox "Lưu mật khẩu" và nút Settings
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberPassword,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberPassword = value!;
                                      });
                                    },
                                  ),
                                  const Text('Lưu mật khẩu'),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings, color: Colors.black, size: 30),
                                onPressed: _showSettingsDialog,
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          // Login Button
                          ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              'ĐĂNG NHẬP',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Dòng chữ "Copyright by TOT-TNG"
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Text(
              'Copyright by TOT-TNG',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}