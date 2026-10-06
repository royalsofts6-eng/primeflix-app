import 'package:flutter/material.dart';
import '../../widgets/bottom_nav.dart';
import '../home/home_screen.dart';
import '../mylist/mylist_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _listVersion = 0; // bump to rebuild My List with fresh data

  void _onTab(int i) {
    setState(() {
      if (i == 2) _listVersion++;
      _index = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0); // Back: any tab -> Home first
      },
      child: Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          const SearchScreen(),
          MyListScreen(key: ValueKey(_listVersion)),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: GlassBottomNav(index: _index, onChanged: _onTab),
      ),
    );
  }
}
