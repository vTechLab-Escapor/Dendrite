import 'package:flutter/material.dart';
import 'package:dendrite/features/chat/widgets/selection_menu.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Dendrite Chat', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomSelectionMenu(
              onBranchAsk: (text) {
                // Show bottom sheet to capture user query for branching
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF121212),
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🌿 Branching Context: "$text"', style: const TextStyle(color: Color(0xFF10A37F))),
                        const TextField(
                          decoration: InputDecoration(hintText: 'Ask a branch question...'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  Text('Dendrite represents non-linear, organic tree-structured conversations.', style: TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
          ),
          // Clean Footer Input Row
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1A1A1A),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Send a message...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF10A37F)),
                  onPressed: () {},
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
