import 'package:flutter/material.dart';
import '../../../domain/entities/transportador_entidade.dart';

class CartaoTransportador extends StatelessWidget {
  const CartaoTransportador({
    super.key,
    required this.transportador,
    required this.aoTocar,
  });

  final TransportadorEntidade transportador;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                child: Icon(Icons.local_shipping_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transportador.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${transportador.veiculo.modelo} · ${transportador.areaAtuacao}',
                    ),
                    Text(
                      '${transportador.veiculo.capacidadeKg.toStringAsFixed(0)} kg · ${transportador.veiculo.volumeM3} m³',
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  Text(transportador.avaliacao.toString()),
                  Text('R\$ ${transportador.valorInicial.toStringAsFixed(0)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
