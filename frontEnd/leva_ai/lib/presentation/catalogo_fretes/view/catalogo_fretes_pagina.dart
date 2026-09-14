import 'package:flutter/material.dart';
import 'package:leva_ai/core/constants/constantes_app.dart';
import 'package:leva_ai/core/routes/rotas_app.dart';
import 'package:leva_ai/presentation/compartilhado/widgets/cartao_transportador.dart';
import 'package:leva_ai/presentation/freight_catalog/viewmodels/catalogo_fretes_viewmodel.dart';


class CatalogoFretesPagina extends StatefulWidget {
  const CatalogoFretesPagina({super.key, required this.viewModel});
  final CatalogoFretesViewModel viewModel;
  @override
  State<CatalogoFretesPagina> createState() => _CatalogoFretesPaginaState();
}

class _CatalogoFretesPaginaState extends State<CatalogoFretesPagina> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.carregar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Encontre seu frete')),
    body: AnimatedBuilder(
      animation: widget.viewModel,
      builder: (_, __) {
        if (widget.viewModel.carregando) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Qual serviço você precisa?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ['Mudança', 'Carga pesada', 'Carreto pequeno']
                  .map(
                    (t) => FilterChip(
                      label: Text(t),
                      onSelected: (_) => setState(() {}),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Melhores opções para você',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            ...widget.viewModel.transportadores.map(
              (t) => CartaoTransportador(
                transportador: t,
                aoTocar: () => Navigator.pushNamed(
                  context,
                  RotasApp.detalhes,
                  arguments: t,
                ),
              ),
            ),
          ],
        );
      },
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 0,
      indicatorColor: ConstantesApp.azulPrincipal.withValues(alpha: .12),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Início',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Histórico',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ],
    ),
  );
}
