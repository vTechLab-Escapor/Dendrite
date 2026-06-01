import 'package:flutter/material.dart';

void main() {
  runApp(const DendriteApp());
}

class DendriteApp extends StatelessWidget {
  const DendriteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dendrite',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: const Color(0xFF10A37F),
      ),
      home: const Scaffold(
        body: Center(child: Text('Welcome to Dendrite')),
      ),
    );
  }
}
