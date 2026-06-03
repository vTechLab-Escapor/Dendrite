import 'package:flutter/material.dart';
import 'package:dendrite/features/chat/widgets/chat_screen.dart';

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
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(Colors.transparent),
          trackColor: WidgetStateProperty.all(Colors.transparent),
          thickness: WidgetStateProperty.all(0.0),
          interactive: false,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}
