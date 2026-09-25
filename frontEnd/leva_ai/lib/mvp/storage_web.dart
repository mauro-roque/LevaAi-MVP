import 'package:web/web.dart' as web;

/// Lê uma preferência que deve sobreviver ao fechamento do navegador.
String? readLocal(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

/// Salva uma preferência persistente sem interromper o fluxo se o navegador negar acesso.
void writeLocal(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {}
}

/// Lê um dado limitado à aba atual, como o token de sessão.
String? readSession(String key) {
  try {
    return web.window.sessionStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

/// Atualiza ou remove um dado limitado à aba atual do navegador.
void writeSession(String key, String? value) {
  try {
    if (value == null) {
      web.window.sessionStorage.removeItem(key);
    } else {
      web.window.sessionStorage.setItem(key, value);
    }
  } catch (_) {}
}
