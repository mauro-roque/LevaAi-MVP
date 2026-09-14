import 'package:flutter/material.dart';

class FreightCatalogPage extends StatelessWidget {
  const FreightCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LevaAí - Catálogo')),
      body: const Center(
        child: Text('Lista de Fretadores'),
      ),
    );
  }
}
