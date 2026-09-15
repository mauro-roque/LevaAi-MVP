import 'package:flutter/material.dart';

class EntrarPagina extends StatelessWidget {
  const EntrarPagina({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Que bom ter você de volta!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'E-mail')),
          const SizedBox(height: 12),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(labelText: 'Senha'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () {}, child: const Text('Entrar')),
          ),
        ],
      ),
    ),
  );
}
