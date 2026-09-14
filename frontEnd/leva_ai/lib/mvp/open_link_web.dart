import 'package:web/web.dart' as web;

bool openLink(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
  return true;
}
