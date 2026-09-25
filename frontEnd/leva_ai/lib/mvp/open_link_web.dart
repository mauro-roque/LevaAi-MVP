import 'package:web/web.dart' as web;

/// Abre um link externo em outra aba nas plataformas web.
bool openLink(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
  return true;
}
