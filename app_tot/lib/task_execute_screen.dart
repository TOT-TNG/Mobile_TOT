import 'package:flutter/material.dart';

class TaskExecutedScreen extends StatefulWidget {
  const TaskExecutedScreen({Key? key}) : super(key: key);

  @override
  _TaskExecutedScreenState createState() => _TaskExecutedScreenState();
}

class _TaskExecutedScreenState extends State<TaskExecutedScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> tasks = [];
  TabController? _dateTabController;
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = false;
  bool _isInitialized = false;
  List<String> dateRange = [];
  int fixedDays = 30; // Số ngày cố định luôn là 30

  // Dữ liệu mẫu tĩnh, thêm một đơn hàng mới
  final List<Map<String, dynamic>> sampleTasks = [
    {
      "materialCode": "MH001",
      "color": "Đỏ",
      "sizes": [
        {"size": "S", "quantity": 10},
        {"size": "M", "quantity": 15},
        {"size": "L", "quantity": 20},
      ],
      "totalQuantity": 45,
      "createdAtList": ["2025-05-06 08:00:00"],
      "team": "Tổ A",
    },
    {
      "materialCode": "MH002",
      "color": "Xanh",
      "sizes": [
        {"size": "M", "quantity": 8},
        {"size": "L", "quantity": 12},
      ],
      "totalQuantity": 20,
      "createdAtList": ["2025-05-06 09:30:00", "2025-05-06 14:00:00"],
      "team": "Tổ B",
    },
    {
      "materialCode": "MH003",
      "color": "Đen",
      "sizes": [
        {"size": "S", "quantity": 5},
        {"size": "XL", "quantity": 7},
      ],
      "totalQuantity": 12,
      "createdAtList": ["2025-05-07 10:00:00"],
      "team": "Tổ C",
    },
    {
      "materialCode": "MH004",
      "color": "Trắng",
      "sizes": [
        {"size": "M", "quantity": 10},
        {"size": "L", "quantity": 15},
      ],
      "totalQuantity": 25,
      "createdAtList": ["2025-05-10 13:00:00"],
      "team": "Tổ D",
    },
    {
      "materialCode": "MH005",
      "color": "Vàng",
      "sizes": [
        {"size": "S", "quantity": 5},
        {"size": "XL", "quantity": 8},
      ],
      "totalQuantity": 13,
      "createdAtList": ["2025-05-15 09:00:00"],
      "team": "Tổ E",
    },
    {
      "materialCode": "MH006",
      "color": "Hồng",
      "sizes": [
        {"size": "S", "quantity": 3},
        {"size": "M", "quantity": 7},
      ],
      "totalQuantity": 10,
      "createdAtList": ["2025-06-05 11:00:00"],
      "team": "Tổ F",
    },
    // Thêm đơn hàng mới
    {
      "materialCode": "MH007",
      "color": "Tím",
      "sizes": [
        {"size": "S", "quantity": 6},
        {"size": "M", "quantity": 9},
        {"size": "L", "quantity": 12},
      ],
      "totalQuantity": 27,
      "createdAtList": ["2025-05-06 15:00:00"],
      "team": "Tổ G",
    },
  ];

  void _updateDateRange() {
    final today = DateTime.now().toLocal();
    dateRange = List.generate(fixedDays, (index) {
      final date = today.add(Duration(days: index));
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    });

    final uniqueDatesFromTasks = tasks
        .where((task) => task['createdAtList'] != null && (task['createdAtList'] as List).isNotEmpty)
        .map((task) => DateTime.parse(task['createdAtList'][0]).toLocal().toString().split(' ')[0])
        .toSet()
        .toList();
    for (var date in uniqueDatesFromTasks) {
      final taskDate = DateTime.parse(date);
      final daysDiff = taskDate.difference(today).inDays;
      if (daysDiff >= 0 && daysDiff < fixedDays && !dateRange.contains(date)) {
        dateRange.add(date);
      }
    }
    dateRange.sort((a, b) => a.compareTo(b));
    if (dateRange.length > fixedDays) {
      dateRange = dateRange.sublist(0, fixedDays);
    }
  }

  void _updateTabController() {
    if (dateRange.isEmpty) return;

    final previousIndex = _dateTabController?.index ?? 0;
    _dateTabController?.dispose();
    _dateTabController = TabController(length: dateRange.length, vsync: this);
    _dateTabController!.index = previousIndex.clamp(0, dateRange.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _fetchTasksAndInitializeTabs();
    _searchController.addListener(_filterTasks);
  }

  Future<void> _fetchTasksAndInitializeTabs() async {
    setState(() {
      isLoading = true;
    });

    tasks = List.from(sampleTasks);
    _updateDateRange();
    _updateTabController();

    setState(() {
      isLoading = false;
      _isInitialized = true;
    });

    _dateTabController?.addListener(() {
      if (_dateTabController != null && !_dateTabController!.indexIsChanging) {
        final currentDate = DateTime.parse(dateRange[_dateTabController!.index]);
        final today = DateTime.now().toLocal();
        if (currentDate.isBefore(today) || _dateTabController!.index == dateRange.length - 1) {
          _updateDateRange();
          if (dateRange.length != _dateTabController!.length) {
            final previousIndex = _dateTabController!.index;
            _dateTabController!.dispose();
            _dateTabController = TabController(length: dateRange.length, vsync: this);
            _dateTabController!.index = previousIndex.clamp(0, dateRange.length - 1);
            setState(() {});
          }
        }
      }
    });
  }

  void _filterTasks() {
    setState(() {
      if (_searchController.text.isNotEmpty) {
        tasks = sampleTasks
            .where((task) =>
                task['materialCode']
                    .toString()
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()))
            .toList();
      } else {
        tasks = List.from(sampleTasks);
      }

      _updateDateRange();
      _updateTabController();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateTabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Giao Hàng',
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
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm mã hàng, màu, tổ...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                  borderSide: BorderSide(color: Colors.grey, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                  borderSide: BorderSide(color: Colors.blue, width: 2.0),
                ),
              ),
            ),
          ),
          // TabBar cho các ngày
          if (_isInitialized && dateRange.isNotEmpty && _dateTabController != null)
            Container(
              color: Colors.blue[800],
              child: TabBar(
                controller: _dateTabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                isScrollable: true,
                tabs: dateRange.map((date) => Tab(text: date)).toList(),
              ),
            ),
          // Danh sách đơn hàng theo ngày
          Expanded(
            child: Container(
              color: Colors.white,
              child: isLoading || !_isInitialized || dateRange.isEmpty || _dateTabController == null
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _dateTabController,
                      children: dateRange.map((date) {
                        final tasksForDate = tasks.where((task) {
                          if (task['createdAtList'] == null || (task['createdAtList'] as List).isEmpty) return false;
                          final taskDate = DateTime.parse(task['createdAtList'][0]).toLocal().toString().split(' ')[0];
                          return taskDate == date;
                        }).toList();

                        return tasksForDate.isEmpty
                            ? const Center(child: Text('Không có đơn hàng để hiển thị'))
                            : SingleChildScrollView(
                                child: Column(
                                  children: [
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(), // Tắt cuộn của ListView, để SingleChildScrollView xử lý
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                      itemCount: tasksForDate.length,
                                      itemBuilder: (context, index) {
                                        final task = tasksForDate[index];
                                        final sizes = (task['sizes'] as List<dynamic>? ?? [])
                                            .map((size) =>
                                                '${size['size']}: ${size['quantity'] == 0 ? 'Đã hết' : size['quantity']}')
                                            .join(', ');
                                        final times = (task['createdAtList'] as List<dynamic>? ?? [])
                                            .map((time) =>
                                                DateTime.parse(time).toLocal().toString().split('.')[0].split(' ')[1])
                                            .toList();

                                        return Card(
                                          color: Colors.white,
                                          elevation: 5,
                                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10.0),
                                            side: BorderSide(color: Colors.grey[300]!, width: 1),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${index + 1}. Đơn hàng ${index + 1}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                                const SizedBox(height: 8.0),
                                                Table(
                                                  border: TableBorder(
                                                    horizontalInside: BorderSide(
                                                      width: 1,
                                                      color: Colors.grey[300]!,
                                                    ),
                                                    verticalInside: BorderSide(
                                                      width: 1,
                                                      color: Colors.grey[300]!,
                                                    ),
                                                    top: BorderSide(
                                                      width: 1,
                                                      color: Colors.grey[300]!,
                                                    ),
                                                    bottom: BorderSide(
                                                      width: 1,
                                                      color: Colors.grey[300]!,
                                                    ),
                                                    left: BorderSide(
                                                      width: 1,
                                                      color: Colors.grey[300]!,
                                                    ),
                                                    right: BorderSide(
                                                      width: 1,
                                                      color: Colors.grey[300]!,
                                                    ),
                                                  ),
                                                  columnWidths: const {
                                                    0: FlexColumnWidth(1.5),
                                                    1: FlexColumnWidth(2),
                                                  },
                                                  children: [
                                                    TableRow(
                                                      children: [
                                                        const Padding(
                                                          padding: EdgeInsets.all(8.0),
                                                          child: Text(
                                                            'Mã Hàng',
                                                            style: TextStyle(fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.all(8.0),
                                                          child: Text(task['materialCode'] ?? 'Không có'),
                                                        ),
                                                      ],
                                                    ),
                                                    TableRow(
                                                      children: [
                                                        const Padding(
                                                          padding: EdgeInsets.all(8.0),
                                                          child: Text(
                                                            'Màu',
                                                            style: TextStyle(fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.all(8.0),
                                                          child: Text(task['color'] ?? 'Không có'),
                                                        ),
                                                      ],
                                                    ),
                                                    TableRow(
                                                      children: [
                                                        const Padding(
                                                          padding: EdgeInsets.all(8.0),
                                                          child: Text(
                                                            'Cỡ & Số Lượng',
                                                            style: TextStyle(fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.all(8.0),
                                                          child: Text(sizes.isNotEmpty ? sizes : 'Không có'),
                                                        ),
                                                      ],
                                                    ),
                                                    TableRow(
                                                      children: [
                                                        const Padding(
                                                          padding: EdgeInsets.all(8.0),
                                                          child: Text(
                                                            'Tổng Số Lượng',
                                                            style: TextStyle(fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.all(8.0),
                                                          child: Text(task['totalQuantity']?.toString() ?? '0'),
                                                        ),
                                                      ],
                                                    ),
                                                    TableRow(
                                                      children: [
                                                        const Padding(
                                                          padding: EdgeInsets.all(8.0),
                                                          child: Text(
                                                            'Thời Gian Cấp',
                                                            style: TextStyle(fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.all(8.0),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: times.map((time) => Padding(
                                                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                                                              child: Text(time),
                                                            )).toList(),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    TableRow(
                                                      children: [
                                                        const Padding(
                                                          padding: EdgeInsets.all(8.0),
                                                          child: Text(
                                                            'Tổ Cấp',
                                                            style: TextStyle(fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.all(8.0),
                                                          child: Text(task['team'] ?? 'Không có'),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                      }).toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}