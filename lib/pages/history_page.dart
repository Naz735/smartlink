import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, String>> scanHistory = [];

  String searchQuery = "";
  String selectedFilter = "All";

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("scan_history", jsonEncode(scanHistory));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove("scan_history");

    setState(() {
      scanHistory.clear();
      searchQuery = "";
      selectedFilter = "All";
      searchController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All scan history deleted"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> deleteHistoryItem(int originalIndex) async {
    setState(() {
      scanHistory.removeAt(originalIndex);
    });

    await saveHistory();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("History item deleted"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> confirmClearHistory() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
              ),
              SizedBox(width: 8),
              Text("Delete All History?"),
            ],
          ),
          content: const Text(
            "This will permanently delete all scan history from this device.\n\nAre you sure you want to continue?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.delete_sweep),
              label: const Text("Delete All"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await clearHistory();
    }
  }

  Future<void> confirmDeleteItem(int originalIndex) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete History"),
          content: const Text(
            "Are you sure you want to delete this history item?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await deleteHistoryItem(originalIndex);
    }
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

  String getRiskLevel(Map<String, String> item) {
    final risk = item["riskLevel"];

    if (risk != null && risk.isNotEmpty) {
      return risk;
    }

    final result = item["result"] ?? "";

    if (result.contains("SAFE")) {
      return "Low";
    }

    if (result.contains("PHISHING")) {
      return "High";
    }

    return "Unknown";
  }

  String getConfidence(Map<String, String> item) {
    final confidence = item["confidence"];

    if (confidence != null && confidence.isNotEmpty) {
      return confidence;
    }

    return "Not available";
  }

  bool isSafeItem(Map<String, String> item) {
    return item["result"]?.contains("SAFE") ?? false;
  }

  bool isPhishingItem(Map<String, String> item) {
    return item["result"]?.contains("PHISHING") ?? false;
  }

  List<MapEntry<int, Map<String, String>>> getFilteredHistory() {
    final query = searchQuery.toLowerCase().trim();

    List<MapEntry<int, Map<String, String>>> entries = [];

    for (int i = 0; i < scanHistory.length; i++) {
      final item = scanHistory[i];

      final url = (item["url"] ?? "").toLowerCase();
      final result = item["result"] ?? "";

      bool matchesSearch = query.isEmpty || url.contains(query);

      bool matchesFilter = selectedFilter == "All" ||
          (selectedFilter == "Safe" && result.contains("SAFE")) ||
          (selectedFilter == "Phishing" && result.contains("PHISHING"));

      if (matchesSearch && matchesFilter) {
        entries.add(MapEntry(i, item));
      }
    }

    return entries;
  }

  String buildShareText(Map<String, String> item) {
    final url = item["url"] ?? "";
    final result = item["result"] ?? "";
    final risk = getRiskLevel(item);
    final confidence = getConfidence(item);
    final time = item["time"] ?? "";

    return "SmartLink Scan Result\n\n"
        "URL: $url\n"
        "Result: $result\n"
        "Risk Level: $risk\n"
        "Model Confidence: $confidence\n"
        "Time: $time\n\n"
        "Confidence is the model prediction score, not a guarantee of website safety.\n\n"
        "Scanned using SmartLink phishing URL detection app.";
  }

  void copyHistoryResult(Map<String, String> item) {
    Clipboard.setData(
      ClipboardData(text: buildShareText(item)),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("History result copied"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void shareHistoryResult(Map<String, String> item) {
    Share.share(buildShareText(item));
  }

  Future<void> openHistoryUrl(Map<String, String> item) async {
    String url = item["url"] ?? "";

    if (url.isEmpty) return;

    bool isPhishing = isPhishingItem(item);

    if (isPhishing) {
      final bool? confirmOpen = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                ),
                SizedBox(width: 8),
                Text("Warning"),
              ],
            ),
            content: const Text(
              "This URL was classified as phishing. Opening this link may be risky.\n\nDo you still want to open it?",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text("Open Anyway"),
              ),
            ],
          );
        },
      );

      if (confirmOpen != true) {
        return;
      }
    }

    String fixedUrl = url.trim();

    if (!fixedUrl.startsWith("http://") && !fixedUrl.startsWith("https://")) {
      fixedUrl = "https://$fixedUrl";
    }

    final Uri uri = Uri.parse(fixedUrl);

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to open URL"),
          ),
        );
      }
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
              : SingleChildScrollView(
                  child: Column(
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

  Widget buildSearchAndFilter() {
    if (scanHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: "Search URL history",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();

                        setState(() {
                          searchQuery = "";
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              buildFilterChip("All"),
              const SizedBox(width: 8),
              buildFilterChip("Safe"),
              const SizedBox(width: 8),
              buildFilterChip("Phishing"),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildFilterChip(String filter) {
    final bool selected = selectedFilter == filter;

    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(filter)),
        selected: selected,
        onSelected: (_) {
          setState(() {
            selectedFilter = filter;
          });
        },
      ),
    );
  }

  Widget buildRiskBadge({
    required bool safe,
    required bool phishing,
    required String riskLevel,
  }) {
    Color badgeColor = safe
        ? Colors.green
        : phishing
            ? Colors.red
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "Risk: $riskLevel",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget buildConfidenceBadge(String confidence) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "Confidence: $confidence",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget buildConfidenceExplanationBox(String confidence) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.30),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Text(
                "Model Confidence: $confidence",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            "Confidence is the model prediction score, not a guarantee of website safety.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSafetyAdviceBox({
    required bool safe,
    required bool phishing,
  }) {
    Color adviceColor = safe
        ? Colors.green
        : phishing
            ? Colors.red
            : Theme.of(context).colorScheme.primary;

    IconData adviceIcon = safe
        ? Icons.check_circle_outline
        : phishing
            ? Icons.health_and_safety_outlined
            : Icons.info_outline;

    List<String> adviceList = safe
        ? [
            "The URL was classified as safe based on the analysis.",
            "Still verify the website before entering sensitive information.",
          ]
        : [
            "Do not enter personal, password, or banking information.",
            "Avoid downloading files from this link.",
            "Close the website if it asks for sensitive information.",
          ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adviceColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: adviceColor.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                adviceIcon,
                size: 20,
                color: adviceColor,
              ),
              const SizedBox(width: 8),
              Text(
                "Safety Advice",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: adviceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...adviceList.map(
            (advice) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "• ",
                    style: TextStyle(
                      color: adviceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      advice,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                      ),
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

  Widget buildHistoryCard({
    required Map<String, String> item,
    required int originalIndex,
  }) {
    final bool safe = isSafeItem(item);
    final bool phishing = isPhishingItem(item);

    final String risk = getRiskLevel(item);
    final String confidence = getConfidence(item);

    Color mainColor = safe
        ? Colors.green
        : phishing
            ? Colors.red
            : Colors.grey;

    IconData mainIcon = safe
        ? Icons.verified_user
        : phishing
            ? Icons.warning_amber_rounded
            : Icons.info_outline;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: mainColor.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: CircleAvatar(
            backgroundColor: mainColor.withOpacity(0.12),
            child: Icon(
              mainIcon,
              color: mainColor,
            ),
          ),
          title: Text(
            item["url"] ?? "",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item["result"] ?? "",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: mainColor,
                      ),
                    ),
                    buildRiskBadge(
                      safe: safe,
                      phishing: phishing,
                      riskLevel: risk,
                    ),
                    buildConfidenceBadge(confidence),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item["time"] ?? "",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Tap to view actions.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 12),
            buildConfidenceExplanationBox(confidence),
            if (phishing)
              buildActionTile(
                icon: Icons.info_outline,
                title: "Why is this phishing?",
                color: Colors.red,
                onTap: () {
                  showReasonDialog(item);
                },
              ),
            buildSafetyAdviceBox(
              safe: safe,
              phishing: phishing,
            ),
            buildActionTile(
              icon: Icons.copy,
              title: "Copy Result",
              onTap: () {
                copyHistoryResult(item);
              },
            ),
            buildActionTile(
              icon: Icons.share,
              title: "Share Result",
              onTap: () {
                shareHistoryResult(item);
              },
            ),
            buildActionTile(
              icon: Icons.open_in_browser,
              title: "Open URL in Browser",
              onTap: () {
                openHistoryUrl(item);
              },
            ),
            buildActionTile(
              icon: Icons.delete_outline,
              title: "Delete This History",
              color: Colors.red,
              onTap: () {
                confirmDeleteItem(originalIndex);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: color,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: color == Colors.red ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              "No scan history yet.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your scanned URLs will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNoSearchResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 70,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              "No matching history found.",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try another keyword or filter.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHistoryList() {
    final filteredHistory = getFilteredHistory();

    if (filteredHistory.isEmpty) {
      return buildNoSearchResult();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: filteredHistory.length,
      itemBuilder: (context, index) {
        final entry = filteredHistory[index];

        return buildHistoryCard(
          item: entry.value,
          originalIndex: entry.key,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Scan History"),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (scanHistory.isNotEmpty)
            IconButton(
              tooltip: "Delete all history",
              icon: const Icon(Icons.delete_sweep),
              onPressed: confirmClearHistory,
            ),
        ],
      ),
      body: scanHistory.isEmpty
          ? buildEmptyState()
          : Column(
              children: [
                buildSearchAndFilter(),
                Expanded(
                  child: buildHistoryList(),
                ),
              ],
            ),
    );
  }
}