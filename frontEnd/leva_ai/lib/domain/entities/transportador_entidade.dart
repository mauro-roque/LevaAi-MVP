import 'veiculo_entidade.dart';

class TransportadorEntidade {
  const TransportadorEntidade({
    required this.id,
    required this.nome,
    required this.avaliacao,
    required this.areaAtuacao,
    required this.veiculo,
    this.valorInicial = 0,
  });
  final String id;
  final String nome;
  final double avaliacao;
  final String areaAtuacao;
  final VeiculoEntidade veiculo;
  final double valorInicial;
}
