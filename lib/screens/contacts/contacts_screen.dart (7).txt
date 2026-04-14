import 'package:flutter/material.dart';
import '../../services/api.dart';

import '../../theme.dart';
import '../../widgets/app_avatar.dart';
import '../chats/chat_screen.dart';
import '../../models/chat.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getContacts();
      if (mounted) setState(() { _contacts = data; _loading = false; });
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
        title: const Text('Контакты', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_add_outlined, size: 20, color: AppColors.textSecondary),
            ),
            onPressed: _showAddContact,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _contacts.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  backgroundColor: AppColors.bg3,
                  child: ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (_, i) {
                      final c = _contacts[i];
                      return _ContactTile(
                        contact: c,
                        onTap: () => _openChat(c),
                        onDelete: () => _removeContact(c['id']),
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
          decoration: BoxDecoration(color: AppColors.primaryGlow, borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.people_outline, size: 40, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        const Text('Нет контактов', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _showAddContact,
          icon: const Icon(Icons.person_add_outlined, size: 18),
          label: const Text('Добавить контакт'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 44),
          ),
        ),
      ],
    ),
  );

  void _showAddContact() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddContactSheet(onAdded: _load),
    );
  }

  Future<void> _openChat(Map c) async {
    try {
      final res = await ApiService.openDirectChat(c['id']);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(chat: Chat(
          id: res['chatId'],
          type: 'direct',
          displayName: c['nickname'] ?? c['display_name'] ?? c['username'],
          displayAvatar: c['avatar_url'],
          partnerOnline: c['is_online'] ?? false,
        )),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  Future<void> _removeContact(String contactId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg3,
        title: const Text('Удалить контакт?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Контакт будет удалён из вашего списка.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.removeContact(contactId);
      _load();
    }
  }
}

class _ContactTile extends StatelessWidget {
  final Map contact;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _ContactTile({required this.contact, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = contact['nickname'] ?? contact['display_name'] ?? contact['username'];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AppAvatar(
              name: name,
              url: contact['avatar_url'],
              size: 50,
              showOnline: true,
              isOnline: contact['is_online'] ?? false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text('@${contact['username']}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.message_outlined, color: AppColors.primary, size: 20),
              onPressed: onTap,
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
              color: AppColors.bg3,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Удалить', style: TextStyle(color: AppColors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (v) { if (v == 'delete') onDelete(); },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddContactSheet({required this.onAdded});
  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _searchCtrl = TextEditingController();
  List _results = [];
  bool _searching = false;
  bool _adding = false;

  Future<void> _search(String q) async {
    if (q.length < 2) return setState(() => _results = []);
    setState(() => _searching = true);
    final res = await ApiService.searchUsers(q);
    if (mounted) setState(() { _results = res; _searching = false; });
  }

  Future<void> _add(Map user) async {
    setState(() => _adding = true);
    try {
      await ApiService.addContact(user['username']);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['display_name'] ?? user['username']} добавлен'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.bg4, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text('Добавить контакт',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Поиск по @username или имени',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              ),
              onChanged: _search,
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final u = _results[i];
                  final alreadyContact = u['is_contact'] == true;
                  return ListTile(
                    leading: AppAvatar(
                      name: u['display_name'] ?? u['username'],
                      url: u['avatar_url'], size: 44,
                      showOnline: true, isOnline: u['is_online'] ?? false,
                    ),
                    title: Text(u['display_name'] ?? u['username'],
                        style: const TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text('@${u['username']}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    trailing: alreadyContact
                        ? const Icon(Icons.check_circle, color: AppColors.green, size: 20)
                        : _adding
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                            : TextButton(
                                onPressed: () => _add(u),
                                child: const Text('Добавить', style: TextStyle(color: AppColors.primary)),
                              ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
