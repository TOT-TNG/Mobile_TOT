import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _rememberPassword = false;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
    _loadSavedCredentials();
  }

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

  Future<void> _saveCredentials(Map<String, dynamic> jsonResponse) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _usernameController.text);
    if (_rememberPassword) {
      await prefs.setString('password', _passwordController.text);
      await prefs.setBool('remember_password', true);
    } else {
      await prefs.remove('password');
      await prefs.setBool('remember_password', false);
    }
    await prefs.setString('token', jsonResponse['token'] ?? '');
    // Lưu các trường user, nếu không có thì đặt giá trị mặc định
    final user = jsonResponse['user'] ?? {};
    await prefs.setString('name', user['name'] ?? 'Unknown');
    await prefs.setString('maNS', user['maNS'] ?? jsonResponse['maNS'] ?? 'Unknown');
    await prefs.setString('maChiNhanh', user['maChiNhanh'] ?? jsonResponse['maChiNhanh'] ?? 'Unknown');
    await prefs.setString('tenDonVi', user['tenDonVi'] ?? 'Unknown');
    await prefs.setString('tenPhongBan', user['tenPhongBan'] ?? 'Không có');
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text;
      final password = _passwordController.text;

      try {
        final response = await http.post(
          Uri.parse('http://appmobile.tng.vn/production/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        );

        print('Phản hồi API: ${response.body}'); // In phản hồi để gỡ lỗi
        print('Mã trạng thái: ${response.statusCode}');

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse.containsKey('token') && jsonResponse['token'] != null) {
            print('Token nhận được: ${jsonResponse['token']}');
            await _saveCredentials(jsonResponse);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đăng nhập thành công!')),
            );
            Navigator.pushReplacementNamed(context, '/dashboard');
          } else {
            String errorMessage = jsonResponse['message'] ?? 'Đăng nhập thất bại: Không tìm thấy token hoặc token rỗng';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        } else {
          final jsonResponse = jsonDecode(response.body);
          String errorMessage = jsonResponse['message'] ?? 'Đăng nhập thất bại: ${response.statusCode}';
          if (response.statusCode == 401) {
            errorMessage = 'Tài khoản hoặc mật khẩu không đúng';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi kết nối đến server: $e')),
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
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue, Colors.lightBlue],
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: FadeTransition(
              opacity: _fadeAnimation,
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
          Positioned.fill(
            top: 170,
            bottom: 50,
            child: SingleChildScrollView(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
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
                              const Text(
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
                              TextFormField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Mật khẩu',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureText ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureText = !_obscureText;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                ),
                                obscureText: _obscureText,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Vui lòng nhập mật khẩu';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
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
                              const SizedBox(height: 30),
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
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: const Text(
              'Copyright by TOT-TNG',
              style: TextStyle(
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