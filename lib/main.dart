import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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

  // week start 설정: true = Monday, false = Sunday
  bool weekStartMonday = true;

  @override
  void initState() {
    super.initState();
    _loadWeekStartPref();
  }

  Future<void> _loadWeekStartPref() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool('weekStartMonday');
    if (v != null && v != weekStartMonday) {
      setState(() {
        weekStartMonday = v;
      });
    }
  }

  Future<void> _setWeekStartPref(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('weekStartMonday', v);
    setState(() {
      weekStartMonday = v;
    });
  }

  // pages를 initState에서 고정 생성하지 않고
  // 현재 widget.isDark 값을 항상 반영하도록 getter로 변경합니다.
  List<Widget> get pages => [
        CalendarPage(weekStartMonday: weekStartMonday),
        const StatsPage(),
        DummySettingsPage(
          isDark: widget.isDark,
          onThemeChanged: widget.onThemeChanged,
          weekStartMonday: weekStartMonday,
          onWeekStartChanged: (v) => _setWeekStartPref(v),
        ),
      ];

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
  final bool weekStartMonday;
  const CalendarPage({super.key, required this.weekStartMonday});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime currentMonth = DateTime.now();

  // 각 키 -> { "books": List<String>, "times": List<String> }
  Map<String, Map<String, dynamic>> records = {};
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
      final raw = jsonDecode(data) as Map<String, dynamic>;
      final Map<String, Map<String, dynamic>> normalized = {};

      raw.forEach((k, v) {
        if (v is Map) {
          if (v.containsKey("books")) {
            // 이미 다중 형식: times가 없으면 빈 리스트로 초기화
            final books = (v["books"] is List)
                ? List<String>.from(v["books"].map((e) => e.toString()))
                : <String>[];
            final times = (v["times"] is List)
                ? List<String>.from(v["times"].map((e) => e.toString()))
                : <String>[];
            normalized[k] = {"books": books, "times": times};
          } else {
            // 레거시 포맷: "book": "A,B", "time": "30" 처리
            final bookStr = v["book"]?.toString() ?? "";
            final books = bookStr.trim().isEmpty
                ? <String>[]
                : bookStr.split(",").map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            // 기존에 단일 time이 있으면 books 수에 맞춰 채우거나, 책이 없으면 단일 times로 둠
            final legacyTime = v["time"]?.toString() ?? "";
            List<String> times = [];
            if (legacyTime.isNotEmpty) {
              if (books.isNotEmpty) {
                times = List<String>.filled(books.length, legacyTime);
              } else {
                times = [legacyTime];
              }
            }
            normalized[k] = {"books": books, "times": times};
          }
        }
      });

      setState(() {
        records = normalized;
      });
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("records", jsonEncode(records));
  }

  DateTime? _parseKeyToDate(String k) {
    try {
      final parts = k.split("-");
      if (parts.length >= 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final year = currentMonth.year;
    final month = currentMonth.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text("독서캘린더"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          /// 월간 / 주간 UI (간단 유지)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
                  child: const Text("월간"),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
                  child: const Text("주간"),
                ),
              ),
            ],
          ),

          // 월 표시 + prev/next
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      currentMonth = DateTime(year, month - 1);
                    });
                  },
                ),
                Text("${year}년 ${month}월", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      currentMonth = DateTime(year, month + 1);
                    });
                  },
                ),
              ],
            ),
          ),

          // 기본 CalendarDatePicker로 교체: 레이아웃/크기 문제 해소
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 360,
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Builder(builder: (context) {
                    final now = DateTime.now();
                    final initialForPicker = (currentMonth.year == now.year && currentMonth.month == now.month)
                        ? now
                        : DateTime(year, month, 1);

                    return CalendarDatePicker(
                      key: ValueKey("${currentMonth.year}-${currentMonth.month}-${widget.weekStartMonday}"),
                      initialDate: initialForPicker,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      currentDate: DateTime.now(),
                      onDateChanged: (d) => openInput(d),
                    );
                  }),
                ),
              ),
            ),
          ),

          // 남은 공간(필요 시 통계 위젯을 별도 페이지에서 제공)
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void openInput(DateTime date) {
    final k = key(date);

    // 초기화된 책 컨트롤러 리스트와 시간 컨트롤러
    final initialBooks = (records[k]?['books'] is List)
        ? List<String>.from(records[k]!['books'].map((e) => e.toString()))
        : <String>[];
    final initialTimes = (records[k]?['times'] is List)
        ? List<String>.from(records[k]!['times'].map((e) => e.toString()))
        : <String>[];

    // <-- 변경점: controllers를 빌더 바깥에서 한 번만 생성하여 재빌드 시에도 유지되게 함
    final List<TextEditingController> bookControllers = [
      for (var b in initialBooks) TextEditingController(text: b),
    ];
    final List<TextEditingController> timeControllers = [
      for (var t in initialTimes) TextEditingController(text: t),
    ];
    // 항상 최소 하나의 쌍을 유지
    if (bookControllers.isEmpty) {
      bookControllers.add(TextEditingController());
    }
    if (timeControllers.isEmpty) {
      timeControllers.add(TextEditingController());
    }
    // 두 리스트 길이 맞추기
    while (timeControllers.length < bookControllers.length) {
      timeControllers.add(TextEditingController());
    }
    while (bookControllers.length < timeControllers.length) {
      bookControllers.add(TextEditingController());
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, dialogSetState) {
        return AlertDialog(
          title: Text("${date.year}/${date.month}/${date.day} 기록"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 책 리스트 입력
                Column(
                  children: List.generate(bookControllers.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: bookControllers[i],
                              decoration: InputDecoration(
                                labelText: "읽은 책 ${i + 1}",
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: timeControllers[i],
                              decoration: const InputDecoration(
                                labelText: "분",
                                hintText: "0",
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 삭제 버튼 (한 개만 남기면 삭제 불가하게 유지)
                          if (bookControllers.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                dialogSetState(() {
                                  bookControllers.removeAt(i);
                                  timeControllers.removeAt(i);
                                });
                              },
                            )
                        ],
                      ),
                    );
                  }),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        dialogSetState(() {
                          bookControllers.add(TextEditingController());
                          timeControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("책 추가"),
                    ),
                  ],
                ),

                // (단일 시간 필드는 제거됨 - 각 책 옆의 '분' 필드를 사용)
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("취소")),
            ElevatedButton(
              onPressed: () async {
                // 저장 처리: 인덱스별로 책/시간 쌍을 확인하여, 둘 다 비어있지 않거나 하나라도 값이 있으면 포함
                final List<String> books = [];
                final List<String> times = [];
                final len = bookControllers.length;
                for (var i = 0; i < len; i++) {
                  final b = bookControllers[i].text.trim();
                  final t = timeControllers.length > i ? timeControllers[i].text.trim() : "";
                  if (b.isNotEmpty || t.isNotEmpty) {
                    books.add(b);
                    times.add(t);
                  }
                }

                if (books.isEmpty && times.isEmpty) {
                  if (records.containsKey(k)) {
                    records.remove(k);
                    await saveData();
                    setState(() {});
                  }
                } else {
                  records[k] = {"books": books, "times": times};
                  await saveData();
                  setState(() {});
                }
                Navigator.pop(context);
              },
              child: const Text("저장"),
            )
          ],
        );
      }),
    );
  }
}

