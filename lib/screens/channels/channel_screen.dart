import 'package:flutter/material.dart';
import '../../../services/api.dart';
import '../../../models/chat.dart' show Channel;
import '../../../theme.dart';

class ChannelScreen extends StatefulWidget {
  final Channel channel;
  const ChannelScreen({super.key, required this.channel});
  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  late Channel _channel;
  List _posts = [];
  bool _loading = true;
  bool _subLoading = false;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    _load();
  }

  Future<void> _load() async {
    try {
      final ch = await ApiService.getChannel(_channel.username);
      final posts = await ApiService.getChannelPosts(_channel.id);
      setState(() {
        _channel = Channel.fromJson(ch);
        _posts = posts as List;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleSubscribe() async {
    setState(() => _subLoading = true);
    try {
      await ApiService.subscribeChannel(_channel.id);
      await _load();
    } catch (_) {} finally {
      setState(() => _subLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.bg2,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_channel.name),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.8), AppColors.bg2],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withOpacity(0.3),
                    backgroundImage: _channel.avatarUrl != null ? NetworkImage(_channel.avatarUrl!) : null,
                    child: _channel.avatarUrl == null
                        ? Text(_channel.name[0].toUpperCase(), style: const TextStyle(fontSize: 32, color: AppColors.primary, fontWeight: FontWeight.bold))
                        : null,
                  ),
                ),
              ),
            ),
            actions: [
              if (_channel.isOwner)
                IconButton(icon: const Icon(Icons.add), onPressed: _showCreatePost),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatBadge(label: 'Подписчики', value: '${_channel.subscriberCount}'),
                      if (_channel.monthlyPrice > 0) ...[
                        const SizedBox(width: 12),
                        _StatBadge(label: 'Подписка', value: '${_channel.monthlyPrice.toStringAsFixed(0)}₽/мес'),
                      ],
                    ],
                  ),
                  if (_channel.description != null) ...[
                    const SizedBox(height: 12),
                    Text(_channel.description!, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 16),
                  if (!_channel.isOwner)
                    ElevatedButton.icon(
                      onPressed: _subLoading ? null : _toggleSubscribe,
                      icon: Icon(_channel.isSubscribed ? Icons.check : Icons.add),
                      label: Text(_channel.isSubscribed ? 'Вы подписаны' : 'Подписаться'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _channel.isSubscribed ? AppColors.bg4 : AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_posts.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('Нет постов', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _PostCard(post: _posts[i]),
                childCount: _posts.length,
              ),
            ),
        ],
      ),
    );
  }

  void _showCreatePost() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CreatePostSheet(channelId: _channel.id, onCreated: () {
        Navigator.pop(context);
        _load();
      }),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostCard({required this.post});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: post['is_paid'] == true
            ? Border.all(color: AppColors.yellow.withOpacity(0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post['is_paid'] == true)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.yellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Платный', style: TextStyle(color: AppColors.yellow, fontSize: 11)),
            ),
          Text(post['content'] ?? '', style: const TextStyle(color: AppColors.textPrimary, height: 1.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('${post['views'] ?? 0}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  final String channelId;
  final VoidCallback onCreated;
  const _CreatePostSheet({required this.channelId, required this.onCreated});
  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _ctrl = TextEditingController();
  bool _isPaid = false;
  bool _loading = false;

  Future<void> _create() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ApiService.createChannelPost(widget.channelId, {
        'content': _ctrl.text.trim(),
        'isPaid': _isPaid,
      });
      widget.onCreated();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
      );
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
        children: [
          const Text('Новый пост', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 5,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Текст поста...'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(value: _isPaid, onChanged: (v) => setState(() => _isPaid = v), activeColor: AppColors.yellow),
              const Text('Платный пост', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _create,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Опубликовать'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
