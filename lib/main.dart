import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('독서캘린더'),
        centerTitle: true,
      ),

      body: Column(
        children: [
          // 🔵 월간 / 주간 선택 버튼
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _calendarFormat = CalendarFormat.month;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      color: _calendarFormat == CalendarFormat.month
                          ? Colors.blue.shade100
                          : Colors.white,
                    ),
                    child: const Text('월간'),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _calendarFormat = CalendarFormat.week;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      color: _calendarFormat == CalendarFormat.week
                          ? Colors.blue.shade100
                          : Colors.white,
                    ),
                    child: const Text('주간'),
                  ),
                ),
              ),
            ],
          ),

          // 🔵 날짜 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              _selectedDay == null
                  ? "날짜"
                  : DateFormat('yyyy년 MM월 dd일').format(_selectedDay!),
            ),
          ),

          // 🔵 실제 캘린더
          Expanded(
            flex: 3,
            child: TableCalendar(
              firstDay: DateTime(2000),
              lastDay: DateTime(2100),
              focusedDay: _focusedDay,

              calendarFormat: _calendarFormat,
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },

              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },

              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },

              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
              ),

              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.deepOrange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // 🔵 통계 영역 (스크롤)
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('독서시간 (스크롤다운)'),
                    SizedBox(height: 8),
                    Text('그래프'),
                    SizedBox(height: 8),
                    Text('가장 오래 읽은 책'),
                    SizedBox(height: 8),
                    Text('독서 횟수'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '캘린더',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: '통계',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
