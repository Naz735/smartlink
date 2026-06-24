import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/home_page.dart';

void main() {
  runApp(const SmartLinkApp());
}

class SmartLinkApp extends StatefulWidget {
  const SmartLinkApp({super.key});

  @override
  State<SmartLinkApp> createState() => _SmartLinkAppState();
}

class _SmartLinkAppState extends State<SmartLinkApp> {
  bool darkMode = false;
  Color seedColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      darkMode = prefs.getBool("dark_mode") ?? false;
      seedColor = Color(prefs.getInt("theme_color") ?? Colors.blue.value);
    });
  }

  Future<void> updateDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("dark_mode", value);

    setState(() {
      darkMode = value;
    });
  }

  Future<void> updateThemeColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt("theme_color", color.value);

    setState(() {
      seedColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "SmartLink",
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomePage(
        darkMode: darkMode,
        seedColor: seedColor,
        onDarkModeChanged: updateDarkMode,
        onThemeColorChanged: updateThemeColor,
      ),
    );
  }
}