////////////////////////////////////////////////////
/// 📊 통계 페이지 - 월별 목록 + 이번 주 그래프
////////////////////////////////////////////////////
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool loading = true;
  Map<String, Map<String, dynamic>> normalized = {};
  DateTime selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAndNormalize();
  }

  Future<void> _loadAndNormalize() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString("records");

    final Map<String, Map<String, dynamic>> norm = {};

    if (data != null) {
      final raw = jsonDecode(data) as Map<String, dynamic>;
      raw.forEach((k, v) {
        if (v is Map) {
          if (v.containsKey("books")) {
            final books = (v["books"] is List)
                ? List<String>.from(v["books"].map((e) => e.toString()))
                : <String>[];
            final times = (v["times"] is List)
                ? List<String>.from(v["times"].map((e) => e.toString()))
                : <String>[];
            norm[k] = {"books": books, "times": times};
          } else {
            final bookStr = v["book"]?.toString() ?? "";
            final books = bookStr.trim().isEmpty
                ? <String>[]
                : bookStr.split(",").map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            final legacyTime = v["time"]?.toString() ?? "";
            List<String> times = [];
            if (legacyTime.isNotEmpty) {
              if (books.isNotEmpty) {
                times = List<String>.filled(books.length, legacyTime);
              } else {
                times = [legacyTime];
              }
            }
            norm[k] = {"books": books, "times": times};
          }
        }
      });
    }

    setState(() {
      normalized = norm;
      loading = false;
    });
  }

  DateTime? _parseKeyToDate(String k) {
    try {
      final parts = k.split("-");
      if (parts.length >= 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }

  // 주어진 범위(포함) 내의 책별 합계 계산
  Map<String, int> _aggregateInRange(DateTime startInclusive, DateTime endInclusive) {
    final Map<String, int> agg = {};
    normalized.forEach((k, v) {
      final dt = _parseKeyToDate(k);
      if (dt == null) return;
      if (dt.isBefore(startInclusive) || dt.isAfter(endInclusive)) return;

      final books = (v['books'] is List) ? List<String>.from(v['books'].map((e) => e.toString())) : <String>[];
      final times = (v['times'] is List) ? List<String>.from(v['times'].map((e) => e.toString())) : <String>[];

      final len = books.length > times.length ? books.length : times.length;
      for (var i = 0; i < len; i++) {
        final bookRaw = (i < books.length ? books[i] : "").trim();
        final book = bookRaw.isEmpty ? "(무명)" : bookRaw;
        final rawTime = (i < times.length ? times[i].trim() : "");
        final minutes = int.tryParse(rawTime) ?? 0;
        if (minutes <= 0 && book == "(무명)") continue;
        agg[book] = (agg[book] ?? 0) + minutes;
      }
    });
    return agg;
  }

  Map<String, int> _aggregateForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    return _aggregateInRange(start, end);
  }

  Map<String, int> _aggregateForCurrentWeek() {
    final now = DateTime.now();
    // 이번 주의 월요일을 시작으로 (월요일~일요일)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return _aggregateInRange(DateTime(monday.year, monday.month, monday.day), DateTime(sunday.year, sunday.month, sunday.day));
  }

  void _prevMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    });
  }

  // 기간(일) 단위로 최근 읽은 책들의 '분' 합을 책 제목별로 집계
  Map<String, int> _gatherRecentBookMinutes({int days = 30}) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    final Map<String, int> bookMinutes = {};
    normalized.forEach((k, v) {
      final dt = _parseKeyToDate(k);
      if (dt == null) return;
      if (dt.isBefore(cutoff)) return;
      final books = (v['books'] is List) ? List<String>.from(v['books'].map((e) => e.toString())) : <String>[];
      final times = (v['times'] is List) ? List<String>.from(v['times'].map((e) => e.toString())) : <String>[];
      final len = books.length > times.length ? books.length : times.length;
      for (var i = 0; i < len; i++) {
        final titleRaw = (i < books.length ? books[i] : "").trim();
        final title = titleRaw.isEmpty ? "(무명)" : titleRaw;
        final minutes = int.tryParse((i < times.length ? times[i] : "").trim()) ?? 0;
        if (minutes <= 0) continue;
        bookMinutes[title] = (bookMinutes[title] ?? 0) + minutes;
      }
    });
    return bookMinutes;
  }

  // 간단한 Google Books API 조회: 제목으로 검색해 첫 결과의 categories[0] 반환
  Future<String> _fetchCategoryForTitle(String title) async {
    try {
      final q = Uri.https('www.googleapis.com', '/books/v1/volumes', {
        'q': 'intitle:${title}',
        'maxResults': '1',
      });
      final res = await http.get(q).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final items = json['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final categories = items[0]['volumeInfo']?['categories'] as List<dynamic>?;
          if (categories != null && categories.isNotEmpty) {
            return categories[0].toString();
          }
        }
      }
    } catch (_) {}
    return "Unknown";
  }

  // 최근 days일 동안의 책별 분을 장르별로 합산해 반환
  Future<Map<String, int>> _analyzeRecentGenres({int days = 30}) async {
    final bookMinutes = _gatherRecentBookMinutes(days: days);
    final Map<String, int> genreTotals = {};
    for (final entry in bookMinutes.entries) {
      final title = entry.key;
      final minutes = entry.value;
      final category = await _fetchCategoryForTitle(title);
      genreTotals[category] = (genreTotals[category] ?? 0) + minutes;
      // 가급적 느린 요청이므로 필요하면 delay 또는 병렬 처리/캐싱 고려
    }
    return genreTotals;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("통계")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final monthAgg = _aggregateForMonth(selectedMonth);
    final monthEntries = monthAgg.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final monthTotal = monthAgg.values.fold<int>(0, (p, e) => p + e);

    final weekAgg = _aggregateForCurrentWeek();
    final weekEntries = weekAgg.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final weekMax = weekEntries.isNotEmpty ? weekEntries.first.value : 0;
    final weekTotal = weekAgg.values.fold<int>(0, (p, e) => p + e);

    return Scaffold(
      appBar: AppBar(
        title: const Text("통계"),
        actions: [
          // 장르 분석 버튼 추가
          IconButton(
            icon: const Icon(Icons.pie_chart),
            tooltip: "최근 장르 분석",
            onPressed: () async {
              final dlg = showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  content: Row(children: const [CircularProgressIndicator(), SizedBox(width: 12), Text("분석 중...")]),
                ),
              );
              final result = await _analyzeRecentGenres(days: 30);
              Navigator.pop(context); // 로딩 다이얼로그 닫기
              final entries = result.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("최근 30일 장르 분석"),
                  content: SizedBox(
                    width: 320,
                    child: entries.isEmpty
                        ? const Text("최근 30일 내 분석할 기록이 없습니다.")
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: entries.map((e) => ListTile(
                                  title: Text(e.key),
                                  trailing: Text("${e.value}분"),
                                )).toList(),
                          ),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("닫기"))],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAndNormalize,
            tooltip: "새로고침",
          )
        ],
      ),
      body: Column(
        children: [
          // 월별 요약 (상단)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
                Expanded(
                  child: Text(
                    "${selectedMonth.year}년 ${selectedMonth.month}월  — 총 ${monthTotal}분, ${monthEntries.length}권",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
              ],
            ),
          ),

          // 월별 목록
          if (monthEntries.isEmpty)
            Container(padding: const EdgeInsets.all(16), child: const Text("선택한 달에 기록된 데이터가 없습니다."))
          else
            SizedBox(
              height: 160,
              child: ListView.builder(
                itemCount: monthEntries.length,
                itemBuilder: (context, i) {
                  final book = monthEntries[i].key;
                  final minutes = monthEntries[i].value;
                  return ListTile(
                    leading: CircleAvatar(child: Text("${i + 1}")),
                    title: Text(book),
                    subtitle: Text("총 ${minutes}분"),
                    trailing: Text("${(minutes / 60).toStringAsFixed(1)}h"),
                  );
                },
              ),
            ),

          const Divider(height: 1),

          // 이번 주 그래프 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("이번 주 읽기 (월~일)", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("총 ${weekTotal}분"),
              ],
            ),
          ),

          // 그래프 영역
          Expanded(
            child: weekEntries.isEmpty
                ? Center(child: Text("이번 주 기록이 없습니다."))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListView.builder(
                      itemCount: weekEntries.length,
                      itemBuilder: (context, i) {
                        final book = weekEntries[i].key;
                        final minutes = weekEntries[i].value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(book, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 7,
                                child: LayoutBuilder(builder: (context, constraints) {
                                  final maxW = constraints.maxWidth;
                                  final w = weekMax > 0 ? (minutes / weekMax) * maxW : 0.0;
                                  return Stack(
                                    children: [
                                      Container(
                                        width: maxW,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.black12,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        width: w,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 56,
                                child: Text("${minutes}m", textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////
/// ⚙️ 설정 + 다크모드 스위치 (주 시작 옵션 추가)
////////////////////////////////////////////////////
class DummySettingsPage extends StatelessWidget {
  final bool isDark;
  final Function(bool) onThemeChanged;
  final bool weekStartMonday;
  final Function(bool) onWeekStartChanged;

  const DummySettingsPage({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
    required this.weekStartMonday,
    required this.onWeekStartChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("설정")),
      body: Column(
        children: [
          // 추가된 설정: 한 주 시작 지정 (위에 위치)
          ListTile(
            title: const Text("한 주의 시작을 월요일로 할까요?"),
            subtitle: const Text("켜면 월요일이 주의 첫 날로 표시됩니다(현재 동작하지 않습니다)"),
            trailing: Switch(
              value: weekStartMonday,
              onChanged: (v) => onWeekStartChanged(v),
            ),
          ),

          const Divider(height: 1),

          ListTile(
            title: const Text("다크 모드"),
            trailing: Switch(
              value: isDark,
              onChanged: onThemeChanged,
            ),
          ),
        ],
      ),
    );
  }
}
