import 'package:flutter/material.dart';

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('독서캘린더'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 월간 / 주간
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Text('월간'),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Text('주간'),
                ),
              ),
            ],
          ),

          // 날짜
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
            ),
            child: const Text('날짜'),
          ),

          // 캘린더 영역
          Expanded(
            flex: 3,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
              ),
              child: const Text('캘린더'),
            ),
          ),

          // 통계 영역 (스크롤)
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
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

      // 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        items: const [
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
