class VeiculoEntidade {
  const VeiculoEntidade({
    required this.modelo,
    required this.tipo,
    required this.capacidadeKg,
    required this.volumeM3,
    required this.comprimentoM,
    required this.larguraM,
    required this.alturaM,
  });
  final String modelo;
  final String tipo;
  final double capacidadeKg;
  final double volumeM3;
  final double comprimentoM;
  final double larguraM;
  final double alturaM;
}
