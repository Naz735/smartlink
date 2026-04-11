import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  late Interpreter _interpreter;
  bool _modelLoaded = false;

  // =========================
  // ✅ LOAD MODEL
  // =========================
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/model/phishing_model.tflite',
      );

      _modelLoaded = true;

      print("✓ Model loaded");
      print("Interpreter hash: ${_interpreter.hashCode}");
      print("Input shape: ${_interpreter.getInputTensors()[0].shape}");
      print("Output shape: ${_interpreter.getOutputTensors()[0].shape}");
    } catch (e) {
      _modelLoaded = false;
      throw Exception("Model load failed: $e");
    }
  }

  // =========================
  // ✅ PREDICT
  // =========================
  List<double> predict(List<double> input) {
    if (!_modelLoaded) {
      throw Exception("Model not loaded");
    }

    if (input.length != 8) {
      throw Exception("Expected 8 features, got ${input.length}");
    }

    try {
      // ✅ IMPORTANT: 2D input [1,8]
      final inputTensor = [input];

      // ✅ IMPORTANT: 2D output [1,1]
      final outputTensor = [
        [0.0]
      ];

      print("Input tensor: $inputTensor");

      // 🚀 RUN MODEL
      _interpreter.run(inputTensor, outputTensor);

      print("Raw output: $outputTensor");

      double result = outputTensor[0][0];
      print("Prediction: $result");

      return [result];
    } catch (e) {
      throw Exception("Prediction error: $e");
    }
  }
}