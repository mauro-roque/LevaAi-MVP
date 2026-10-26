import 'dart:js_interop';

/// Chama o Google Identity Services carregado no `index.html` e recebe o ID
/// token assinado. O token é validado novamente no Worker antes do login.
@JS('levaAiGoogleSignIn')
external JSPromise<JSString> _requestGoogleCredential(JSString clientId);

Future<String> requestGoogleCredential(String clientId) async =>
    (await _requestGoogleCredential(clientId.toJS).toDart).toDart;
