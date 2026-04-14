import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../services/api.dart';
import '../../../services/ws.dart';
import '../../../models/chat.dart';
import '../../../theme.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<Chat> _chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ru', timeago.RuMessages());
    _load();
    wsService.connect();
    wsService.messages.listen((msg) {
      if (msg['type'] == 'new_message') _load();
    });
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getChats();
      setState(() {
        _chats = (data as List).map((j) => Chat.fromJson(j)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        title: const Text('Сообщения'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showNewChat(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _chats.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text('Нет чатов', style: TextStyle(color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text('Найдите людей через поиск', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    itemCount: _chats.length,
                    itemBuilder: (_, i) => _ChatTile(
                      chat: _chats[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ChatScreen(chat: _chats[i])),
                      ).then((_) => _load()),
                    ),
                  ),
                ),
    );
  }

  void _showSearch() {
    showSearch(context: context, delegate: _UserSearchDelegate());
  }

  void _showNewChat() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NewChatSheet(onCreated: (chatId, name) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chat: Chat(id: chatId, type: 'direct', displayName: name),
            ),
          ),
        ).then((_) => _load());
      }),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;
  const _ChatTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Avatar(name: chat.displayName, url: chat.displayAvatar, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.lastMessageAt != null)
                        Text(
                          timeago.format(chat.lastMessageAt!, locale: 'ru'),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage ?? 'Нет сообщений',
                          style: TextStyle(
                            color: chat.lastMessage != null ? AppColors.textSecondary : AppColors.textMuted,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;
  const _Avatar({required this.name, this.url, required this.size});

  Color get _color {
    final colors = [
      AppColors.primary, AppColors.green, const Color(0xFFEB459E),
      const Color(0xFFFEE75C), AppColors.red,
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (url != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(url!),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _color.withOpacity(0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

class _UserSearchDelegate extends SearchDelegate {
  List _results = [];

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
        appBarTheme: const AppBarTheme(backgroundColor: AppColors.bg2),
        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(color: AppColors.textMuted),
          border: InputBorder.none,
        ),
      );

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length >= 2) _search();
    return _buildList(context);
  }

  Future<void> _search() async {
    final res = await ApiService.searchUsers(query);
    _results = res;
  }

  Widget _buildList(BuildContext context) {
    return FutureBuilder(
      future: query.length >= 2 ? ApiService.searchUsers(query) : Future.value([]),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final users = snap.data as List;
        if (users.isEmpty) return const Center(child: Text('Никого не найдено', style: TextStyle(color: AppColors.textSecondary)));
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            return ListTile(
              leading: _Avatar(name: u['display_name'] ?? u['username'], url: u['avatar_url'], size: 44),
              title: Text(u['display_name'] ?? u['username'], style: const TextStyle(color: AppColors.textPrimary)),
              subtitle: Text('@${u['username']}', style: const TextStyle(color: AppColors.textSecondary)),
              onTap: () async {
                final res = await ApiService.openDirectChat(u['id']);
                if (!context.mounted) return;
                close(context, null);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chat: Chat(id: res['chatId'], type: 'direct', displayName: u['display_name'] ?? u['username']),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  final Function(String chatId, String name) onCreated;
  const _NewChatSheet({required this.onCreated});
  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _ctrl = TextEditingController();
  List _results = [];

  Future<void> _search(String q) async {
    if (q.length < 2) return setState(() => _results = []);
    final res = await ApiService.searchUsers(q);
    setState(() => _results = res);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text('Новый чат', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Поиск по имени или @username'),
            onChanged: _search,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final u = _results[i];
              return ListTile(
                leading: _Avatar(name: u['display_name'] ?? u['username'], url: u['avatar_url'], size: 44),
                title: Text(u['display_name'] ?? u['username'], style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text('@${u['username']}', style: const TextStyle(color: AppColors.textSecondary)),
                onTap: () async {
                  final res = await ApiService.openDirectChat(u['id']);
                  widget.onCreated(res['chatId'], u['display_name'] ?? u['username']);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
