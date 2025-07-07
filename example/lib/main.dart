import 'package:flutter/material.dart';
import 'cpcl_screen.dart';
import 'legacy_screen.dart';
import 'simplified_screen.dart';
import 'result_based_screen.dart';
import 'smart_discovery_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zebra Printer Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zebra Printer Demo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.print),
              text: 'CPCL Test',
            ),
            Tab(
              icon: Icon(Icons.settings),
              text: 'Legacy',
            ),
            Tab(
              icon: Icon(Icons.dashboard),
              text: 'Simplified',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'Result-Based',
            ),
            Tab(
              icon: Icon(Icons.explore),
              text: 'Smart Discovery',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CPCLScreen(),
          LegacyScreen(),
          SimplifiedScreen(),
          ResultBasedScreen(),
          SmartDiscoveryScreen(),
        ],
      ),
    );
  }
}
