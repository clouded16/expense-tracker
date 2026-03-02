import 'package:flutter/material.dart';
import 'core/network/health_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HealthScreen(),
    );
  }
}

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  String result = "Checking...";

  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    try {
      final response = await HealthService.checkHealth();
      setState(() {
        result = response;
      });
    } catch (e) {
      setState(() {
        result = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Backend Health Check")),
      body: Center(
        child: Text(result),
      ),
    );
  }
}