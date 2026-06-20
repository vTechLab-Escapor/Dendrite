import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dendrite/features/chat/widgets/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On web, the browser's native context menu would otherwise pre-empt Flutter's
  // custom selection toolbar (the "🌿 Branch Ask" item). Disable it so right-click
  // on a text selection shows the in-app Branch menu.
  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  }
  runApp(const DendriteApp());
}

class DendriteApp extends StatelessWidget {
  const DendriteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dendrite',
      debugShowCheckedModeBanner: false,
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
