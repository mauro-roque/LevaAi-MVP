import 'package:flutter/material.dart';

/// Catálogo alternativo mantido como ponto de extensão para uma listagem pública.
///
/// O fluxo principal do MVP usa `mvp/app.dart`; esta tela permanece simples para
/// evitar duplicar regras de cotação enquanto o catálogo público não é integrado.
class FreightCatalogPage extends StatelessWidget {
  const FreightCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LevaAí - Catálogo')),
      body: const Center(child: Text('Lista de fretadores')),
    );
  }
}
