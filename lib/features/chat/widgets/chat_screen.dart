import 'package:flutter/material.dart';
import 'package:dendrite/features/chat/widgets/selection_menu.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isDarkMode = true; // Support both light and dark themes dynamically

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _controller.clear();
    });

    // Simulate AI response after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _messages.add({
          'sender': 'ai',
          'text': _getMockAIResponse(text),
        });
      });
    });
  }

  String _getMockAIResponse(String text) {
    if (text.contains('黑洞') || text.contains('事件视界')) {
      return '黑洞是时空展现出极端强大引力的区域。在黑洞的边缘，存在着一个被称为“事件视界”的边界，任何物质甚至光线，一旦穿过该边界就再也无法逃逸。\n\n💡 提示：长按上方任何文字以长出分叉（Branch Ask）进行深度脑暴。';
    } else if (text.contains('诗') || text.contains('写作')) {
      return '“枯藤老树昏鸦，小桥流水人家。” 这首词的意境极为深远，我们可以分拆出三个关键的分叉：\n1. 🌿 【昏鸦与秋意】：关于自然意象的冷色调脑暴。\n2. 🧠 【小桥流水】：代表着羁旅之思的戏剧反差。\n3. ✍️ 【古今翻译】：用现代诗歌重构古风。';
    } else {
      return '这是一个非常有趣的分支视角！我们可以以此为核心（Dendrite Node），向外延伸脑暴出更多子话题。请问你对这个视角的哪一部分最感兴趣？';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeBg = _isDarkMode ? const Color(0xFF171717) : const Color(0xFFFFFFFF);
    final themeText = _isDarkMode ? Colors.white : Colors.black;
    final themeSubText = _isDarkMode ? const Color(0xFFB4B4B4) : const Color(0xFF666666);
    final themeInputBg = _isDarkMode ? const Color(0xFF212121) : const Color(0xFFF4F4F4);
    final themeBorder = _isDarkMode ? const Color(0xFF2F2F2F) : const Color(0xFFE2E2E2);

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        backgroundColor: themeBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            _isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
            color: themeSubText,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _isDarkMode = !_isDarkMode;
            });
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dendrite 1.0',
              style: TextStyle(
                color: themeText,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, color: themeSubText, size: 16),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Color(0xFF10A37F), size: 20),
            onPressed: () {
              setState(() {
                _messages.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(themeText, themeSubText, themeBorder)
                : _buildMessageList(themeText, themeSubText),
          ),
          
          // Floating Input Capsule (Exact ChatGPT UI Style)
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 24,
              top: 8,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: themeInputBg,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: themeBorder, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '+',
                    style: TextStyle(
                      color: themeSubText,
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: themeText, fontSize: 14.5),
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: 'Message Dendrite...',
                        hintStyle: TextStyle(color: themeSubText.withOpacity(0.7)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_upward,
                        color: _isDarkMode ? Colors.black : Colors.white,
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => _sendMessage(_controller.text),
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

  // Beautiful ChatGPT Initial Page with custom vector Dendrite neural logo
  Widget _buildEmptyState(Color textCol, Color subTextCol, Color borderCol) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Custom Neural Vector Logo representation
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF10A37F).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF10A37F).withOpacity(0.3), width: 1.5),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(36, 36),
                  painter: DendriteLogoPainter(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '有什么我可以帮您的？',
              style: TextStyle(
                color: textCol,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            
            // Quick start capsule button options
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildPromptCard('🌿 介绍黑洞的“事件视界”', '开始对黑洞进行分叉提问', subTextCol, borderCol),
                _buildPromptCard('💡 脑暴一个科幻小说剧情', '分拆出多条故事发展主线', subTextCol, borderCol),
                _buildPromptCard('🧠 AI-Native 商业画布', '从一个核心痛点发散脑暴', subTextCol, borderCol),
                _buildPromptCard('✍️ 重构一首古诗的现代意境', '针对每一个核心意象长出分叉', subTextCol, borderCol),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard(String title, String subtitle, Color textCol, Color borderCol) {
    return GestureDetector(
      onTap: () {
        _controller.text = title.substring(2); // Strip emoji
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: textCol.withOpacity(0.8),
                fontSize: 9.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(Color textCol, Color subTextCol) {
    return CustomSelectionMenu(
      onBranchAsk: (text) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF212121) : const Color(0xFFF9F9F9),
                border: Border(
                  top: BorderSide(
                    color: _isDarkMode ? const Color(0xFF2F2F2F) : const Color(0xFFE2E2E2),
                    width: 1.0,
                  ),
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _isDarkMode ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '🌿 Branch Ask (分叉提问)',
                    style: TextStyle(
                      color: Color(0xFF10A37F),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? const Color(0xFF171717) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isDarkMode ? const Color(0xFF2F2F2F) : const Color(0xFFE2E2E2),
                      ),
                    ),
                    child: Text(
                      '“$text”',
                      style: TextStyle(
                        color: subTextCol,
                        fontSize: 13,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: _isDarkMode ? const Color(0xFF171717) : Colors.white,
                      border: Border.all(
                        color: _isDarkMode ? Colors.transparent : const Color(0xFFE2E2E2),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: TextStyle(color: textCol, fontSize: 13.5),
                            decoration: InputDecoration(
                              hintText: '关于该分支你想问什么？...',
                              hintStyle: TextStyle(color: subTextCol.withOpacity(0.7)),
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
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          final isUser = msg['sender'] == 'user';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF543FD7) : const Color(0xFF10A37F),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isUser ? 'Y' : 'D',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isUser ? 'You' : 'Dendrite',
                    style: TextStyle(
                      color: textCol,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 6, bottom: 24),
                child: Text(
                  msg['text'] ?? '',
                  style: TextStyle(
                    color: textCol,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Custom Painter to draw a clean vector neural branching Dendrite logo
class DendriteLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF10A37F)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw central glowing node
    final nodePaint = Paint()
      ..color = const Color(0xFF10A37F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, nodePaint);

    // Draw branching organic lines representing neural dendrites
    canvas.drawLine(center, Offset(center.dx - 12, center.dy - 12), paint);
    canvas.drawLine(center, Offset(center.dx + 12, center.dy - 8), paint);
    canvas.drawLine(center, Offset(center.dx - 4, center.dy + 14), paint);

    // Draw secondary sub-branches
    canvas.drawLine(Offset(center.dx - 12, center.dy - 12), Offset(center.dx - 18, center.dy - 10), paint);
    canvas.drawLine(Offset(center.dx - 12, center.dy - 12), Offset(center.dx - 14, center.dy - 18), paint);
    canvas.drawLine(Offset(center.dx + 12, center.dy - 8), Offset(center.dx + 18, center.dy - 16), paint);
    canvas.drawLine(Offset(center.dx + 12, center.dy - 8), Offset(center.dx + 16, center.dy + 2), paint);

    // Draw small node dots on branches
    canvas.drawCircle(Offset(center.dx - 18, center.dy - 10), 1.5, nodePaint);
    canvas.drawCircle(Offset(center.dx - 14, center.dy - 18), 1.5, nodePaint);
    canvas.drawCircle(Offset(center.dx + 18, center.dy - 16), 1.5, nodePaint);
    canvas.drawCircle(Offset(center.dx + 16, center.dy + 2), 1.5, nodePaint);
    canvas.drawCircle(Offset(center.dx - 4, center.dy + 14), 2.0, nodePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
