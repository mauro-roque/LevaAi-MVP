import 'package:flutter/material.dart';

import 'mvp/app.dart';

/// Inicia o aplicativo Flutter com a configuração visual e de sessão do MVP.
void main() => runApp(const AplicacaoLevaAi());

/// Contêiner inicial mantido para concentrar futuras configurações globais.
class AplicacaoLevaAi extends StatelessWidget {
  const AplicacaoLevaAi({super.key});
  @override
  Widget build(BuildContext context) => const LevaAiMvp();
}
