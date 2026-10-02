import 'dart:io';

class AuthenticityService {
  Future<Map<String, dynamic>> score(File imageFile, Map<String, dynamic> exif) async {
    // Reference only: mirror the Python heuristic fields so mobile and backend speak the same schema.
    return <String, dynamic>{
      'trustStatus': 'clear',
      'score': 1.0,
      'reasons': <String>[],
    };
  }
}
