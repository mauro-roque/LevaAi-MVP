import 'package:flutter/material.dart';

/// Implementação usada fora da Web: o botão não é exibido nessas plataformas.
class GoogleOfficialButton extends StatelessWidget {
  const GoogleOfficialButton({
    super.key,
    required this.clientId,
    required this.onCredential,
    required this.enabled,
  });

  final String clientId;
  final ValueChanged<String> onCredential;
  final bool enabled;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
