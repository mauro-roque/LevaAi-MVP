import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Registra o botão oficial do Google dentro de um elemento HTML do Flutter.
@JS('levaAiRenderGoogleButton')
external void _renderGoogleButton(JSString elementId, JSString clientId);

/// Exibe a interface oficial do Google no lugar do botão visual do aplicativo.
class GoogleOfficialButton extends StatefulWidget {
  const GoogleOfficialButton({
    super.key,
    required this.clientId,
    required this.onCredential,
    required this.enabled,
  });

  final String clientId;
  final ValueChanged<String> onCredential;
  final bool enabled;

  @override
  State<GoogleOfficialButton> createState() => _GoogleOfficialButtonState();
}

class _GoogleOfficialButtonState extends State<GoogleOfficialButton> {
  static var _sequence = 0;
  late final String _hostId = 'levaai-google-button-${_sequence++}';
  late final String _viewType = '$_hostId-view';
  late final JSFunction _credentialListener;

  @override
  void initState() {
    super.initState();
    _credentialListener = ((web.Event event) {
      if (!mounted || event is! web.CustomEvent) return;
      final credential = event.detail;
      if (credential is JSString) widget.onCredential(credential.toDart);
    }).toJS;
    web.window.addEventListener('levaai-google-credential', _credentialListener);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      final host = web.HTMLDivElement()
        ..id = _hostId
        ..style.width = '100%'
        ..style.height = '44px'
        ..style.display = 'flex'
        ..style.justifyContent = 'center'
        ..style.alignItems = 'center'
        ..style.opacity = '1'
        ..style.transition = 'opacity 120ms ease';
      // Reserva o mesmo espaço do botão oficial desde o primeiro quadro.
      // Assim, a chegada da biblioteca do Google não desloca nem pisca a tela.
      final loading = web.HTMLSpanElement()
        ..textContent = 'Carregando acesso Google...'
        ..style.width = '100%'
        ..style.maxWidth = '400px'
        ..style.height = '42px'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.border = '1px solid #dadce0'
        ..style.borderRadius = '4px'
        ..style.background = '#ffffff'
        ..style.color = '#5f6368'
        ..style.fontFamily = 'Roboto, Arial, sans-serif'
        ..style.fontSize = '14px';
      host.append(loading);
      Future<void>.delayed(Duration.zero, () {
        _renderGoogleButton(_hostId.toJS, widget.clientId.toJS);
      });
      return host;
    });
  }

  @override
  void dispose() {
    web.window.removeEventListener(
      'levaai-google-credential',
      _credentialListener,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !widget.enabled,
    child: Opacity(
      opacity: widget.enabled ? 1 : .55,
      child: SizedBox(
        height: 44,
        width: double.infinity,
        child: HtmlElementView(viewType: _viewType),
      ),
    ),
  );
}
