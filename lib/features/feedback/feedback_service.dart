import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import 'feedback_data.dart';

class FeedbackService {
  Future<bool> submit(FeedbackData data) async {
    final url = '${AppConstants.feedbackBaseUrl}/feedback';
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[Feedback] status=${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Feedback] error: $e');
      return false;
    }
  }
}
