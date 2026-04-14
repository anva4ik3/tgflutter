import 'package:flutter/material.dart';
import '../../../services/api.dart';
import '../../../models/user.dart';
import '../../../theme.dart';
import '../auth/email_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getMe();
      if (mounted) setState(() { _user = User.fromJson(data); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.deleteToken();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => const EmailScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Профиль', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
            ),
            onPressed: _user == null ? null : _showEdit,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _user == null
              ? const Center(child: Text('Ошибка загрузки', style: TextStyle(color: AppColors.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.primaryGlow,
                            backgroundImage: _user!.avatarUrl != null ? NetworkImage(_user!.avatarUrl!) : null,
                            child: _user!.avatarUrl == null
                                ? Text(_user!.displayName[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 40, color: AppColors.primary, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(child: Text(_user!.displayName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                    Center(child: Text('@${_user!.username}',
                        style: const TextStyle(color: AppColors.primary, fontSize: 15))),
                    if (_user!.bio != null && _user!.bio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Center(child: Text(_user!.bio!,
                          style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center)),
                    ],
                    const SizedBox(height: 28),
                    if (_user!.email != null)
                      _InfoTile(icon: Icons.email_outlined, label: 'Email', value: _user!.email!),
                    _InfoTile(
                      icon: Icons.verified_outlined,
                      label: 'Статус',
                      value: _user!.isVerified ? 'Подтверждён' : 'Не подтверждён',
                      valueColor: _user!.isVerified ? AppColors.green : AppColors.textMuted,
                    ),
                    const SizedBox(height: 24),
                    _ActionTile(icon: Icons.notifications_outlined, label: 'Уведомления', onTap: () {}),
                    _ActionTile(icon: Icons.lock_outline, label: 'Конфиденциальность', onTap: () {}),
                    _ActionTile(icon: Icons.help_outline, label: 'Помощь', onTap: () {}),
                    const SizedBox(height: 12),
                    _ActionTile(icon: Icons.logout, label: 'Выйти', onTap: _logout, color: AppColors.red),
                  ],
                ),
    );
  }

  void _showEdit() {
    final nameCtrl = TextEditingController(text: _user!.displayName);
    final bioCtrl = TextEditingController(text: _user!.bio ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Редактировать профиль',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Отображаемое имя'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'О себе...'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await ApiService.updateProfile(
                  displayName: nameCtrl.text,
                  bio: bioCtrl.text,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                _load();
              },
              child: const Text('Сохранить'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoTile({required this.icon, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
        Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: color ?? AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: color ?? AppColors.textPrimary))),
          Icon(Icons.chevron_right, color: color ?? AppColors.textMuted, size: 20),
        ],
      ),
    ),
  );
}
