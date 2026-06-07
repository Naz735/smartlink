import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, String>> scanHistory = [];

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString("scan_history");

    if (historyString != null) {
      final List decodedHistory = jsonDecode(historyString);

      setState(() {
        scanHistory = decodedHistory
            .map((item) => Map<String, String>.from(item))
            .toList();
      });
    }
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove("scan_history");

    setState(() {
      scanHistory.clear();
    });
  }

  List<String> getReasons(Map<String, String> item) {
    try {
      final reasonString = item["reasons"];

      if (reasonString == null || reasonString.isEmpty) {
        return [];
      }

      final List decodedReasons = jsonDecode(reasonString);

      return decodedReasons.map((reason) => reason.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  void showReasonDialog(Map<String, String> item) {
    final reasons = getReasons(item);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Why is this phishing?"),
          content: reasons.isEmpty
              ? const Text(
                  "The machine learning model detected suspicious patterns in this URL.",
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: reasons
                      .map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text("• $reason"),
                        ),
                      )
                      .toList(),
                ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan History"),
        centerTitle: true,
        actions: [
          if (scanHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: clearHistory,
            ),
        ],
      ),
      body: scanHistory.isEmpty
          ? const Center(
              child: Text(
                "No scan history yet.",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scanHistory.length,
              itemBuilder: (context, index) {
                final item = scanHistory[index];

                final bool safe =
                    item["result"]?.contains("SAFE") ?? false;

                final bool phishing =
                    item["result"]?.contains("PHISHING") ?? false;

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      safe
                          ? Icons.verified_user
                          : Icons.warning_amber_rounded,
                      color: safe ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      item["url"] ?? "",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "${item["result"]} - ${item["confidence"]}\n${item["time"]}",
                      ),
                    ),
                    trailing: phishing
                        ? const Icon(Icons.info_outline)
                        : null,
                    onTap: phishing
                        ? () {
                            showReasonDialog(item);
                          }
                        : null,
                  ),
                );
              },
            ),
    );
  }
}