import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api {
  final http.Client client;
  String? token;
  Api({http.Client? client}) : client = client ?? http.Client();
  static String get baseUrl {
    const configured = String.fromEnvironment('API_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb && Uri.base.port == 3000) return Uri.base.origin;
    return 'http://localhost:3000';
  }

  Future<dynamic> call(String path, {String method = 'GET', Json? body}) async {
    try {
      final request = http.Request(method, Uri.parse('$baseUrl/api$path'));
      request.headers['Content-Type'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 50)),
      ).timeout(const Duration(seconds: 50));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 400) {
        throw ApiException(
          data['error'] ?? 'Não foi possível concluir.',
          response.statusCode,
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Não foi possível acessar o servidor. Verifique a conexão e tente novamente.',
      );
    }
  }

  void dispose() => client.close();
}
