import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/tflite_service.dart';
import 'utils/feature_extractor.dart';
import 'services/whoisxml_service.dart';
import 'pages/history_page.dart';

void main() {
  runApp(const SmartLinkApp());
}

class SmartLinkApp extends StatelessWidget {
  const SmartLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController controller = TextEditingController();

  final TFLiteService tflite = TFLiteService();
  final WhoisXmlService whoisService = WhoisXmlService();

  String result = "";
  String whoisResult = "";

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
    List<String> reasons = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString("scan_history");

    List<Map<String, String>> scanHistory = [];

    if (historyString != null) {
      final List decodedHistory = jsonDecode(historyString);
      scanHistory = decodedHistory
          .map((item) => Map<String, String>.from(item))
          .toList();
    }

    final now = DateTime.now();

    scanHistory.insert(0, {
      "url": url,
      "result": resultStatus,
      "confidence": confidence,
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
      whoisResult = "";
      phishingReasons = [];
    });

    try {
      String url = controller.text.trim();

      // =========================
      // OFFLINE TFLITE ANALYSIS
      // =========================
      List<double> features = extractFeatures(url);

      var output = tflite.predict(features);
      double score = output[0];

      print("Score: $score");

      String predictionText;
      String historyResult;
      String confidenceText;

      if (score > 0.5) {
        confidenceText = "${(score * 100).toStringAsFixed(2)}%";
        historyResult = "SAFE ✅";
        predictionText = "SAFE ✅\nConfidence: $confidenceText";
      } else {
        confidenceText = "${((1 - score) * 100).toStringAsFixed(2)}%";
        historyResult = "PHISHING ⚠️";
        predictionText = "PHISHING ⚠️\nConfidence: $confidenceText";

        // Build URL-based reasons immediately
        phishingReasons = buildUrlReasons(url);
      }

      setState(() {
        result = predictionText;
        loading = false;
      });

      // =========================
      // ONLINE WHOISXML API LOOKUP
      // =========================
      WhoisXmlInfo info = await whoisService.lookup(url);

      if (historyResult.contains("PHISHING")) {
        List<String> whoisReasons = buildWhoisReasons(info);
        phishingReasons.addAll(whoisReasons);
      }

      // Save to history AFTER phishing reasons are completed
      await addToHistory(
        url: url,
        resultStatus: historyResult,
        confidence: confidenceText,
        reasons: phishingReasons,
      );

      setState(() {
        whoisLoading = false;

        whoisResult =
            "WHOIS API Information\n\n"
            "Domain: ${info.domainName}\n"
            "Registrar: ${info.registrarName}\n"
            "Created: ${info.createdDate}\n"
            "Updated: ${info.updatedDate}\n"
            "Expires: ${info.expiresDate}\n"
            "Domain Age: ${info.domainAge}";
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

    if (lowerUrl.contains("bit.ly") || lowerUrl.contains("tinyurl")) {
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

  void clearAll() {
    controller.clear();

    setState(() {
      result = "";
      whoisResult = "";
      loading = false;
      whoisLoading = false;
      phishingReasons = [];
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color resultColor = result.contains("SAFE")
        ? Colors.green
        : result.contains("PHISHING")
            ? Colors.red
            : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text("SmartLink"),
        centerTitle: true,
        actions: [
          IconButton(
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.security,
              size: 80,
              color: Colors.blue,
            ),

            const SizedBox(height: 10),

            const Text(
              "Offline Phishing Detection",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              modelLoaded
                  ? "App ready. Enter URL to analyze."
                  : "Loading app...",
              style: TextStyle(
                color: modelLoaded ? Colors.green : Colors.orange,
              ),
            ),

            const SizedBox(height: 25),

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
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : analyze,
                child: Text(
                  loading ? "Analyzing..." : "Analyze",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 30),

            if (loading)
              const CircularProgressIndicator()
            else if (result.isNotEmpty)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        result,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: resultColor,
                        ),
                      ),

                      if (result.contains("PHISHING"))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ElevatedButton.icon(
                            onPressed: showWhyPhishingDialog,
                            icon: const Icon(Icons.info_outline),
                            label: const Text("Why is this phishing?"),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            if (whoisLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Loading WHOIS information..."),
                ],
              )
            else if (whoisResult.isNotEmpty)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    whoisResult,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 30),

            const Text(
              "SmartLink uses TensorFlow Lite for offline phishing detection and WhoisXML API for online domain registration information.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}