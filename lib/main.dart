import 'package:flutter/cupertino.dart';
import 'screens/main_menu.dart';

void main() {
  runApp(const CabinetsApp());
}

class CabinetsApp extends StatelessWidget {
  const CabinetsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
      ),
      home: MainMenu(),
    );
  }
}