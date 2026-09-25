import 'package:flutter/material.dart';
import 'ui.dart';

/// Apresenta o propósito do aplicativo antes da primeira busca de frete.
class Onboarding extends StatefulWidget {
  final VoidCallback onDone;

  /// Recebe a ação que encerra a apresentação e abre a busca.
  const Onboarding({super.key, required this.onDone});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

/// Mantém qual etapa da apresentação está visível.
class _OnboardingState extends State<Onboarding> {
  int step = 0;
  static const titles = [
    'Seu próximo destino começa aqui.',
    'Compare e escolha com confiança.',
    'Do agendamento à entrega.',
  ];
  static const descriptions = [
    'Informe a origem e o destino. Encontre quem transporta seus móveis, caixas e novas histórias.',
    'Veja veículos compatíveis, avaliações e preços detalhados. Pesquise sem precisar de uma conta.',
    'Entre só quando decidir contratar. Acompanhe cada etapa e avalie depois do serviço.',
  ];
  static const icons = [
    Icons.local_shipping_outlined,
    Icons.compare_arrows_rounded,
    Icons.task_alt_rounded,
  ];
  @override
  /// Constrói a etapa atual e os controles para avançar ou pular.
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Row(
                  children: [
                    const Brand(),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onDone,
                      child: const Text('Pular'),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 64),
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0FF),
                            borderRadius: BorderRadius.circular(60),
                          ),
                          child: Icon(icons[step], size: 100, color: blue),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          titles[step],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          descriptions[step],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.6,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Container(
                      margin: const EdgeInsets.all(4),
                      width: i == step ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == step ? blue : const Color(0xFFD5DEEF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        () =>
                            step == 2
                                ? widget.onDone()
                                : setState(() => step++),
                    child: Text(step == 2 ? 'Encontrar meu frete' : 'Próximo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
