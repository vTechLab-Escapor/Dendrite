import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart';
import 'package:dendrite/core/db/database.dart';

class AgentEngine {
  final AppDatabase db;
  
  AgentEngine({required this.db});

  Future<String> submitQuery({
    required String chatId,
    required String? parentId,
    required String query,
    required String? associatedSelection,
    required String providerUrl,
    required String apiKey,
    required String modelName,
  }) async {
    final String msgId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Save user's query first
    await db.into(db.messages).insert(MessagesCompanion.insert(
      id: msgId,
      parentId: Value(parentId),
      chatId: chatId,
      role: 'user',
      content: query,
      associatedSelection: Value(associatedSelection),
    ));

    // Gather full lineage context
    final contextHistory = await db.getAncestors(msgId);
    
    // Build messages payload
    final messagesPayload = contextHistory.map((m) => {
      'role': m.role,
      'content': m.content,
    }).toList();

    // Call API completions
    final response = await http.post(
      Uri.parse('$providerUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': modelName,
        'messages': messagesPayload,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API Request Failed: ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final aiAnswer = data['choices'][0]['message']['content'] as String;

    // Save AI answer
    final answerId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
    await db.into(db.messages).insert(MessagesCompanion.insert(
      id: answerId,
      parentId: Value(msgId),
      chatId: chatId,
      role: 'assistant',
      content: aiAnswer,
    ));

    return aiAnswer;
  }
}
