import 'package:flutter/material.dart';
import '../../services/api.dart';
import '../../services/ws.dart';
import '../../theme.dart';
import '../home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String email;
  const RegisterScreen({super.key, required this.email});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    final username = _usernameCtrl.text.trim().toLowerCase();
    final name = _nameCtrl.text.trim();
    if (username.length < 3) return setState(() => _error = 'Минимум 3 символа');
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      return setState(() => _error = 'Только a-z, 0-9, _');
    }
    setState(() { _loading = true; _error = null; });
    try {
      // Fix: передаём email + username + displayName (без code)
      await ApiService.register(widget.email, username, name.isNotEmpty ? name : username);
      wsService.connect();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Ошибка регистрации'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(title: const Text('Создать профиль')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Придумайте имя пользователя',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Аккаунт: ${widget.email}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 28),
              TextField(
                controller: _usernameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'username (a-z, 0-9, _)',
                  prefixText: '@',
                  prefixStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Отображаемое имя (необязательно)'),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _register(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.red, size: 16),
                      const SizedBox(width: 8),
                      Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Создать аккаунт'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
