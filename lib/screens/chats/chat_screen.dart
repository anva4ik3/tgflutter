import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api.dart';
import '../../../services/ws.dart';
import '../../../models/chat.dart';
import '../../../models/chat.dart' show Message;
import '../../../theme.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;
  const ChatScreen({super.key, required this.chat});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Message> _messages = [];
  bool _loading = true;
  bool _aiMode = false;
  Message? _replyTo;
  String? _typingUser;
  Timer? _typingTimer;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    wsService.joinChat(widget.chat.id);
    _wsSub = wsService.chatStream(widget.chat.id).listen(_onWsMessage);
    wsService.markRead(widget.chat.id);
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'new_message':
        final m = Message.fromJson(msg['message']);
        setState(() => _messages.add(m));
        _scrollToBottom();
        wsService.markRead(widget.chat.id);
        break;
      case 'typing':
        if (msg['userId'] != null) {
          setState(() => _typingUser = msg['isTyping'] == true ? msg['userId'] : null);
        }
        break;
      case 'message_deleted':
        setState(() => _messages.removeWhere((m) => m.id == msg['messageId']));
        break;
      case 'message_edited':
        final updated = Message.fromJson(msg['message']);
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == updated.id);
          if (idx >= 0) _messages[idx] = updated;
        });
        break;
    }
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getMessages(widget.chat.id);
      setState(() {
        _messages = (data as List).map((j) => Message.fromJson(j)).toList();
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    if (_aiMode) {
      // AI режим
      final thinking = Message(
        id: 'thinking',
        chatId: widget.chat.id,
        senderId: 'ai',
        senderName: 'AI Ассистент',
        senderUsername: 'ai',
        content: '...',
        type: 'ai',
        createdAt: DateTime.now(),
      );
      setState(() {
        _messages.add(thinking);
        _aiMode = false;
      });
      _scrollToBottom();
      try {
        final response = await ApiService.askAi(widget.chat.id, text);
        setState(() {
          _messages.removeWhere((m) => m.id == 'thinking');
          _messages.add(Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            chatId: widget.chat.id,
            senderId: 'ai',
            senderName: 'AI Ассистент',
            senderUsername: 'ai',
            content: response,
            type: 'ai',
            createdAt: DateTime.now(),
          ));
        });
        _scrollToBottom();
      } catch (_) {
        setState(() => _messages.removeWhere((m) => m.id == 'thinking'));
      }
    } else {
      wsService.sendMessage(widget.chat.id, text, replyTo: _replyTo?.id);
      setState(() => _replyTo = null);
    }
  }

  void _onTyping(String v) {
    wsService.sendTyping(widget.chat.id, v.isNotEmpty);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      wsService.sendTyping(widget.chat.id, false);
    });
  }

  Future<void> _summarize() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
    try {
      final summary = await ApiService.summarizeChat(widget.chat.id);
      if (!mounted) return;
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.bg2,
          title: const Text('Резюме чата', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(summary, style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _typingTimer?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chat.displayName),
            if (_typingUser != null)
              const Text('печатает...', style: TextStyle(fontSize: 12, color: AppColors.green)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Резюме AI',
            onPressed: _summarize,
          ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _MessageBubble(
                      message: _messages[i],
                      onReply: (m) => setState(() => _replyTo = m),
                      onDelete: (m) => wsService.deleteMessage(widget.chat.id, m.id),
                    ),
                  ),
          ),
          // Reply preview
          if (_replyTo != null)
            Container(
              color: AppColors.bg3,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(width: 3, height: 36, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_replyTo!.senderName, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(_replyTo!.content, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _replyTo = null)),
                ],
              ),
            ),
          // Input
          Container(
            color: AppColors.bg2,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // AI toggle
                GestureDetector(
                  onTap: () => setState(() => _aiMode = !_aiMode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _aiMode ? AppColors.green.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: _aiMode ? AppColors.green : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: _aiMode ? 'Спросить AI...' : 'Сообщение...',
                      hintStyle: TextStyle(color: _aiMode ? AppColors.green.withOpacity(0.6) : AppColors.textMuted),
                      fillColor: AppColors.bg3,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: _onTyping,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final Function(Message) onReply;
  final Function(Message) onDelete;
  const _MessageBubble({required this.message, required this.onReply, required this.onDelete});

  bool get _isAi => message.type == 'ai';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar
            if (_isAi)
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 6, bottom: 2),
                decoration: BoxDecoration(
                  color: AppColors.aiAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.aiAccent),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isAi)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        message.senderName,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  // Reply preview
                  if (message.replyContent != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bg4,
                        borderRadius: BorderRadius.circular(6),
                        border: const Border(left: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(message.replySender ?? '', style: const TextStyle(color: AppColors.primary, fontSize: 11)),
                          Text(message.replyContent!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isAi ? AppColors.aiBubble : AppColors.bg3,
                      borderRadius: BorderRadius.circular(12),
                      border: _isAi ? Border.all(color: AppColors.aiAccent.withOpacity(0.3)) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.content,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message.createdAt),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                            ),
                            if (message.editedAt != null)
                              const Text(' · изменено', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.textSecondary),
              title: const Text('Ответить', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                onReply(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.textSecondary),
              title: const Text('Скопировать', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title: const Text('Удалить', style: TextStyle(color: AppColors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete(message);
              },
            ),
          ],
        ),
      ),
    );
  }
}
