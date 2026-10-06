import 'package:flutter/material.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../shell/main_shell.dart';

/// Short animated splash (gold "P" + wordmark), then routes to Login / Home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), _go);
  }

  void _go() {
    if (!mounted) return;
    final next = Prefs.isLoggedIn ? const MainShell() : const LoginScreen();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => next,
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween(begin: 0.6, end: 1.0).animate(scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    color: Colors.black,
                    border: Border.all(
                        color: AppColors.gold.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.gold.withOpacity(0.25),
                          blurRadius: 30)
                    ],
                  ),
                  child: const Text('P',
                      style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold)),
                ),
                const SizedBox(height: 18),
                const Text('PrimeFlix',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
