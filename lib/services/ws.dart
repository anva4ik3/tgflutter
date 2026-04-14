import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api.dart';

class WsService {
  // Синхронизируем с baseUrl из api.dart — просто меняем https -> wss
  static String get _wsUrl =>
      ApiService.baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://') + '/ws';

  WebSocketChannel? _channel;
  final _globalController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatControllers = <String, StreamController<Map<String, dynamic>>>{};
  bool _connected = false;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  Stream<Map<String, dynamic>> get messages => _globalController.stream;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected) return;
    final token = await ApiService.getToken();
    if (token == null) return;

    try {
      final uri = Uri.parse('$_wsUrl?token=$token');
      _channel = WebSocketChannel.connect(uri);
      _connected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            _globalController.add(msg);

            // Роутим по chatId
            final chatId = msg['message']?['chat_id'] ?? msg['chatId'];
            if (chatId != null && _chatControllers.containsKey(chatId)) {
              _chatControllers[chatId]!.add(msg);
            }
          } catch (_) {}
        },
        onDone: () { _connected = false; _scheduleReconnect(); },
        onError: (_) { _connected = false; _scheduleReconnect(); },
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) => send({'type': 'ping'}));
    } catch (e) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), connect);
  }

  void send(Map<String, dynamic> data) {
    if (_connected && _channel != null) {
      try { _channel!.sink.add(jsonEncode(data)); } catch (_) {}
    }
  }

  void joinChat(String chatId) =>
      send({'type': 'join_chat', 'payload': {'chatId': chatId}});

  void sendMessage(String chatId, String content,
      {String? replyTo, String type = 'text',
       String? mediaUrl, String? mediaMime, int? mediaSize, int? mediaDuration}) {
    send({
      'type': 'send_message',
      'payload': {
        'chatId': chatId, 'content': content, 'type': type,
        if (replyTo != null) 'replyTo': replyTo,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaMime != null) 'mediaMime': mediaMime,
        if (mediaSize != null) 'mediaSize': mediaSize,
        if (mediaDuration != null) 'mediaDuration': mediaDuration,
      },
    });
  }

  void sendTyping(String chatId, bool isTyping) =>
      send({'type': 'typing', 'payload': {'chatId': chatId, 'isTyping': isTyping}});

  void markRead(String chatId, {String? messageId}) =>
      send({'type': 'mark_read', 'payload': {'chatId': chatId, if (messageId != null) 'messageId': messageId}});

  void deleteMessage(String chatId, String messageId) =>
      send({'type': 'delete_message', 'payload': {'chatId': chatId, 'messageId': messageId}});

  void editMessage(String chatId, String messageId, String content) =>
      send({'type': 'edit_message', 'payload': {'chatId': chatId, 'messageId': messageId, 'content': content}});

  void react(String chatId, String messageId, String emoji) =>
      send({'type': 'react', 'payload': {'chatId': chatId, 'messageId': messageId, 'emoji': emoji}});

  void forwardMessage(String fromChatId, String messageId, String toChatId) =>
      send({'type': 'forward_message', 'payload': {'fromChatId': fromChatId, 'messagId': messageId, 'toChatId': toChatId}});

  Stream<Map<String, dynamic>> chatStream(String chatId) {
    _chatControllers.putIfAbsent(
        chatId, () => StreamController<Map<String, dynamic>>.broadcast());
    return _chatControllers[chatId]!.stream;
  }

  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
  }
}

final wsService = WsService();
