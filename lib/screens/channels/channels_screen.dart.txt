import 'package:flutter/material.dart';
import '../../../services/api.dart';
import '../../../models/chat.dart' show Channel;
import '../../../theme.dart';
import 'channel_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});
  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Channel> _explore = [];
  List<Channel> _my = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final exp = await ApiService.exploreChannels();
      final my = await ApiService.myChannels();
      setState(() {
        _explore = (exp as List).map((j) => Channel.fromJson(j)).toList();
        _my = (my as List).map((j) => Channel.fromJson(j)).toList();
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
        title: const Text('Каналы'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showCreate),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [Tab(text: 'Обзор'), Tab(text: 'Мои')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tab,
              children: [
                _ChannelList(channels: _explore, onTap: _openChannel),
                _ChannelList(channels: _my, onTap: _openChannel),
              ],
            ),
    );
  }

  void _openChannel(Channel ch) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChannelScreen(channel: ch)),
    ).then((_) => _load());
  }

  void _showCreate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CreateChannelSheet(onCreated: (ch) {
        Navigator.pop(context);
        _load();
        _openChannel(ch);
      }),
    );
  }
}

class _ChannelList extends StatelessWidget {
  final List<Channel> channels;
  final Function(Channel) onTap;
  const _ChannelList({required this.channels, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return const Center(
        child: Text('Нет каналов', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (_, i) {
        final ch = channels[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.2),
            child: ch.avatarUrl != null
                ? null
                : Text(ch.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            backgroundImage: ch.avatarUrl != null ? NetworkImage(ch.avatarUrl!) : null,
          ),
          title: Text(ch.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${ch.subscriberCount} подписчиков${ch.monthlyPrice > 0 ? ' · ${ch.monthlyPrice.toStringAsFixed(0)}₽/мес' : ''}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: ch.isSubscribed
              ? const Icon(Icons.check_circle, color: AppColors.green, size: 20)
              : null,
          onTap: () => onTap(ch),
        );
      },
    );
  }
}

class _CreateChannelSheet extends StatefulWidget {
  final Function(Channel) onCreated;
  const _CreateChannelSheet({required this.onCreated});
  @override
  State<_CreateChannelSheet> createState() => _CreateChannelSheetState();
}

class _CreateChannelSheetState extends State<_CreateChannelSheet> {
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _create() async {
    if (_usernameCtrl.text.isEmpty || _nameCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final data = await ApiService.createChannel(
        _usernameCtrl.text.trim(),
        _nameCtrl.text.trim(),
        _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      widget.onCreated(Channel.fromJson(data));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Создать канал', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          TextField(
            controller: _usernameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'username', prefixText: '@', prefixStyle: TextStyle(color: AppColors.primary)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Название канала'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Описание (необязательно)'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _create,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Создать'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
