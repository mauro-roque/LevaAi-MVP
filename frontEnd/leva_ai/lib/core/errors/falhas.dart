sealed class Falha implements Exception {
  const Falha(this.mensagem);
  final String mensagem;
}

class FalhaDeRede extends Falha {
  const FalhaDeRede([super.mensagem = 'Não foi possível carregar os dados.']);
}

class FalhaInesperada extends Falha {
  const FalhaInesperada([super.mensagem = 'Ocorreu um erro inesperado.']);
}
