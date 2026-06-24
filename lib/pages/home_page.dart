import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/tflite_service.dart';
import '../utils/feature_extractor.dart';
import '../services/whoisxml_service.dart';
import 'history_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final bool darkMode;
  final Color seedColor;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<Color> onThemeColorChanged;

  const HomePage({
    super.key,
    required this.darkMode,
    required this.seedColor,
    required this.onDarkModeChanged,
    required this.onThemeColorChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController controller = TextEditingController();

  final TFLiteService tflite = TFLiteService();
  final WhoisXmlService whoisService = WhoisXmlService();

  String result = "";
  String riskLevel = "";
  String confidence = "";
  String currentUrl = "";

  WhoisXmlInfo? latestWhoisInfo;

  bool loading = false;
  bool modelLoaded = false;
  bool whoisLoading = false;

  List<String> phishingReasons = [];

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      await tflite.loadModel();

      setState(() {
        modelLoaded = true;
      });
    } catch (e) {
      setState(() {
        result = "Model load error: $e";
      });
    }
  }

  Future<void> addToHistory({
    required String url,
    required String resultStatus,
    required String confidence,
    required String riskLevel,
    List<String> reasons = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString("scan_history");

    List<Map<String, String>> scanHistory = [];

    if (historyString != null) {
      final List decodedHistory = jsonDecode(historyString);
      scanHistory =
          decodedHistory.map((item) => Map<String, String>.from(item)).toList();
    }

    final now = DateTime.now();

    scanHistory.insert(0, {
      "url": url,
      "result": resultStatus,
      "confidence": confidence,
      "riskLevel": riskLevel,
      "time":
          "${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}",
      "reasons": jsonEncode(reasons),
    });

    if (scanHistory.length > 30) {
      scanHistory = scanHistory.take(30).toList();
    }

    await prefs.setString("scan_history", jsonEncode(scanHistory));
  }

  void analyze() async {
    if (controller.text.isEmpty) return;

    if (!modelLoaded) {
      setState(() {
        result = "App still loading...";
      });
      return;
    }

    setState(() {
      loading = true;
      whoisLoading = true;
      result = "";
      riskLevel = "";
      confidence = "";
      currentUrl = "";
      latestWhoisInfo = null;
      phishingReasons = [];
    });

    try {
      String url = controller.text.trim();
      currentUrl = url;

      List<double> features = await extractFeatures(url);

      var output = tflite.predict(features);
      double score = output[0];

      print("Model score: $score");

      String historyResult;
      String confidenceText;
      String riskText;

      if (score > 0.5) {
        confidenceText = "${(score * 100).toStringAsFixed(2)}%";
        historyResult = "SAFE ✅";
        riskText = "Low";
      } else {
        confidenceText = "${((1 - score) * 100).toStringAsFixed(2)}%";
        historyResult = "PHISHING ⚠️";
        riskText = "High";
        phishingReasons = buildUrlReasons(url);
      }

      setState(() {
        result = historyResult;
        riskLevel = riskText;
        confidence = confidenceText;
        loading = false;
      });

      WhoisXmlInfo info = await whoisService.lookup(url);

      if (historyResult.contains("PHISHING")) {
        List<String> whoisReasons = buildWhoisReasons(info);
        phishingReasons.addAll(whoisReasons);
      }

      await addToHistory(
        url: url,
        resultStatus: historyResult,
        confidence: confidenceText,
        riskLevel: riskText,
        reasons: phishingReasons,
      );

      setState(() {
        whoisLoading = false;
        latestWhoisInfo = info;
      });
    } catch (e) {
      setState(() {
        loading = false;
        whoisLoading = false;
        result = "Analysis failed: $e";
      });
    }
  }

  List<String> buildUrlReasons(String url) {
    List<String> reasons = [];
    String lowerUrl = url.toLowerCase();

    if (!lowerUrl.startsWith("https")) {
      reasons.add("The URL does not use HTTPS.");
    }

    if (lowerUrl.contains("@")) {
      reasons.add(
        "The URL contains '@', which can hide the real website destination.",
      );
    }

    if (lowerUrl.length > 75) {
      reasons.add(
        "The URL is very long, which may hide suspicious information.",
      );
    }

    if (lowerUrl.contains("bit.ly") ||
        lowerUrl.contains("tinyurl") ||
        lowerUrl.contains("goo.gl") ||
        lowerUrl.contains("t.co")) {
      reasons.add(
        "The URL uses a shortening service, which can hide the real domain.",
      );
    }

    if (lowerUrl.contains("-")) {
      reasons.add(
        "The domain contains '-', which is often used in fake website names.",
      );
    }

    int dotCount = ".".allMatches(lowerUrl).length;
    if (dotCount > 3) {
      reasons.add(
        "The URL has many dots or subdomains, which can be suspicious.",
      );
    }

    if (RegExp(r'\d+\.\d+\.\d+\.\d+').hasMatch(lowerUrl)) {
      reasons.add(
        "The URL uses an IP address instead of a normal domain name.",
      );
    }

    if (reasons.isEmpty) {
      reasons.add(
        "The machine learning model detected suspicious URL patterns.",
      );
    }

    return reasons;
  }

  List<String> buildWhoisReasons(WhoisXmlInfo info) {
    List<String> reasons = [];

    if (info.domainAge == "Not available") {
      reasons.add("The domain age is not available from WHOIS API.");
    } else if (info.domainAge.contains("day")) {
      reasons.add("The domain appears to be newly registered.");
    }

    if (info.registrarName == "Not available") {
      reasons.add(
        "The registrar information is not available from WHOIS API.",
      );
    }

    if (info.createdDate == "Not available") {
      reasons.add(
        "The domain creation date is not available from WHOIS API.",
      );
    }

    return reasons;
  }

  void showWhyPhishingDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Why is this phishing?"),
          content: phishingReasons.isEmpty
              ? const Text(
                  "The machine learning model detected suspicious patterns in this URL.",
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: phishingReasons
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

  String buildShareText() {
    return "SmartLink Scan Result\n\n"
        "URL: $currentUrl\n"
        "Result: $result\n"
        "Risk Level: $riskLevel\n"
        "Model Confidence: $confidence\n\n"
        "Confidence is the model prediction score, not a guarantee of website safety.\n\n"
        "Scanned using SmartLink phishing URL detection app.";
  }

  void copyResult() {
    if (result.isEmpty || currentUrl.isEmpty) return;

    Clipboard.setData(
      ClipboardData(text: buildShareText()),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Result copied"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void shareResult() {
    if (result.isEmpty || currentUrl.isEmpty) return;

    Share.share(buildShareText());
  }

  Future<void> openUrlInBrowser() async {
    if (currentUrl.isEmpty) return;

    bool isPhishing = result.contains("PHISHING");

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
              "This URL has been classified as phishing. Opening this link may be risky.\n\nDo you still want to open it?",
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

    String fixedUrl = currentUrl.trim();

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

  void clearAll() {
    controller.clear();

    setState(() {
      result = "";
      riskLevel = "";
      confidence = "";
      currentUrl = "";
      latestWhoisInfo = null;
      loading = false;
      whoisLoading = false;
      phishingReasons = [];
    });
  }

  @override
  void dispose() {
    controller.dispose();
    tflite.close();
    super.dispose();
  }

  Widget buildHeaderCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.security,
            size: 38,
            color: Colors.white,
          ),
          SizedBox(height: 5),
          Text(
            "SmartLink",
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2),
          Text(
            "Phishing URL Detection System",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildResultCard() {
  bool isSafe = result.contains("SAFE");
  bool isPhishing = result.contains("PHISHING");

  Color mainColor = isSafe
      ? Colors.green
      : isPhishing
          ? Colors.red
          : Theme.of(context).colorScheme.primary;

  Color cardColor = isSafe
      ? Colors.green.withOpacity(0.10)
      : isPhishing
          ? Colors.red.withOpacity(0.10)
          : Theme.of(context).colorScheme.surface;

  IconData resultIcon = isSafe
      ? Icons.verified_user
      : isPhishing
          ? Icons.warning_amber_rounded
          : Icons.info;

  return Card(
    elevation: 5,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: mainColor, width: 1.3),
    ),
    color: cardColor,
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: mainColor.withOpacity(0.14),
                child: Icon(
                  resultIcon,
                  size: 27,
                  color: mainColor,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Detection Result",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      result,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: mainColor,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: mainColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Risk Level: $riskLevel",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: mainColor,
                        ),
                      ),
                    ),

                    if (isPhishing)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SizedBox(
                          height: 34,
                          child: ElevatedButton.icon(
                            onPressed: showWhyPhishingDialog,
                            icon: const Icon(
                              Icons.info_outline,
                              size: 17,
                            ),
                            label: const Text(
                              "Why phishing?",
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.30),
              ),
            ),
            child: Column(
              children: [
                Text(
                  confidence,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  "Model Confidence",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

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
          ),
        ],
      ),
    ),
  );
}
  Widget buildSafetyAdviceCard() {
    if (result.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isSafe = result.contains("SAFE");
    final bool isPhishing = result.contains("PHISHING");

    Color adviceColor = isSafe
        ? Colors.green
        : isPhishing
            ? Colors.red
            : Theme.of(context).colorScheme.primary;

    IconData adviceIcon = isSafe
        ? Icons.check_circle_outline
        : isPhishing
            ? Icons.health_and_safety_outlined
            : Icons.info_outline;

    List<String> adviceList = isSafe
        ? [
            "The URL appears safe based on the current analysis.",
            "Still check the website carefully before entering sensitive information.",
            "Avoid sharing passwords or banking details if the website looks suspicious.",
          ]
        : [
            "Do not enter your password, banking details, or personal information.",
            "Do not download files from this link.",
            "Close the website if it looks suspicious or asks for sensitive information.",
          ];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: adviceColor.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  adviceIcon,
                  color: adviceColor,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Text(
                  "Safety Advice",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: adviceColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ...adviceList.map(
              (advice) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "• ",
                      style: TextStyle(
                        fontSize: 14,
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
      ),
    );
  }

  Widget buildScrollHint() {
    if (result.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            "Scroll down to view WHOIS details and actions",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildActionButtons() {
    if (result.isEmpty || currentUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.touch_app, size: 20),
                SizedBox(width: 8),
                Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: copyResult,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text("Copy"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: shareResult,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("Share"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: openUrlInBrowser,
                icon: const Icon(Icons.open_in_browser, size: 18),
                label: const Text("Open URL in Browser"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildWhoisRow(String label, String value) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Text(
            ": ",
            style: TextStyle(color: textColor),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWhoisCard() {
    final info = latestWhoisInfo;

    if (info == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(
            Icons.language,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text(
            "WHOIS API Information",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "Domain Age: ${info.domainAge}",
            style: const TextStyle(fontSize: 13),
          ),
          children: [
            const Divider(height: 18),
            buildWhoisRow("Domain", info.domainName),
            buildWhoisRow("Registrar", info.registrarName),
            buildWhoisRow("Created", info.createdDate),
            buildWhoisRow("Updated", info.updatedDate),
            buildWhoisRow("Expires", info.expiresDate),
            buildWhoisRow("Domain Age", info.domainAge),
          ],
        ),
      ),
    );
  }

  void openSettingsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          darkMode: widget.darkMode,
          selectedColor: widget.seedColor,
          onDarkModeChanged: widget.onDarkModeChanged,
          onThemeColorChanged: widget.onThemeColorChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBackground = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Scan History",
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: "Settings",
            icon: const Icon(Icons.settings),
            onPressed: openSettingsPage,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: Column(
          children: [
            buildHeaderCard(),
            const SizedBox(height: 10),
            Text(
              modelLoaded
                  ? "App ready. Enter URL to analyze."
                  : "Loading app...",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: modelLoaded ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: "Enter URL",
                        hintText: "https://example.com",
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: clearAll,
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : analyze,
                        icon: const Icon(Icons.search, size: 19),
                        label: Text(
                          loading ? "Analyzing..." : "Analyze URL",
                          style: const TextStyle(fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Analyzing URL and extracting security features..."),
                ],
              )
            else if (result.isNotEmpty)
              buildResultCard(),
            if (result.isNotEmpty) ...[
              const SizedBox(height: 9),
              buildSafetyAdviceCard(),
              const SizedBox(height: 5),
              buildScrollHint(),
            ],
            const SizedBox(height: 8),
            if (whoisLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text("Loading WHOIS information..."),
                ],
              )
            else if (latestWhoisInfo != null)
              buildWhoisCard(),
            if (result.isNotEmpty) ...[
              const SizedBox(height: 10),
              buildActionButtons(),
            ],
            const SizedBox(height: 20),
            const Text(
              "SmartLink uses TensorFlow Lite and WhoisXML API to analyze URL safety and domain registration information.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}