import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api.dart';
import '../../services/ws.dart';
import '../../models/chat.dart';
import '../../theme.dart';
import '../../widgets/app_avatar.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;
  const ChatScreen({super.key, required this.chat});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _imagePicker = ImagePicker();
  List<Message> _messages = [];
  bool _loading = true;
  bool _aiMode = false;
  Message? _replyTo;
  Message? _editingMessage;
  String? _typingUserId;
  Timer? _typingTimer;
  StreamSubscription? _wsSub;
  String? _myUserId;
  bool _sendingMedia = false;

  @override
  void initState() {
    super.initState();
    _loadMyId();
    _loadMessages();
    wsService.joinChat(widget.chat.id);
    _wsSub = wsService.chatStream(widget.chat.id).listen(_onWsMessage);
    wsService.markRead(widget.chat.id);
  }

  Future<void> _loadMyId() async {
    try {
      final me = await ApiService.getMe();
      if (mounted) setState(() => _myUserId = me['id']);
    } catch (_) {}
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'new_message':
        final m = Message.fromJson(msg['message']);
        setState(() => _messages.add(m));
        _scrollToBottom();
        wsService.markRead(widget.chat.id, messageId: m.id);
        break;
      case 'typing':
        setState(() => _typingUserId = msg['isTyping'] == true ? msg['userId'] : null);
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
      case 'reaction_update':
        final msgId = msg['messageId'] as String?;
        if (msgId == null) return;
        final rawReactions = msg['reactions'] as List? ?? [];
        final reactions = rawReactions.map((r) {
          final myUserId = _myUserId;
          final isMine = myUserId != null && r['user_id'] == myUserId;
          return Reaction(
            emoji: r['emoji'],
            count: int.tryParse(r['count']?.toString() ?? '1') ?? 1,
            mine: isMine,
          );
        }).toList();
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx >= 0) _messages[idx] = _messages[idx].copyWith(reactions: reactions);
        });
        break;
      case 'message_read':
        final msgId = msg['messageId'] as String?;
        if (msgId == null) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx >= 0) {
            _messages[idx] = _messages[idx].copyWith(readCount: (_messages[idx].readCount) + 1);
          }
        });
        break;
    }
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService.getMessages(widget.chat.id);
      if (!mounted) return;
      setState(() {
        _messages = data.map((j) => Message.fromJson(j)).toList();
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    if (_editingMessage != null) {
      wsService.editMessage(widget.chat.id, _editingMessage!.id, text);
      setState(() => _editingMessage = null);
      return;
    }

    if (_aiMode) {
      final tempId = 'thinking_${DateTime.now().millisecondsSinceEpoch}';
      final thinking = Message(
        id: tempId, chatId: widget.chat.id, senderId: 'ai',
        senderName: 'AI', senderUsername: 'ai',
        content: '...', type: 'ai', createdAt: DateTime.now(),
      );
      setState(() { _messages.add(thinking); _aiMode = false; });
      _scrollToBottom();
      try {
        final response = await ApiService.askAi(widget.chat.id, text);
        setState(() {
          _messages.removeWhere((m) => m.id == tempId);
          _messages.add(Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            chatId: widget.chat.id, senderId: 'ai',
            senderName: 'AI', senderUsername: 'ai',
            content: response, type: 'ai', createdAt: DateTime.now(),
          ));
        });
        _scrollToBottom();
      } catch (_) {
        setState(() => _messages.removeWhere((m) => m.id == tempId));
      }
      return;
    }

    wsService.sendMessage(widget.chat.id, text, replyTo: _replyTo?.id);
    setState(() => _replyTo = null);
  }

  Future<void> _pickImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _sendingMedia = true);
    try {
      final bytes = await file.readAsBytes();
      final base64 = base64Encode(bytes);
      final mime = file.mimeType ?? 'image/jpeg';
      final uploaded = await ApiService.uploadMedia(base64, mime);
      wsService.sendMessage(
        widget.chat.id, '',
        type: 'image',
        mediaUrl: uploaded['url'],
        mediaMime: mime,
        mediaSize: uploaded['size'],
        replyTo: _replyTo?.id,
      );
      setState(() => _replyTo = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
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
          backgroundColor: AppColors.bg3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('AI Резюме', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(summary, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
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

  String _formatLastSeen() {
    if (widget.chat.partnerOnline) return 'онлайн';
    final ls = widget.chat.partnerLastSeen;
    if (ls == null) return '';
    final diff = DateTime.now().difference(ls);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return 'был(а) ${diff.inMinutes} мин. назад';
    if (diff.inDays < 1) return 'был(а) ${diff.inHours} ч. назад';
    return 'был(а) ${diff.inDays} дн. назад';
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
        leadingWidth: 40,
        titleSpacing: 0,
        title: Row(
          children: [
            AppAvatar(
              name: widget.chat.displayName,
              url: widget.chat.displayAvatar,
              size: 40,
              showOnline: widget.chat.type == 'direct',
              isOnline: widget.chat.partnerOnline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.chat.displayName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  if (_typingUserId != null)
                    const Text('печатает...', style: TextStyle(fontSize: 12, color: AppColors.primary))
                  else if (widget.chat.type == 'direct' && _formatLastSeen().isNotEmpty)
                    Text(_formatLastSeen(),
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.chat.partnerOnline ? AppColors.online : AppColors.textMuted,
                        )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined, size: 22),
            tooltip: 'AI Резюме',
            onPressed: _summarize,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showChatMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final isMe = m.senderId == _myUserId;
                      // Показываем дату-разделитель
                      final showDate = i == 0 ||
                          !_isSameDay(_messages[i - 1].createdAt, m.createdAt);
                      return Column(
                        children: [
                          if (showDate) _DateDivider(date: m.createdAt),
                          _MessageBubble(
                            message: m,
                            isMe: isMe,
                            onReply: (msg) => setState(() => _replyTo = msg),
                            onDelete: (msg) => wsService.deleteMessage(widget.chat.id, msg.id),
                            onEdit: (msg) {
                              setState(() {
                                _editingMessage = msg;
                                _ctrl.text = msg.content ?? '';
                              });
                            },
                            onReact: (msg, emoji) => wsService.react(widget.chat.id, msg.id, emoji),
                            onForward: (msg) => _showForwardDialog(msg),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          // Reply / Edit preview
          if (_replyTo != null || _editingMessage != null)
            _PreviewBar(
              replyTo: _replyTo,
              editingMessage: _editingMessage,
              onClose: () => setState(() { _replyTo = null; _editingMessage = null; _ctrl.clear(); }),
            ),
          // Input bar
          _InputBar(
            ctrl: _ctrl,
            aiMode: _aiMode,
            sendingMedia: _sendingMedia,
            onToggleAi: () => setState(() => _aiMode = !_aiMode),
            onSend: _send,
            onTyping: _onTyping,
            onPickImage: _pickImage,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.summarize_outlined, color: AppColors.textSecondary),
              title: const Text('AI Резюме', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () { Navigator.pop(context); _summarize(); },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined, color: AppColors.textSecondary),
              title: const Text('Закреплённые', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () { Navigator.pop(context); /* TODO: показать закреплённые */ },
            ),
            if (widget.chat.type == 'group')
              ListTile(
                leading: const Icon(Icons.people_outline, color: AppColors.textSecondary),
                title: const Text('Участники', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () { Navigator.pop(context); /* TODO: участники */ },
              ),
          ],
        ),
      ),
    );
  }

  void _showForwardDialog(Message msg) {
    // TODO: показать список чатов для пересылки
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Пересылка: в разработке'), backgroundColor: AppColors.bg3),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String _format() {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Сегодня';
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) return 'Вчера';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bg3.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(_format(),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ),
    ),
  );
}

class _PreviewBar extends StatelessWidget {
  final Message? replyTo;
  final Message? editingMessage;
  final VoidCallback onClose;
  const _PreviewBar({this.replyTo, this.editingMessage, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isEdit = editingMessage != null;
    final msg = isEdit ? editingMessage! : replyTo!;
    return Container(
      color: AppColors.bg2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(width: 3, height: 36, decoration: BoxDecoration(
            color: isEdit ? AppColors.yellow : AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Редактирование' : msg.senderName,
                  style: TextStyle(color: isEdit ? AppColors.yellow : AppColors.primary,
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  msg.type == 'image' ? '📷 Фото' : (msg.content ?? ''),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted), onPressed: onClose),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool aiMode;
  final bool sendingMedia;
  final VoidCallback onToggleAi;
  final VoidCallback onSend;
  final Function(String) onTyping;
  final VoidCallback onPickImage;

  const _InputBar({
    required this.ctrl, required this.aiMode, required this.sendingMedia,
    required this.onToggleAi, required this.onSend, required this.onTyping,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg2,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Media button
            if (!aiMode)
              GestureDetector(
                onTap: sendingMedia ? null : onPickImage,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.bg4, borderRadius: BorderRadius.circular(12)),
                  child: sendingMedia
                      ? const Center(child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
                      : const Icon(Icons.attach_file, color: AppColors.textSecondary, size: 20),
                ),
              ),
            if (!aiMode) const SizedBox(width: 6),
            // AI toggle
            GestureDetector(
              onTap: onToggleAi,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: aiMode ? AppColors.aiAccent.withOpacity(0.15) : AppColors.bg4,
                  borderRadius: BorderRadius.circular(12),
                  border: aiMode ? Border.all(color: AppColors.aiAccent.withOpacity(0.4)) : null,
                ),
                child: Icon(Icons.auto_awesome,
                    color: aiMode ? AppColors.aiAccent : AppColors.textMuted, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            // Text field
            Expanded(
              child: TextField(
                controller: ctrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                maxLines: 5,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: aiMode ? 'Спросить AI...' : 'Сообщение...',
                  hintStyle: TextStyle(
                    color: aiMode ? AppColors.aiAccent.withOpacity(0.6) : AppColors.textMuted,
                    fontSize: 15,
                  ),
                  fillColor: AppColors.bg4,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: onTyping,
              ),
            ),
            const SizedBox(width: 6),
            // Send
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final Function(Message) onReply;
  final Function(Message) onDelete;
  final Function(Message) onEdit;
  final Function(Message, String) onReact;
  final Function(Message) onForward;

  const _MessageBubble({
    required this.message, required this.isMe,
    required this.onReply, required this.onDelete,
    required this.onEdit, required this.onReact, required this.onForward,
  });

  bool get _isAi => message.type == 'ai';

  Color get _bubbleColor {
    if (_isAi) return AppColors.aiBubble;
    if (isMe) return AppColors.myBubble;
    return AppColors.otherBubble;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Padding(
        padding: EdgeInsets.only(
          top: 2, bottom: 2,
          left: isMe ? 48 : 8,
          right: isMe ? 8 : 48,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender name (only in groups or AI)
            if (!isMe && !_isAi)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(message.senderName,
                    style: const TextStyle(fontSize: 12, color: AppColors.primary,
                        fontWeight: FontWeight.w500)),
              ),
            // Forwarded label
            if (message.forwardedFrom != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.forward, size: 12, color: AppColors.textMuted),
                    SizedBox(width: 4),
                    Text('Переслано', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            // Bubble
            Container(
              decoration: BoxDecoration(
                color: _bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: _isAi ? Border.all(color: AppColors.aiAccent.withOpacity(0.3)) : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply preview inside bubble
                    if (message.replyContent != null || message.replyMediaUrl != null)
                      _ReplyPreviewInBubble(
                        sender: message.replySender ?? '',
                        content: message.replyContent,
                        mediaUrl: message.replyMediaUrl,
                        isMe: isMe,
                      ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.type == 'image' && message.mediaUrl != null)
                            _ImageContent(url: message.mediaUrl!),
                          if (message.content != null && message.content!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: message.type == 'image' ? 6 : 0),
                              child: Text(
                                message.content!,
                                style: TextStyle(
                                  color: _isAi ? AppColors.textPrimary :
                                    (isMe ? Colors.white : AppColors.textPrimary),
                                  fontSize: 14.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(message.createdAt),
                                style: TextStyle(
                                  color: isMe ? Colors.white.withOpacity(0.6) : AppColors.textMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                              if (message.editedAt != null)
                                Text(' · изм.',
                                    style: TextStyle(
                                        color: isMe ? Colors.white.withOpacity(0.5) : AppColors.textMuted,
                                        fontSize: 10.5)),
                              // Read receipt
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  message.readCount > 0 ? Icons.done_all : Icons.done,
                                  size: 13,
                                  color: message.readCount > 0
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.white.withOpacity(0.5),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Reactions
            if (message.reactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: message.reactions.map((r) => _ReactionChip(
                    reaction: r,
                    onTap: () => onReact(message, r.emoji),
                  )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick reactions
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '😂', '👍', '😮', '😢', '🔥'].map((e) => GestureDetector(
                  onTap: () { Navigator.pop(context); onReact(message, e); },
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                )).toList(),
              ),
            ),
            const Divider(color: AppColors.bg4, height: 1),
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.textSecondary),
              title: const Text('Ответить', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () { Navigator.pop(context); onReply(message); },
            ),
            ListTile(
              leading: const Icon(Icons.forward, color: AppColors.textSecondary),
              title: const Text('Переслать', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () { Navigator.pop(context); onForward(message); },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.textSecondary),
              title: const Text('Скопировать', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content ?? ''));
                Navigator.pop(context);
              },
            ),
            if (isMe) ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
              title: const Text('Редактировать', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () { Navigator.pop(context); onEdit(message); },
            ),
            if (isMe) ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title: const Text('Удалить', style: TextStyle(color: AppColors.red)),
              onTap: () { Navigator.pop(context); onDelete(message); },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyPreviewInBubble extends StatelessWidget {
  final String sender;
  final String? content;
  final String? mediaUrl;
  final bool isMe;
  const _ReplyPreviewInBubble({required this.sender, this.content, this.mediaUrl, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(
          color: isMe ? Colors.white.withOpacity(0.6) : AppColors.primary,
          width: 2,
        )),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sender, style: TextStyle(
            color: isMe ? Colors.white.withOpacity(0.8) : AppColors.primary,
            fontSize: 11, fontWeight: FontWeight.bold,
          )),
          if (content != null)
            Text(content!, style: TextStyle(
              color: isMe ? Colors.white.withOpacity(0.7) : AppColors.textSecondary,
              fontSize: 12,
            ), overflow: TextOverflow.ellipsis),
          if (mediaUrl != null && content == null)
            const Text('📷 Фото', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  final String url;
  const _ImageContent({required this.url});

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (url.startsWith('data:')) {
      final base64 = url.split(',').last;
      try {
        img = Image.memory(base64Decode(base64), fit: BoxFit.cover);
      } catch (_) {
        img = const Icon(Icons.broken_image, color: AppColors.textMuted);
      }
    } else {
      img = Image.network(url, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppColors.textMuted));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
          maxHeight: 300,
        ),
        child: img,
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final Reaction reaction;
  final VoidCallback onTap;
  const _ReactionChip({required this.reaction, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: reaction.mine ? AppColors.primaryGlow : AppColors.bg3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reaction.mine ? AppColors.primary.withOpacity(0.5) : AppColors.bg4,
        ),
      ),
      child: Text('${reaction.emoji} ${reaction.count}',
          style: const TextStyle(fontSize: 12)),
    ),
  );
}
