import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

////////////////////////////////////////////////////
///  🌗 앱 전체 테마 관리
////////////////////////////////////////////////////
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),

      home: HomeScreen(
        isDark: isDark,
        onThemeChanged: (v) => setState(() => isDark = v),
      ),
    );
  }
}

////////////////////////////////////////////////////
///  🏠 홈 + 하단 네비게이션
////////////////////////////////////////////////////
class HomeScreen extends StatefulWidget {
  final bool isDark;
  final Function(bool) onThemeChanged;

  const HomeScreen({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [
      const CalendarPage(),
      const DummyStatsPage(),
      DummySettingsPage(
        isDark: widget.isDark,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (v) => setState(() => index = v),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month), label: "캘린더"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "통계"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "설정"),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////
///  📅 캘린더 + 날짜 기록 저장
////////////////////////////////////////////////////
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime currentMonth = DateTime.now();

  Map<String, Map<String, String>> records = {};
  String key(DateTime d) => "${d.year}-${d.month}-${d.day}";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString("records");

    if (data != null) {
      setState(() {
        records = Map<String, Map<String, String>>.from(
          jsonDecode(data).map(
                (k, v) => MapEntry(k, Map<String, String>.from(v)),
          ),
        );
      });
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("records", jsonEncode(records));
  }

  @override
  Widget build(BuildContext context) {
    final last = DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final days = List.generate(
      last.day,
          (i) => DateTime(currentMonth.year, currentMonth.month, i + 1),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("독서캘린더"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          /// 월간 / 주간 UI (현재는 형태만 유지)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12)),
                  child: const Text("월간"),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12)),
                  child: const Text("주간"),
                ),
              ),
            ],
          ),

          /// 월 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
            child: Text(
              "${currentMonth.year}년 ${currentMonth.month}월",
              textAlign: TextAlign.center,
            ),
          ),

          /// 캘린더
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            currentMonth = DateTime(
                                currentMonth.year, currentMonth.month - 1);
                          });
                        },
                      ),
                      Text("${currentMonth.year}년 ${currentMonth.month}월"),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            currentMonth = DateTime(
                                currentMonth.year, currentMonth.month + 1);
                          });
                        },
                      ),
                    ],
                  ),

                  Expanded(
                    child: GridView.builder(
                      itemCount: days.length,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                      ),
                      itemBuilder: (context, index) {
                        final d = days[index];
                        final hasData = records.containsKey(key(d));

                        return GestureDetector(
                          onTap: () => openInput(d),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black26),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text("${d.day}"),
                                if (hasData)
                                  const Positioned(
                                    bottom: 6,
                                    child: CircleAvatar(
                                      radius: 5,
                                      backgroundColor: Colors.blue,
                                    ),
                                  )
                              ],
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

          /// 아래 통계 영역 (임시 유지)
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
              child: const Text("밑에 통계 UI (지금은 그대로 유지)"),
            ),
          ),
        ],
      ),
    );
  }

  void openInput(DateTime date) {
    final book = TextEditingController();
    final time = TextEditingController();
    final k = key(date);

    if (records.containsKey(k)) {
      book.text = records[k]!["book"] ?? "";
      time.text = records[k]!["time"] ?? "";
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("${date.year}/${date.month}/${date.day} 기록"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                decoration: const InputDecoration(labelText: "읽은 책"),
                controller: book),
            TextField(
              decoration: const InputDecoration(labelText: "읽은 시간(분)"),
              keyboardType: TextInputType.number,
              controller: time,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소")),
          ElevatedButton(
            onPressed: () async {
              records[k] = {"book": book.text, "time": time.text};
              await saveData();
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text("저장"),
          )
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////
/// 📊 통계 더미
////////////////////////////////////////////////////
class DummyStatsPage extends StatelessWidget {
  const DummyStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("통계 (나중에 구현)")),
    );
  }
}

////////////////////////////////////////////////////
/// ⚙️ 설정 + 다크모드 스위치
////////////////////////////////////////////////////
class DummySettingsPage extends StatelessWidget {
  final bool isDark;
  final Function(bool) onThemeChanged;

  const DummySettingsPage({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("설정")),
      body: ListTile(
        title: const Text("다크 모드"),
        trailing: Switch(
          value: isDark,
          onChanged: onThemeChanged,
        ),
      ),
    );
  }
}
