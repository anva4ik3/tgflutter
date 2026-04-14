import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api.dart';

typedef MessageCallback = void Function(Map<String, dynamic> msg);

class WsService {
  static const _wsUrl = 'wss://YOUR_RAILWAY_URL/ws'; // замени

  WebSocketChannel? _channel;
  final _controllers = <String, StreamController<Map<String, dynamic>>>{};
  final _globalController = StreamController<Map<String, dynamic>>.broadcast();
  bool _connected = false;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  Stream<Map<String, dynamic>> get messages => _globalController.stream;

  Future<void> connect() async {
    if (_connected) return;
    final token = await ApiService.getToken();
    if (token == null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse('$_wsUrl?token=$token'));
      _connected = true;

      _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          _globalController.add(msg);

          // Роутим по chatId если есть
          final chatId = msg['message']?['chat_id'] ?? msg['chatId'];
          if (chatId != null && _controllers.containsKey(chatId)) {
            _controllers[chatId]!.add(msg);
          }
        },
        onDone: () {
          _connected = false;
          _scheduleReconnect();
        },
        onError: (_) {
          _connected = false;
          _scheduleReconnect();
        },
      );

      // Ping каждые 30 сек
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        send({'type': 'ping'});
      });
    } catch (e) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), connect);
  }

  void send(Map<String, dynamic> data) {
    if (_connected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void joinChat(String chatId) {
    send({'type': 'join_chat', 'payload': {'chatId': chatId}});
  }

  void sendMessage(String chatId, String content, {String? replyTo}) {
    send({
      'type': 'send_message',
      'payload': {'chatId': chatId, 'content': content, 'replyTo': replyTo},
    });
  }

  void sendTyping(String chatId, bool isTyping) {
    send({
      'type': 'typing',
      'payload': {'chatId': chatId, 'isTyping': isTyping},
    });
  }

  void markRead(String chatId) {
    send({'type': 'mark_read', 'payload': {'chatId': chatId}});
  }

  void deleteMessage(String chatId, String messageId) {
    send({
      'type': 'delete_message',
      'payload': {'chatId': chatId, 'messageId': messageId},
    });
  }

  void editMessage(String chatId, String messageId, String content) {
    send({
      'type': 'edit_message',
      'payload': {'chatId': chatId, 'messageId': messageId, 'content': content},
    });
  }

  // Получить стрим для конкретного чата
  Stream<Map<String, dynamic>> chatStream(String chatId) {
    if (!_controllers.containsKey(chatId)) {
      _controllers[chatId] = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _controllers[chatId]!.stream;
  }

  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
  }
}

final wsService = WsService();
