import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'storage.dart';

typedef Json = Map<String, dynamic>;

/// Erro padronizado devolvido pela API, com mensagem segura para a interface.
class ApiException implements Exception {
  final String message;
  final int status;

  /// Cria uma falha de interface com o status HTTP quando ele estiver disponível.
  ApiException(this.message, [this.status = 0]);
  @override
  /// Expõe somente a mensagem apropriada para o usuário.
  String toString() => message;
}

/// Cliente HTTP central que mantém a sessão e a origem da API em um só lugar.
class Api {
  final http.Client client;
  String? _token = readSession('levaai.session');

  /// Entrega o token atual para chamadas que exigem autenticação.
  String? get token => _token;

  /// Persiste ou remove o token junto com a sessão da aba atual.
  set token(String? value) {
    _token = value;
    writeSession('levaai.session', value);
  }

  Json? draft;

  /// Aceita um cliente injetado em testes ou cria o cliente HTTP padrão.
  Api({http.Client? client}) : client = client ?? http.Client();

  /// Prioriza `API_URL`; na web publicada, usa a origem do próprio Worker.
  static String get baseUrl {
    const configured = String.fromEnvironment('API_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return Uri.base.origin;
    return 'http://localhost:3000';
  }

  /// Executa uma chamada autenticada e converte falhas em [ApiException].
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

  /// Libera o cliente quando a aplicação ou um teste é encerrado.
  void dispose() => client.close();
}
