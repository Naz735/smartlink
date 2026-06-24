import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  final bool darkMode;
  final Color selectedColor;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<Color> onThemeColorChanged;

  const SettingsPage({
    super.key,
    required this.darkMode,
    required this.selectedColor,
    required this.onDarkModeChanged,
    required this.onThemeColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> themeColors = [
      {
        "name": "Blue",
        "color": Colors.blue,
      },
      {
        "name": "Green",
        "color": Colors.green,
      },
      {
        "name": "Purple",
        "color": Colors.purple,
      },
      {
        "name": "Red",
        "color": Colors.red,
      },
      {
        "name": "Orange",
        "color": Colors.orange,
      },
      {
        "name": "Teal",
        "color": Colors.teal,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: SwitchListTile(
              secondary: Icon(
                darkMode ? Icons.dark_mode : Icons.light_mode,
              ),
              title: const Text(
                "Dark Mode",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Switch between light and dark theme"),
              value: darkMode,
              onChanged: onDarkModeChanged,
            ),
          ),

          const SizedBox(height: 20),

          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.palette),
                      SizedBox(width: 8),
                      Text(
                        "Theme Color",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Choose your preferred app color theme.",
                  ),

                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: themeColors.map((item) {
                      final Color color = item["color"];
                      final String name = item["name"];

                      final bool isSelected = selectedColor.value == color.value;

                      return ChoiceChip(
                        label: Text(name),
                        selected: isSelected,
                        avatar: CircleAvatar(
                          backgroundColor: color,
                        ),
                        onSelected: (_) {
                          onThemeColorChanged(color);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 25),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Settings are saved automatically and will remain after closing the app.",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}