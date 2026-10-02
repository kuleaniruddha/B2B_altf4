import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectorService {
  DetectorService(this.interpreter);

  final Interpreter interpreter;
  static const int inputSize = 512;
  static const double defaultScoreThreshold = 0.35;

  Future<List<Map<String, dynamic>>> detectIssue(File imageFile) async {
    // Reference only: preprocess, run inference, decode raw tensor outputs, then apply NMS in Dart.
    return <Map<String, dynamic>>[];
  }
}
