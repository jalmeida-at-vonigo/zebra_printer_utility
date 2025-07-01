import 'package:flutter/material.dart';
import 'legacy_screen.dart';
import 'new_api_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zebra Printer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainTabs(),
    );
  }
}

class MainTabs extends StatelessWidget {
  const MainTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Zebra Printer Demo'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Legacy API', icon: Icon(Icons.history)),
              Tab(text: 'New API', icon: Icon(Icons.auto_awesome)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            LegacyPrinterScreen(),
            NewApiScreen(),
          ],
        ),
      ),
    );
  }
}
