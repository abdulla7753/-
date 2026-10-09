import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int? status;
  final List<String> messages;
  const ApiException(this.messages, {this.status});
  @override
  String toString() => messages.join('\n');
}

class JobStatus {
  final String jobId;
  final String status; // queued | building | running | analysing | done | failed
  final double progress;
  final String message;
  final List<String> errors;
  final Map<String, dynamic>? result;
  JobStatus.fromJson(Map<String, dynamic> j)
      : jobId = j['jobId'] as String,
        status = j['status'] as String,
        progress = (j['progress'] as num?)?.toDouble() ?? 0,
        message = j['message'] as String? ?? '',
        errors = [for (final e in (j['errors'] as List? ?? const [])) '$e'],
        result = j['result'] as Map<String, dynamic>?;

  bool get finished => status == 'done' || status == 'failed';
}

/// Client of the RoadFlow simulation server (see docs/API.md).
class SimulationApi {
  final String baseUrl;
  final String? token;
  final http.Client _http;
  final Duration timeout;

  SimulationApi(String baseUrl, {this.token, http.Client? client, this.timeout = const Duration(seconds: 30)})
      : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _http = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    final http.Response r;
    try {
      r = await call().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(['timeout']);
    } catch (e) {
      throw ApiException(['network: $e']);
    }
    // The server sends UTF-8 JSON without a charset parameter; never let the
    // HTTP library fall back to Latin-1 (it would garble Arabic messages).
    final text = utf8.decode(r.bodyBytes, allowMalformed: true);
    final body = text.isEmpty ? null : _decode(text);
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    throw ApiException(_errorMessages(body, text), status: r.statusCode);
  }

  static dynamic _decode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return s;
    }
  }

  /// FastAPI errors: {"detail": "..."} | {"detail": [{"loc":..,"msg":..}]} | {"detail": {"errors": [...]}}.
  static List<String> _errorMessages(dynamic body, String raw) {
    if (body is Map && body['detail'] != null) {
      final d = body['detail'];
      if (d is String) return [d];
      if (d is List) {
        return [
          for (final e in d)
            if (e is Map) '${(e['loc'] as List?)?.skip(1).join('.') ?? ''}: ${e['msg']}' else '$e'
        ];
      }
      if (d is Map && d['errors'] is List) return [for (final e in d['errors'] as List) '$e'];
      return ['$d'];
    }
    return [raw.length > 500 ? raw.substring(0, 500) : raw];
  }

  Future<Map<String, dynamic>> health() async =>
      (await _send(() => _http.get(_u('/health'), headers: _headers))) as Map<String, dynamic>;

  Future<Map<String, dynamic>> buildNetwork(Map<String, dynamic> request) async =>
      (await _send(() => _http.post(_u('/v1/networks/build'), headers: _headers, body: jsonEncode(request))))
          as Map<String, dynamic>;

  Future<JobStatus> submit(Map<String, dynamic> request) async => JobStatus.fromJson(
      (await _send(() => _http.post(_u('/v1/simulations'), headers: _headers, body: jsonEncode(request))))
          as Map<String, dynamic>);

  Future<JobStatus> status(String jobId) async =>
      JobStatus.fromJson((await _send(() => _http.get(_u('/v1/simulations/$jobId'), headers: _headers))) as Map<String, dynamic>);

  Future<Map<String, dynamic>> network(String jobId) async =>
      (await _send(() => _http.get(_u('/v1/simulations/$jobId/network'), headers: _headers))) as Map<String, dynamic>;

  Future<Map<String, dynamic>> trajectory(String jobId) async =>
      (await _send(() => _http.get(_u('/v1/simulations/$jobId/trajectory'), headers: _headers))) as Map<String, dynamic>;

  Future<void> delete(String jobId) async {
    try {
      await _send(() => _http.delete(_u('/v1/simulations/$jobId'), headers: _headers));
    } on ApiException {
      // best effort
    }
  }

  void close() => _http.close();
}
