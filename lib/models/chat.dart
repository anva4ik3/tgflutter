class Chat {
  final String id;
  final String type; // direct | group
  final String displayName;
  final String? displayAvatar;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  Chat({
    required this.id,
    required this.type,
    required this.displayName,
    this.displayAvatar,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
        id: j['id'],
        type: j['type'],
        displayName: j['display_name'] ?? 'Чат',
        displayAvatar: j['display_avatar'],
        lastMessage: j['last_message'],
        lastMessageAt: j['last_message_at'] != null
            ? DateTime.parse(j['last_message_at'])
            : null,
        unreadCount: int.tryParse(j['unread_count']?.toString() ?? '0') ?? 0,
      );
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderUsername;
  final String? senderAvatar;
  final String content;
  final String type; // text | image | ai
  final String? replyTo;
  final String? replyContent;
  final String? replySender;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDeleted;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderUsername,
    this.senderAvatar,
    required this.content,
    this.type = 'text',
    this.replyTo,
    this.replyContent,
    this.replySender,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'],
        chatId: j['chat_id'] ?? '',
        senderId: j['sender_id'],
        senderName: j['display_name'] ?? j['username'] ?? 'Unknown',
        senderUsername: j['username'] ?? '',
        senderAvatar: j['avatar_url'],
        content: j['content'] ?? '',
        type: j['type'] ?? 'text',
        replyTo: j['reply_to'],
        replyContent: j['reply_content'],
        replySender: j['reply_sender'],
        createdAt: DateTime.parse(j['created_at']),
        editedAt: j['edited_at'] != null ? DateTime.parse(j['edited_at']) : null,
        isDeleted: j['deleted_at'] != null,
      );
}

class Channel {
  final String id;
  final String username;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String ownerName;
  final int subscriberCount;
  final bool isPublic;
  final double monthlyPrice;
  final bool isSubscribed;
  final bool isOwner;

  Channel({
    required this.id,
    required this.username,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.ownerName,
    this.subscriberCount = 0,
    this.isPublic = true,
    this.monthlyPrice = 0,
    this.isSubscribed = false,
    this.isOwner = false,
  });

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id: j['id'],
        username: j['username'],
        name: j['name'],
        description: j['description'],
        avatarUrl: j['avatar_url'],
        ownerName: j['owner_name'] ?? '',
        subscriberCount: j['subscriber_count'] ?? 0,
        isPublic: j['is_public'] ?? true,
        monthlyPrice: double.tryParse(j['monthly_price']?.toString() ?? '0') ?? 0,
        isSubscribed: j['is_subscribed'] ?? false,
        isOwner: j['is_owner'] ?? false,
      );
}
