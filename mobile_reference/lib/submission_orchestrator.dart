import 'dart:io';

class SubmissionOrchestrator {
  Future<Map<String, dynamic>> buildSubmission({
    required File imageFile,
    required Map<String, dynamic> exifSummary,
    required Map<String, dynamic> gps,
    required Map<String, dynamic> authenticityFlags,
    required List<Map<String, dynamic>> detections,
    required List<Map<String, dynamic>> wastePredictions,
    required String imageHash,
    required Map<String, dynamic> modelVersions,
    required Map<String, dynamic> latency,
    required String imageUri,
    required String reportId,
  }) async {
    return <String, dynamic>{
      'reportId': reportId,
      'imageUri': imageUri,
      'gps': gps,
      'exifSummary': exifSummary,
      'imageHash': imageHash,
      'mobileDetections': detections,
      'wastePredictions': wastePredictions,
      'authenticityFlags': authenticityFlags,
      'modelVersions': modelVersions,
      'deviceLatencyMs': latency,
    };
  }
}
