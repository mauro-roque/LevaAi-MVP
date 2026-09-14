class CotacaoFreteEntidade {
  const CotacaoFreteEntidade({
    required this.origem,
    required this.destino,
    required this.tipoDeCarga,
    required this.pesoKg,
    required this.volumeM3,
  });
  final String origem;
  final String destino;
  final String tipoDeCarga;
  final double pesoKg;
  final double volumeM3;
}
