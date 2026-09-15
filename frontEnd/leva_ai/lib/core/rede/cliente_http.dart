abstract interface class ClienteHttp {
  Future<Map<String, dynamic>> obter(String caminho);
}
