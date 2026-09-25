/// Simula a leitura persistida nas plataformas sem `window.localStorage`.
String? readLocal(String key) => null;

/// Ignora a escrita local nas plataformas que não oferecem armazenamento web.
void writeLocal(String key, String value) {}

/// Simula a leitura de sessão fora do navegador.
String? readSession(String key) => null;

/// Ignora a escrita de sessão fora do navegador.
void writeSession(String key, String? value) {}
