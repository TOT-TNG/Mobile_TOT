import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = 'Unknown';
  String _tenPhongBan = 'Unknown';
  String _userId = '';
  String _maChiNhanh = 'Unknown';
  List<String> _teams = [];
  Set<String> _tempSelectedTeams = {};
  Set<String> _selectedTeams = {};
  bool _isEditing = false;
  bool _isSaved = false;
  String? _successMessage;
  bool _isUserInfoLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserInfo();
    _loadTeams();
    await _loadSelectedTeams();
    if (mounted) {
      setState(() {
        _isUserInfoLoaded = true;
      });
    }
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name') ?? 'Unknown';
      _tenPhongBan = prefs.getString('tenPhongBan') ?? 'Unknown';
      _userId = prefs.getString('maNS') ?? '';
      _maChiNhanh = prefs.getString('maChiNhanh') ?? 'Unknown';
    });
    print('Loaded user info - name: "$_name", tenPhongBan: "$_tenPhongBan", userId: "$_userId", maChiNhanh: "$_maChiNhanh"');
  }

  void _loadTeams() {
    // Danh sách tổ cố định từ yêu cầu
    /*_teams = [
      '15', '20-1', '11', '03', '13', '17', '21', '40-2', '42-1', '23',
      '19', '05', '08', '10', '41-1', '09', '07', '06', '14', '36-2',
      '41-2', '40-1', '22', '16', '02', '38-1', '27', '04', '01-1', '18',
      '12', '39', '24', '29', '30', '31-2', '26', '31-1', '36-1', '35',
      '25', '32'
    ];*/
    _teams = [
      '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
      '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
      '21', '22', '23', '24', '25', '26', '27', '28', '29', '30',
      '31', '32', '33', '34', '35', '36', '37', '38', '39', '40',
      '41','42'
    ];
    setState(() {
      _teams = _teams;
    });
    print('Loaded teams: $_teams');
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
    final validTeams = savedTeams.where((team) => _teams.contains(team)).toSet();
    if (mounted) {
      setState(() {
        _selectedTeams = validTeams;
        _tempSelectedTeams = validTeams;
        _isSaved = true;
        _isEditing = false;
      });
    }
    print('Loaded selected teams for user $_userId: $_selectedTeams');
  }

  Future<void> _saveSelectedTeams() async {
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không tìm thấy thông tin tài khoản! Vui lòng đăng nhập lại.'),
          action: SnackBarAction(
            label: 'Đăng nhập',
            textColor: Colors.blue,
            onPressed: _navigateToLogin,
          ),
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('confirmed_teams_$_userId', _selectedTeams.toList());
    if (mounted) {
      setState(() {
        _isEditing = false;
        _isSaved = true;
        _successMessage = 'Lưu thành công';
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      });
    }
    print('Saved selected teams for user $_userId: $_selectedTeams');
  }

  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _confirmSelection() {
    if (mounted) {
      setState(() {
        _selectedTeams = _tempSelectedTeams.toSet();
        _isEditing = true;
        _isSaved = false;
      });
    }
    print('Confirmed selected teams: $_selectedTeams');
    Navigator.of(context).pop();
  }

  void _showMultiSelectDropdown(BuildContext context) {
    if (_teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có tổ nào để chọn.')),
      );
      return;
    }

    _tempSelectedTeams = _selectedTeams.toSet();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Chọn tổ'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._teams.map((String team) {
                      return CheckboxListTile(
                        title: Text('Tổ may $team'),
                        value: _tempSelectedTeams.contains(team),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            if (value == true) {
                              _tempSelectedTeams.add(team);
                            } else {
                              _tempSelectedTeams.remove(team);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _startEditing() {
    if (mounted) {
      setState(() {
        _isEditing = true;
        _isSaved = false;
        _tempSelectedTeams = _selectedTeams.toSet();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        title: const Text(
          'CÀI ĐẶT',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: !_isUserInfoLoaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Thông tin tài khoản',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(Icons.person, 'Họ tên', _name),
                            const Divider(height: 20),
                            _buildInfoRow(Icons.group, 'Phòng ban', _tenPhongBan),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tổ làm việc',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _showMultiSelectDropdown(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedTeams.isEmpty ? 'Chọn tổ' : ' ${_selectedTeams.length} tổ',
                              style: TextStyle(
                                color: _selectedTeams.isEmpty ? Colors.grey : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_selectedTeams.isNotEmpty) ...[
                      const Text(
                        'Danh sách tổ phụ trách',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (_successMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _successMessage!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _selectedTeams.length,
                              itemBuilder: (context, index) {
                                final team = _selectedTeams.elementAt(index);
                                return ListTile(
                                  title: Text('Tổ may $team'),
                                  trailing: _isEditing
                                      ? ElevatedButton(
                                          onPressed: () {
                                            if (mounted) {
                                              setState(() {
                                                _selectedTeams.remove(team);
                                                _tempSelectedTeams.remove(team);
                                              });
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.delete, color: Colors.white, size: 18),
                                              SizedBox(width: 4),
                                              Text('Xóa'),
                                            ],
                                          ),
                                        )
                                      : null,
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            if (_isEditing)
                              ElevatedButton(
                                onPressed: _saveSelectedTeams,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Lưu'),
                              ),
                            if (_isSaved && !_isEditing)
                              ElevatedButton(
                                onPressed: _startEditing,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Sửa'),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue[800], size: 24),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}