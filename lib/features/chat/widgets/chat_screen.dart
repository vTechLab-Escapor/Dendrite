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
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF10A37F),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF10A37F),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Dendrite',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 12.0, bottom: 12.0),
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                side: const BorderSide(color: Color(0xFF2F2F2F)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text(
                '🌿 树状图',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomSelectionMenu(
              onBranchAsk: (text) {
                // Show bottom sheet with premium dark-grey modal drawer style
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF121212),
                        border: Border(
                          top: BorderSide(color: Color(0xFF2F2F2F), width: 1.5),
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFF444444),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '🌿 新分支提问',
                            style: TextStyle(
                              color: Color(0xFF10A37F),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '“$text”',
                            style: const TextStyle(
                              color: Color(0xFF8E8E8F),
                              fontSize: 12,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D0D0D),
                              border: Border.all(color: const Color(0xFF2F2F2F)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: TextField(
                                    style: TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: '关于该边界你想问什么？...',
                                      hintStyle: TextStyle(color: Color(0xFF8E8E8F)),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10A37F),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_upward,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // User bubble: sleek rounded modern card
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                      margin: const EdgeInsets.only(bottom: 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                          bottomLeft: Radius.circular(22),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: const Text(
                        '你好，请向我介绍一下什么是黑洞。',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),

                  // AI Response: Editorial, clean, no-bubble layout (ChatGPT Mobile Style)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10A37F),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'D',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '黑洞是时空展现出极端强大引力的区域。在黑洞的边缘，存在着一个被称为“事件视界”的边界，任何物质甚至光线，一旦穿过该边界就再也无法逃逸。',
                              style: TextStyle(
                                color: Color(0xFFECECF1),
                                fontSize: 14.5,
                                height: 1.6,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '💡 提示：长按上方任何文字以长出分叉（Branch Ask）进行深度脑暴。',
                              style: TextStyle(
                                color: Color(0xFF8E8E8F),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Premium Floating Input Capsule
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 30,
              top: 8,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0xFF2F2F2F), width: 1.5),
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: '给 Dendrite 发送消息...',
                        hintStyle: TextStyle(color: Color(0xFF8E8E8F)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10A37F),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
