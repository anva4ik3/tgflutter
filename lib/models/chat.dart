class Chat {
  final String id;
  final String type;
  final String displayName;
  final String? displayAvatar;
  final String? lastMessage;
  final String? lastMessageType;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final int unreadCount;
  final bool isMuted;
  final bool partnerOnline;
  final DateTime? partnerLastSeen;

  const Chat({
    required this.id,
    required this.type,
    required this.displayName,
    this.displayAvatar,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageAt,
    this.lastSenderId,
    this.unreadCount = 0,
    this.isMuted = false,
    this.partnerOnline = false,
    this.partnerLastSeen,
  });

  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
    id: j['id'],
    type: j['type'],
    displayName: j['display_name'] ?? 'Чат',
    displayAvatar: j['display_avatar'],
    lastMessage: j['last_message'],
    lastMessageType: j['last_message_type'],
    lastMessageAt: j['last_message_at'] != null ? DateTime.tryParse(j['last_message_at']) : null,
    lastSenderId: j['last_sender_id'],
    unreadCount: int.tryParse(j['unread_count']?.toString() ?? '0') ?? 0,
    isMuted: j['is_muted'] ?? false,
    partnerOnline: j['partner_online'] ?? false,
    partnerLastSeen: j['partner_last_seen'] != null ? DateTime.tryParse(j['partner_last_seen']) : null,
  );
}

class Reaction {
  final String emoji;
  final int count;
  final bool mine;
  const Reaction({required this.emoji, required this.count, required this.mine});
  factory Reaction.fromJson(Map<String, dynamic> j) => Reaction(
    emoji: j['emoji'],
    count: int.tryParse(j['count']?.toString() ?? '1') ?? 1,
    mine: j['mine'] ?? false,
  );
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderUsername;
  final String? avatarUrl;
  final String? content;
  final String type;
  final String? mediaUrl;
  final String? mediaMime;
  final int? mediaSize;
  final int? mediaDuration;
  final String? replyContent;
  final String? replySender;
  final String? replyMediaUrl;
  final String? forwardedFrom;
  final bool isPinned;
  final DateTime? editedAt;
  final DateTime createdAt;
  final List<Reaction> reactions;
  final int readCount;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderUsername,
    this.avatarUrl,
    this.content,
    this.type = 'text',
    this.mediaUrl,
    this.mediaMime,
    this.mediaSize,
    this.mediaDuration,
    this.replyContent,
    this.replySender,
    this.replyMediaUrl,
    this.forwardedFrom,
    this.isPinned = false,
    this.editedAt,
    required this.createdAt,
    this.reactions = const [],
    this.readCount = 0,
  });

  factory Message.fromJson(Map<String, dynamic> j) {
    final rawReactions = j['reactions'];
    List<Reaction> reactions = [];
    if (rawReactions is List) {
      reactions = rawReactions
          .whereType<Map<String, dynamic>>()
          .map((r) => Reaction.fromJson(r))
          .toList();
    }
    return Message(
      id: j['id'],
      chatId: j['chat_id'],
      senderId: j['sender_id'] ?? '',
      senderName: j['display_name'] ?? j['sender_name'] ?? 'Unknown',
      senderUsername: j['username'] ?? '',
      avatarUrl: j['avatar_url'],
      content: j['content'],
      type: j['type'] ?? 'text',
      mediaUrl: j['media_url'],
      mediaMime: j['media_mime'],
      mediaSize: j['media_size'],
      mediaDuration: j['media_duration'],
      replyContent: j['reply_content'],
      replySender: j['reply_sender'],
      replyMediaUrl: j['reply_media_url'],
      forwardedFrom: j['forwarded_from'],
      isPinned: j['is_pinned'] ?? false,
      editedAt: j['edited_at'] != null ? DateTime.tryParse(j['edited_at']) : null,
      createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      reactions: reactions,
      readCount: int.tryParse(j['read_count']?.toString() ?? '0') ?? 0,
    );
  }

  Message copyWith({List<Reaction>? reactions, int? readCount}) => Message(
    id: id, chatId: chatId, senderId: senderId, senderName: senderName,
    senderUsername: senderUsername, avatarUrl: avatarUrl, content: content,
    type: type, mediaUrl: mediaUrl, mediaMime: mediaMime, mediaSize: mediaSize,
    mediaDuration: mediaDuration, replyContent: replyContent, replySender: replySender,
    replyMediaUrl: replyMediaUrl, forwardedFrom: forwardedFrom, isPinned: isPinned,
    editedAt: editedAt, createdAt: createdAt,
    reactions: reactions ?? this.reactions,
    readCount: readCount ?? this.readCount,
  );
}
