import 'package:flutter/material.dart';
import 'services/tflite_service.dart';
import 'utils/feature_extractor.dart';

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

  String result = "";
  bool loading = false;
  bool modelLoaded = false;

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

  void analyze() async {
    if (controller.text.isEmpty) return;

    if (!modelLoaded) {
      setState(() {
        result = "Model still loading...";
      });
      return;
    }

    setState(() {
      loading = true;
      result = "";
    });

    try {
      String url = controller.text.trim();

      List<double> features = extractFeatures(url);

      var output = tflite.predict(features);
      double score = output[0];

      print("Score: $score");

      setState(() {
        loading = false;

        if (score > 0.5) {
          result =
              "SAFE ✅\nConfidence: ${(score * 100).toStringAsFixed(2)}%";
        } else {
          result =
              "PHISHING ⚠️\nConfidence: ${((1 - score) * 100).toStringAsFixed(2)}%";
        }
      });
    } catch (e) {
      setState(() {
        loading = false;
        result = "Analysis failed: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SmartLink"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Offline Phishing Detection",
                style: TextStyle(fontSize: 18)),

            const SizedBox(height: 20),

            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Enter URL",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: analyze,
              child: const Text("Analyze"),
            ),

            const SizedBox(height: 30),

            loading
                ? const CircularProgressIndicator()
                : Text(
                    result,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: result.contains("SAFE")
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}