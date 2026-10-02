import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';

class WasteClassifierService {
  WasteClassifierService(this.interpreter);

  final Interpreter interpreter;
  static const int inputSize = 224;

  Future<Map<String, dynamic>> classifyCrop(File imageFile) async {
    // Reference only: crop detected region, normalize, run inference, and expose full score map.
    return <String, dynamic>{'label': 'unknown', 'scores': <String, double>{}};
  }
}
