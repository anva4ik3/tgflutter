import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api.dart';
import '../../theme.dart';
import 'register_screen.dart';
import '../home_screen.dart';
import '../../services/ws.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focuses = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  int _resendSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _resendSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitInput(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focuses[index + 1].requestFocus();
    }
    if (_code.length == 6) _verify();
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focuses[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _verify() async {
    if (_loading || _code.length < 6) return;
    setState(() => _loading = true);
    try {
      final result = await ApiService.verifyOtp(widget.email, _code);
      if (!mounted) return;
      if (result['isNewUser'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterScreen(email: widget.email),
          ),
        );
      } else {
        await ApiService.login(widget.email, _code);
        if (!mounted) return;
        wsService.connect();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
      );
      for (final c in _controllers) c.clear();
      _focuses[0].requestFocus();
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    try {
      await ApiService.sendOtp(widget.email);
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focuses) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Введите код',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Отправили на ${widget.email}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => _OtpBox(
                controller: _controllers[i],
                focusNode: _focuses[i],
                onChanged: (v) => _onDigitInput(i, v),
                onBackspace: () => _onBackspace(i),
              )),
            ),
            const SizedBox(height: 32),
            if (_loading)
              const Center(child: CircularProgressIndicator(color: AppColors.primary))
            else
              ElevatedButton(
                onPressed: _code.length == 6 ? _verify : null,
                child: const Text('Подтвердить'),
              ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: _resendSeconds == 0 ? _resend : null,
                child: Text(
                  _resendSeconds > 0
                      ? 'Повторить через ${_resendSeconds}с'
                      : 'Отправить повторно',
                  style: TextStyle(
                    color: _resendSeconds > 0 ? AppColors.textMuted : AppColors.primary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      // Fix: KeyboardListener вместо устаревшего RawKeyboardListener
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (e) {
          if (e is KeyDownEvent &&
              e.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            fillColor: AppColors.bg3,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
