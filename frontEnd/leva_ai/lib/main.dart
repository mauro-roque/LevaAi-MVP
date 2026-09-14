import 'package:flutter/material.dart';

import 'mvp/app.dart';

void main() => runApp(const AplicacaoLevaAi());

class AplicacaoLevaAi extends StatelessWidget {
  const AplicacaoLevaAi({super.key});
  @override
  Widget build(BuildContext context) => const LevaAiMvp();
}
