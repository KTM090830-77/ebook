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

  // Google Books에서 제목으로 검색하여 (title, authors, thumbnail) 리스트를 반환
  Future<List<Map<String, String>>> _searchBooksApi(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final q = Uri.https('www.googleapis.com', '/books/v1/volumes', {
        'q': 'intitle:$query',
        'maxResults': '5',
      });
      final res = await http.get(q).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final items = body['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final results = <Map<String, String>>[];
          for (final it in items) {
            final info = it['volumeInfo'] as Map<String, dynamic>?;
            if (info == null) continue;
            final title = (info['title'] ?? '').toString();
            final authors = (info['authors'] is List) ? (info['authors'] as List).join(", ") : (info['authors']?.toString() ?? "");
            String thumbnail = "";
            try {
              final imageLinks = info['imageLinks'] as Map<String, dynamic>?;
              if (imageLinks != null) {
                thumbnail = (imageLinks['thumbnail'] ?? imageLinks['smallThumbnail'] ?? "").toString();
                // 일부 썸네일 URL이 http일 수 있으므로 https로 보정
                if (thumbnail.isNotEmpty && thumbnail.startsWith('http:')) {
                  thumbnail = thumbnail.replaceFirst('http:', 'https:');
                }
              }
            } catch (_) {
              thumbnail = "";
            }
            if (title.isNotEmpty) {
              results.add({'title': title, 'authors': authors, 'thumbnail': thumbnail});
            }
          }
          return results;
        }
      }
    } catch (_) {}
    return [];
  }

  // 특정 컨트롤러 인덱스(i)에 대해 검색을 수행하고 결과 선택 UI를 띄움
  Future<void> _onSearchForController(int i, List<TextEditingController> bookControllers) async {
    final current = bookControllers[i].text.trim();
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final results = await _searchBooksApi(current);
    Navigator.pop(context); // 로딩 닫기

    if (results.isEmpty) {
      // 결과 없음 -> 원래 텍스트를 그대로 사용하도록 안내
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("검색 결과 없음"),
          content: Text(current.isEmpty ? "검색어가 비어 있습니다. 직접 입력하여 추가하세요." : "검색 결과가 없습니다.\n\"$current\" 를 그대로 사용하시겠습니까?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
            TextButton(
              onPressed: () {
                // 그대로 사용: 아무것도 안함(필드에 이미 입력되어 있음)
                Navigator.pop(ctx);
              },
              child: const Text("그대로 사용"),
            ),
          ],
        ),
      );
      return;
    }

    // 변경: 가로 스크롤하는 카드형 리스트 다이얼로그
    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: SizedBox(
            height: 460,
            child: Column(
              children: [
                // 가로 스크롤 리스트
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (c, idx) {
                        final item = results[idx];
                        final thumb = item['thumbnail'] ?? "";
                        final title = item['title'] ?? "";
                        final authors = item['authors'] ?? "";
                        return GestureDetector(
                          onTap: () {
                            bookControllers[i].text = title;
                            Navigator.pop(ctx);
                          },
                          child: SizedBox(
                            width: 260,
                            child: Card(
                              clipBehavior: Clip.hardEdge,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Stack(
                                children: [
                                  // 표지 이미지
                                  Positioned.fill(
                                    child: thumb.isNotEmpty
                                        ? Image.network(
                                            thumb,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => Container(
                                              color: Colors.black12,
                                              alignment: Alignment.center,
                                              child: const Icon(Icons.broken_image, size: 48),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.black12,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.book, size: 64),
                                          ),
                                  ),
                                  // 하단 반투명 오버레이: 제목/저자
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                      color: Colors.black.withOpacity(0.55),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          if (authors.isNotEmpty)
                                            Text(authors, style: const TextStyle(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // 우측 상단 작은 '선택' 버튼 (옵션)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(6)),
                                      child: IconButton(
                                        icon: const Icon(Icons.check, color: Colors.white, size: 20),
                                        onPressed: () {
                                          bookControllers[i].text = title;
                                          Navigator.pop(ctx);
                                        },
                                      ),
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
                ),

                // 취소 버튼
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, right: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 추가: 시간 입력 파서 및 포맷 유틸
  // 허용 형식 예시:
  // - "2시간 30분", "2시간30분", "2시 30분" (한글)
  // - "2:30", "2.5" (간단 지원하지 않음) -> 숫자만 입력하면 분으로 처리
  // - "150" -> 150분
  int _parseTimeInput(String s) {
    final st = s.trim();
    if (st.isEmpty) return 0;

    // 시/분 한글 패턴
    final regKor = RegExp(r'(?:(\d+)\s*(?:시간|시))?\s*(?:(\d+)\s*(?:분))?');
    final mKor = regKor.firstMatch(st);
    if (mKor != null && (mKor.group(1) != null || mKor.group(2) != null)) {
      final h = int.tryParse(mKor.group(1) ?? '') ?? 0;
      final mm = int.tryParse(mKor.group(2) ?? '') ?? 0;
      return h * 60 + mm;
    }

    // "HH:MM" 형식
    final regColon = RegExp(r'^(\d+)\s*[:]\s*(\d+)$');
    final mCol = regColon.firstMatch(st);
    if (mCol != null) {
      final h = int.tryParse(mCol.group(1) ?? '') ?? 0;
      final mm = int.tryParse(mCol.group(2) ?? '') ?? 0;
      return h * 60 + mm;
    }

    // 순수 숫자(분)
    final numOnly = int.tryParse(st.replaceAll(RegExp(r'[^0-9]'), ''));
    if (numOnly != null) return numOnly;

    return 0;
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return "";
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) {
      if (m > 0) return "${h}시간 ${m}분";
      return "${h}시간";
    }
    return "${m}분";
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

    // <-- controllers를 빌더 바깥에서 한 번만 생성하여 재빌드 시에도 유지되게 함
    final List<TextEditingController> bookControllers = [
      for (var b in initialBooks) TextEditingController(text: b),
    ];

    // 변경: 저장된 분(문자열)을 표시할 때 "X시간 Y분" 형식으로 보여주도록 변환
    final List<TextEditingController> timeControllers = [
      for (var t in initialTimes)
        TextEditingController(
            text: () {
              final minutes = int.tryParse(t.trim()) ?? 0;
              return minutes > 0 ? _formatMinutes(minutes) : t;
            }())
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

                          // 검색 버튼 추가: 검색 결과 있으면 선택, 없으면 그대로 사용 가능
                          IconButton(
                            icon: const Icon(Icons.search),
                            tooltip: "Google Books에서 검색",
                            onPressed: () async {
                              await _onSearchForController(i, bookControllers);
                              // TextField가 controller 변경을 반영하므로 다이얼로그 내 재렌더링 필요 시 호출
                              dialogSetState(() {});
                            },
                          ),

                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: timeControllers[i],
                              decoration: const InputDecoration(
                                labelText: "시간 (예: 2시간 30분 또는 150)",
                                hintText: "예: 1시간 20분 또는 80",
                              ),
                              keyboardType: TextInputType.text,
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
                // 저장 처리: 입력 문자열을 파싱하여 분으로 변환 (유효한 분 > 0인 항목만 저장)
                final List<String> books = [];
                final List<String> times = [];
                final len = bookControllers.length;
                for (var i = 0; i < len; i++) {
                  final b = bookControllers[i].text.trim();
                  final tRaw = timeControllers.length > i ? timeControllers[i].text.trim() : "";
                  final minutes = _parseTimeInput(tRaw);
                  if (minutes > 0) {
                    books.add(b);
                    times.add(minutes.toString());
                  }
                }

                if (books.isEmpty) {
                  // 모든 항목이 비어(또는 유효한 시간이 없어)졌다면 해당 날짜 레코드 삭제
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

  // 새로 추가: CalendarPage UI (CalendarDatePicker 기반)
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // 안전하게 initialDate 결정: currentMonth가 현재 달이면 '오늘'을, 아니면 해당 월의 1일을 사용
    DateTime initialDate;
    if (currentMonth.year == now.year && currentMonth.month == now.month) {
      // 오늘 날짜가 해당 월의 마지막 일을 넘지 않도록 보정
      final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
      final safeDay = now.day <= lastDay ? now.day : lastDay;
      initialDate = DateTime(currentMonth.year, currentMonth.month, safeDay);
    } else {
      initialDate = DateTime(currentMonth.year, currentMonth.month, 1);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("캘린더"),
      ),
      body: Column(
        children: [
          // 월 이동 컨트롤
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
                    });
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "${currentMonth.year}년 ${currentMonth.month}월",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
          ),

          // 기본 Flutter 캘린더
          // key를 month 단위로 주어 currentMonth 변경 시 캘린더가 재표시되도록 함
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CalendarDatePicker(
                key: ValueKey("${currentMonth.year}-${currentMonth.month}"),
                initialDate: initialDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                currentDate: DateTime.now(),
                onDateChanged: (date) {
                  // 날짜 선택 시 입력 다이얼로그 호출
                  openInput(date);
                },
                onDisplayedMonthChanged: (displayedDate) {
                  // 사용자가 달을 넘겼을 때 currentMonth 동기화
                  setState(() {
                    currentMonth = DateTime(displayedDate.year, displayedDate.month, 1);
                  });
                },
              ),
            ),
          ),
        ],
      )
      );
    }
  }


////////////////////////////////////////////////////
///  📊 통계 페이지 - 월별 목록 + 이번 주 그래프
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

  // 메모리 캐시: 제목 -> thumbnail URL
  final Map<String, String> _thumbCache = {};

  // 제목으로 Google Books에서 첫 결과의 thumbnail 가져오기(캐시 사용)
  Future<String> _fetchThumbnailForTitle(String title) async {
    if (title.isEmpty) return "";
    if (_thumbCache.containsKey(title)) return _thumbCache[title] ?? "";
    try {
      final q = Uri.https('www.googleapis.com', '/books/v1/volumes', {
        'q': 'intitle:${title}',
        'maxResults': '1',
      });
      final res = await http.get(q).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final info = items[0]['volumeInfo'] as Map<String, dynamic>?;
          if (info != null) {
            final imageLinks = info['imageLinks'] as Map<String, dynamic>?;
            if (imageLinks != null) {
              var thumb = (imageLinks['thumbnail'] ?? imageLinks['smallThumbnail'] ?? "").toString();
              if (thumb.isNotEmpty && thumb.startsWith('http:')) thumb = thumb.replaceFirst('http:', 'https:');
              _thumbCache[title] = thumb;
              return thumb;
            }
          }
        }
      }
    } catch (_) {}
    _thumbCache[title] = "";
    return "";
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
                    leading: FutureBuilder<String>(
                      future: _fetchThumbnailForTitle(book),
                      builder: (ctx, snap) {
                        final url = snap.data ?? "";
                        if (url.isEmpty) {
                          return CircleAvatar(child: Text("${i + 1}"));
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            url,
                            width: 40,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => CircleAvatar(child: Text("${i + 1}")),
                          ),
                        );
                      },
                    ),
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
                              // 소형 썸네일
                              FutureBuilder<String>(
                                future: _fetchThumbnailForTitle(book),
                                builder: (ctx, snap) {
                                  final url = snap.data ?? "";
                                  if (url.isEmpty) {
                                    return Container(width: 36, height: 48, color: Colors.transparent);
                                  }
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      url,
                                      width: 36,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(width: 36, height: 48, color: Colors.black12),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
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
            subtitle: const Text("켜면 월요일이 주의 첫 날로 표시됩니다(미작동)"),
            trailing: Switch(
              value: weekStartMonday,
              onChanged: (v) => onWeekStartChanged(v),
            ),
          ),

          const Divider(height: 1),

          // 독서감상문 항목 추가 (다크모드 위/아래 원하는 위치로 조정 가능)
          ListTile(
            title: const Text("독서감상문"),
            subtitle: const Text("지금까지 읽은 책 목록에서 선택하여 감상문을 작성/관리합니다"),
            trailing: const Icon(Icons.note_add),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReviewPage()),
              );
            },
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

// 새로 추가: ReviewPage (로컬 저장, 4000자 제한)
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  List<String> titles = [];
  String? selectedTitle;
  Map<String, String> reviews = {};
  final TextEditingController _ctrl = TextEditingController();
  bool loading = true;
  // 바이트 제한: 5000바이트
  final int maxBytes = 5000;

  @override
  void initState() {
    super.initState();
    _loadData();
    // 컨트롤러 리스너: 바이트 초과 시 자르기 및 UI 갱신
    _ctrl.addListener(() {
      final cur = _ctrl.text;
      final trimmed = _trimToBytes(cur, maxBytes);
      if (trimmed != cur) {
        // 잘라서 적용, 커서 끝으로 이동
        _ctrl.text = trimmed;
        _ctrl.selection = TextSelection.collapsed(offset: trimmed.length);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // 바이트 계산 유틸:
  // ASCII(<=127) : 1바이트, '\n' : 2바이트, 한글(AC00..D7A3) : 3바이트, 기타 비ASCII : 3바이트로 처리
  int _byteLength(String s) {
    var cnt = 0;
    for (final r in s.runes) {
      if (r == 10) {
        cnt += 2;
      } else if (r >= 0xAC00 && r <= 0xD7A3) {
        cnt += 3;
      } else if (r <= 127) {
        cnt += 1;
      } else {
        cnt += 3;
      }
    }
    return cnt;
  }

  // 바이트 제한에 맞춰 문자열을 잘라 반환 (문자 단위로 안전하게 잘라냄)
  String _trimToBytes(String s, int max) {
    final buf = StringBuffer();
    var cnt = 0;
    for (final r in s.runes) {
      int add;
      if (r == 10) {
        add = 2;
      } else if (r >= 0xAC00 && r <= 0xD7A3) {
        add = 3;
      } else if (r <= 127) {
        add = 1;
      } else {
        add = 3;
      }
      if (cnt + add > max) break;
      buf.write(String.fromCharCode(r));
      cnt += add;
    }
    return buf.toString();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsStr = prefs.getString("records");
    final Map<String, String> loadedReviews = {};
    final reviewsStr = prefs.getString("reviews");
    if (reviewsStr != null) {
      try {
        final decoded = jsonDecode(reviewsStr) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          loadedReviews[k] = v?.toString() ?? "";
        });
      } catch (_) {}
    }

    final Set<String> titleSet = {};
    if (recordsStr != null) {
      try {
        final raw = jsonDecode(recordsStr) as Map<String, dynamic>;
        raw.forEach((k, v) {
          if (v is Map) {
            if (v.containsKey("books")) {
              final books = (v["books"] is List)
                  ? List<String>.from(v["books"].map((e) => e.toString()))
                  : <String>[];
              for (var b in books) {
                final t = b.trim();
                if (t.isNotEmpty) titleSet.add(t);
              }
            } else {
              final bookStr = v["book"]?.toString() ?? "";
              final books = bookStr.trim().isEmpty
                  ? <String>[]
                  : bookStr.split(",").map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              for (var b in books) {
                final t = b.trim();
                if (t.isNotEmpty) titleSet.add(t);
              }
            }
          }
        });
      } catch (_) {}
    }

    // 리뷰에만 존재하는 제목도 목록에 포함
    titleSet.addAll(loadedReviews.keys.where((e) => e.trim().isNotEmpty));

    final list = titleSet.toList()..sort((a, b) => a.compareTo(b));

    setState(() {
      titles = list;
      reviews = loadedReviews;
      selectedTitle = titles.isNotEmpty ? titles.first : null;
      _ctrl.text = selectedTitle != null ? (reviews[selectedTitle] ?? "") : "";
      loading = false;
    });
  }

  Future<void> _saveReview() async {
    if (selectedTitle == null) return;
    final prefs = await SharedPreferences.getInstance();
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      reviews.remove(selectedTitle);
    } else {
      // 바이트 제한에 맞춰 잘라 저장
      final clipped = _trimToBytes(text, maxBytes);
      reviews[selectedTitle!] = clipped;
    }
    await prefs.setString("reviews", jsonEncode(reviews));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("저장되었습니다")));
    setState(() {});
  }

  Future<void> _deleteReview() async {
    if (selectedTitle == null) return;
    final prefs = await SharedPreferences.getInstance();
    reviews.remove(selectedTitle);
    await prefs.setString("reviews", jsonEncode(reviews));
    _ctrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("삭제되었습니다")));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("독서감상문")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("독서감상문")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: titles.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text("기록된 책이 없습니다.\n먼저 캘린더에 읽은 책을 추가해 주세요.", textAlign: TextAlign.center),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("책 선택", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedTitle,
                    isExpanded: true,
                    items: titles.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedTitle = v;
                        _ctrl.text = v != null ? (reviews[v] ?? "") : "";
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text("감상문 (최대 5000바이트)"),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "여기에 감상문을 작성하세요.",
                        helperText: "${_byteLength(_ctrl.text)} / $maxBytes bytes",
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveReview,
                        icon: const Icon(Icons.save),
                        label: const Text("저장"),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("삭제 확인"),
                              content: const Text("이 감상문을 삭제하시겠습니까?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("취소")),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("삭제")),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _deleteReview();
                          }
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text("삭제"),
                      ),
                    ],
                  )
                ],
              ),
      ),
    );
  }
}

