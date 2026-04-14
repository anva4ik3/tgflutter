import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/api.dart';
import '../../services/ws.dart';
import '../../models/chat.dart';
import '../../theme.dart';
import '../../widgets/app_avatar.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<Chat> _chats = [];
  bool _loading = true;
  // Онлайн-статусы
  final Map<String, bool> _onlineMap = {};

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ru', timeago.RuMessages());
    _load();
    wsService.connect();
    wsService.messages.listen((msg) {
      if (msg['type'] == 'new_message') _load();
      if (msg['type'] == 'user_status') {
        setState(() => _onlineMap[msg['userId']] = msg['online'] ?? false);
        // Обновим чат
        _load();
      }
    });
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getChats();
      if (!mounted) return;
      setState(() {
        _chats = data.map((j) => Chat.fromJson(j)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Сообщения', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
            ),
            onPressed: () => showSearch(context: context, delegate: _UserSearchDelegate()),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
            ),
            onPressed: _showNewChat,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _chats.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  backgroundColor: AppColors.bg3,
                  child: ListView.builder(
                    itemCount: _chats.length,
                    itemBuilder: (_, i) {
                      final c = _chats[i];
                      return _ChatTile(
                        chat: c,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatScreen(chat: c)),
                        ).then((_) => _load()),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.primaryGlow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        const Text('Нет диалогов', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Найдите людей через кнопку поиска', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      ],
    ),
  );

  void _showNewChat() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => _NewChatSheet(
          scrollCtrl: sc,
          onCreated: (chatId, name, avatar) {
            Navigator.pop(context);
            Navigator.push(context,
              MaterialPageRoute(builder: (_) => ChatScreen(
                chat: Chat(id: chatId, type: 'direct', displayName: name, displayAvatar: avatar),
              )),
            ).then((_) => _load());
          },
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;
  const _ChatTile({required this.chat, required this.onTap});

  String _lastMsgPreview() {
    if (chat.lastMessage == null) return 'Нет сообщений';
    if (chat.lastMessageType == 'image') return '📷 Фото';
    if (chat.lastMessageType == 'voice') return '🎤 Голосовое';
    if (chat.lastMessageType == 'file') return '📎 Файл';
    return chat.lastMessage!;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AppAvatar(
              name: chat.displayName,
              url: chat.displayAvatar,
              size: 54,
              showOnline: chat.type == 'direct',
              isOnline: chat.partnerOnline,
            ),
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
                            fontSize: 15.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.lastMessageAt != null)
                        Text(
                          timeago.format(chat.lastMessageAt!, locale: 'ru'),
                          style: TextStyle(
                            color: chat.unreadCount > 0 ? AppColors.primary : AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (chat.isMuted) ...[
                        const Icon(Icons.volume_off, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          _lastMsgPreview(),
                          style: TextStyle(
                            color: chat.lastMessage != null ? AppColors.textSecondary : AppColors.textMuted,
                            fontSize: 13.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: chat.isMuted ? AppColors.textMuted : AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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

// Поиск
class _UserSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.bg2),
    inputDecorationTheme: const InputDecorationTheme(
      hintStyle: TextStyle(color: AppColors.textMuted),
      border: InputBorder.none,
    ),
  );

  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    return FutureBuilder(
      future: query.length >= 2 ? ApiService.searchUsers(query) : Future.value(<dynamic>[]),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
        }
        final users = snap.data as List? ?? [];
        if (users.isEmpty && query.length >= 2) {
          return const Center(child: Text('Никого не найдено', style: TextStyle(color: AppColors.textSecondary)));
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            return ListTile(
              leading: AppAvatar(
                name: u['display_name'] ?? u['username'],
                url: u['avatar_url'],
                size: 46,
                showOnline: true,
                isOnline: u['is_online'] ?? false,
              ),
              title: Text(u['display_name'] ?? u['username'],
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              subtitle: Text('@${u['username']}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              trailing: u['is_contact'] == true
                  ? const Icon(Icons.person, size: 16, color: AppColors.primary)
                  : null,
              onTap: () async {
                final res = await ApiService.openDirectChat(u['id']);
                if (!context.mounted) return;
                close(context, null);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(chat: Chat(
                    id: res['chatId'], type: 'direct',
                    displayName: u['display_name'] ?? u['username'],
                    displayAvatar: u['avatar_url'],
                    partnerOnline: u['is_online'] ?? false,
                  )),
                ));
              },
            );
          },
        );
      },
    );
  }
}

// Новый чат
class _NewChatSheet extends StatefulWidget {
  final Function(String chatId, String name, String? avatar) onCreated;
  final ScrollController scrollCtrl;
  const _NewChatSheet({required this.onCreated, required this.scrollCtrl});
  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();
  List _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.length < 2) return setState(() => _results = []);
    setState(() => _searching = true);
    final res = await ApiService.searchUsers(q);
    if (mounted) setState(() { _results = res; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(color: AppColors.bg4, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Text('Новый чат', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Поиск'), Tab(text: 'Контакты')],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              // Поиск
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Поиск по имени или @username',
                        prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                      ),
                      onChanged: _search,
                    ),
                  ),
                  Expanded(
                    child: _searching
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                        : ListView.builder(
                            controller: widget.scrollCtrl,
                            itemCount: _results.length,
                            itemBuilder: (_, i) {
                              final u = _results[i];
                              return ListTile(
                                leading: AppAvatar(
                                  name: u['display_name'] ?? u['username'],
                                  url: u['avatar_url'], size: 46,
                                  showOnline: true, isOnline: u['is_online'] ?? false,
                                ),
                                title: Text(u['display_name'] ?? u['username'],
                                    style: const TextStyle(color: AppColors.textPrimary)),
                                subtitle: Text('@${u['username']}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                onTap: () async {
                                  final res = await ApiService.openDirectChat(u['id']);
                                  widget.onCreated(res['chatId'],
                                      u['display_name'] ?? u['username'], u['avatar_url']);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
              // Контакты
              _ContactsList(
                onTap: (u) async {
                  final res = await ApiService.openDirectChat(u['id']);
                  widget.onCreated(res['chatId'],
                      u['display_name'] ?? u['username'], u['avatar_url']);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactsList extends StatefulWidget {
  final Function(Map) onTap;
  const _ContactsList({required this.onTap});
  @override
  State<_ContactsList> createState() => _ContactsListState();
}

class _ContactsListState extends State<_ContactsList> {
  List _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ApiService.getContacts().then((c) {
      if (mounted) setState(() { _contacts = c; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
    if (_contacts.isEmpty) return const Center(
      child: Text('Нет контактов.\nДобавьте через поиск.', textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
    );
    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (_, i) {
        final c = _contacts[i];
        return ListTile(
          leading: AppAvatar(
            name: c['nickname'] ?? c['display_name'] ?? c['username'],
            url: c['avatar_url'], size: 46,
            showOnline: true, isOnline: c['is_online'] ?? false,
          ),
          title: Text(c['nickname'] ?? c['display_name'] ?? c['username'],
              style: const TextStyle(color: AppColors.textPrimary)),
          subtitle: Text('@${c['username']}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          onTap: () => widget.onTap(c),
        );
      },
    );
  }
}
