import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'home_page.dart';
import 'albums_page.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  int _currentIndex = 0;
  late Box _settingsBox;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    // Restore last selected tab
    _currentIndex = _settingsBox.get('lastTabIndex', defaultValue: 0);
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Save selected tab
    _settingsBox.put('lastTabIndex', index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If on home tab (0), minimize app to background
        if (_currentIndex == 0) {
          // Move task to background instead of closing
          // This requires platform channel or just let it exit normally
          Navigator.of(context).pop();
        } else {
          // Otherwise, go back to home tab first
          setState(() {
            _currentIndex = 0;
          });
          _settingsBox.put('lastTabIndex', 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: const [HomePage(), AlbumsPage()]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2)),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: Colors.deepPurple,
            unselectedItemColor: Colors.grey.shade600,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), activeIcon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.album_outlined),
                activeIcon: Icon(Icons.album_rounded),
                label: 'Albums',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
