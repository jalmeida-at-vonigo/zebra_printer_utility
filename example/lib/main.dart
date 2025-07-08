import 'package:flutter/material.dart';

import 'screens/basic_print_screen.dart';
import 'screens/smart_print_screen.dart';
import 'screens/discovery_screen.dart';
import 'screens/direct_print_screen.dart';
import 'widgets/responsive_layout.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zebra Print Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: ResponsiveScaffold(
        title: 'Zebra Print Demo',
        screens: [
          ResponsiveScreen(
            label: 'Basic Print',
            icon: Icons.print,
            selectedIcon: Icons.print,
            builder: (context) => const BasicPrintScreen(),
          ),
          ResponsiveScreen(
            label: 'Smart Print',
            icon: Icons.smart_toy_outlined,
            selectedIcon: Icons.smart_toy,
            builder: (context) => const SmartPrintScreen(),
          ),
          ResponsiveScreen(
            label: 'Discovery',
            icon: Icons.search,
            selectedIcon: Icons.search,
            builder: (context) => const DiscoveryScreen(),
          ),
          ResponsiveScreen(
            label: 'Direct Print',
            icon: Icons.cable,
            selectedIcon: Icons.cable,
            builder: (context) => const DirectPrintScreen(),
          ),
        ],
      ),
    );
  }
}
