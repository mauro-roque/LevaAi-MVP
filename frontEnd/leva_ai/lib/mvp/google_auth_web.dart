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
      // O host não possui estilos próprios neste teste. O botão será exibido
      // somente com os padrões visuais definidos pela biblioteca do Google.
      final host = web.HTMLDivElement()..id = _hostId;
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
      // Mantém somente o espaço físico necessário ao componente oficial.
      // Não há estilo visual aplicado pelo LevaAí.
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: 400,
          height: 44,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    ),
  );
}
