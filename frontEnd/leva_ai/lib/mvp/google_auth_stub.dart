/// Implementação usada fora da Web: o botão não é exibido nessas plataformas.
Future<String> requestGoogleCredential(String clientId) =>
    Future.error(UnsupportedError('Login Google disponível somente na Web.'));
