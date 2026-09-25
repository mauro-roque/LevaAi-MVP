import 'package:flutter/material.dart';
import 'api.dart';
import 'ui.dart';

/// Conduz o pedido e a confirmação da recuperação de senha.
class RecoveryPage extends StatefulWidget {
  final Api api;

  /// Recebe o cliente de API usado para emitir e consumir o código temporário.
  const RecoveryPage({super.key, required this.api});
  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

/// Armazena os campos e a etapa atual da recuperação de senha.
class _RecoveryPageState extends State<RecoveryPage> {
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController();
  bool sent = false, busy = false;
  String? message;
  @override
  /// Libera os controladores do formulário ao sair da página.
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    super.dispose();
  }

  /// Solicita o código por e-mail ou redefine a senha com o código informado.
  Future<void> submit() async {
    setState(() => busy = true);
    try {
      final data = await widget.api.call(
        sent ? '/auth/reset' : '/auth/forgot',
        method: 'POST',
        body:
            sent
                ? {'code': code.text, 'password': password.text}
                : {'email': email.text},
      );
      if (!mounted) return;
      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha atualizada. Entre com a nova senha.'),
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          sent = true;
          message = data['message'];
        });
      }
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  /// Exibe os campos necessários para a etapa atual da recuperação.
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recuperar acesso')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_reset, size: 52, color: blue),
                const SizedBox(height: 24),
                Text(
                  sent ? 'Defina sua nova senha' : 'Esqueceu sua senha?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                if (!sent)
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail cadastrado',
                    ),
                  ),
                if (sent) ...[
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Código recebido por e-mail',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nova senha • mínimo de 8 caracteres',
                    ),
                  ),
                ],
                if (message != null) Notice(message!),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Aguarde…'
                        : sent
                        ? 'Atualizar senha'
                        : 'Enviar código',
                  ),
                ),
                if (!sent)
                  TextButton(
                    onPressed: () => setState(() => sent = true),
                    child: const Text('Já tenho um código'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
