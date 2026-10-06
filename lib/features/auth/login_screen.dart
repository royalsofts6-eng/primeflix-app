import 'package:flutter/material.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass.dart';
import '../shell/main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter your member key');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await Prefs.setMemberKey(key);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [Color(0xFF1A1608), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.gold, width: 1.5),
                      ),
                      child: const Text('P',
                          style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 40,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 18),
                    const Text('PrimeFlix',
                        style: TextStyle(
                            fontSize: 34, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Enter your member key to continue',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 26),
                    TextField(
                      controller: _controller,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      decoration: const InputDecoration(
                        hintText: 'Member key',
                        prefixIcon: Icon(Icons.key_rounded,
                            color: AppColors.textSecondary),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                    ],
                    const SizedBox(height: 20),
                    GoldButton(
                        label: 'Continue', loading: _loading, onPressed: _login),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
