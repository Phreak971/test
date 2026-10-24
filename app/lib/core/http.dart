import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Small JSON GET helper with a timeout and one retry on transient failures
/// (network errors, 429, 5xx). Public OSM services ask for an identifying UA.
class JsonClient {
  JsonClient({http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const userAgent = 'Overworld/1.0 (+https://github.com/phreak971/test)';

  Future<dynamic> getJson(Uri uri) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _client
            .get(uri, headers: {'User-Agent': userAgent, 'Accept': 'application/json'})
            .timeout(timeout);
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
        lastError = ApiException('HTTP ${res.statusCode}', statusCode: res.statusCode);
        if (res.statusCode != 429 && res.statusCode < 500) break;
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      }
      if (attempt == 0) await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    if (lastError is ApiException) throw lastError;
    throw ApiException(lastError.toString());
  }

  void close() => _client.close();
}
