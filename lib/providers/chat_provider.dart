import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  ChatMessage({required this.role, required this.content});
}

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  final _apiKey = dotenv.env['OPENAI_API_KEY'];
  final _model = dotenv.env['OPENAI_MODEL'] ?? 'gpt-3.5-turbo';
  final _baseUrl = 'https://api.openai.com/v1/chat/completions';

  void addUserMessage(String text) {
    _messages.add(ChatMessage(role: 'user', content: text));
    notifyListeners();
    sendToOpenAI(text);
  }

  Future<void> sendToOpenAI(String userMessage) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _error = 'OpenAI API key not set.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final messagesPayload = [
      {'role': 'system', 'content': 'You are a helpful assistant.'},
      ..._messages.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final resp = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messagesPayload,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final aiContent = data['choices'][0]['message']['content'] ?? '';
        _messages.add(ChatMessage(role: 'assistant', content: aiContent.trim()));
      } else {
        _error = 'API Error (${resp.statusCode}): ${resp.body}';
      }
    } catch (e) {
      _error = 'Request failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
