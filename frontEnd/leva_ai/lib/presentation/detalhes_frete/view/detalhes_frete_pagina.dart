import 'package:flutter/material.dart';
import 'package:leva_ai/domain/entities/transportador_entidade.dart';


class DetalhesFretePagina extends StatelessWidget {
  const DetalhesFretePagina({super.key, required this.transportador});
  final TransportadorEntidade transportador;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalhes do frete')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transportador.nome,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            '${transportador.veiculo.modelo} · ${transportador.veiculo.tipo}',
          ),
          Text('Capacidade: ${transportador.veiculo.capacidadeKg} kg'),
          Text('Volume: ${transportador.veiculo.volumeM3} m³'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              child: const Text('Solicitar orçamento'),
            ),
          ),
        ],
      ),
    ),
  );
}
