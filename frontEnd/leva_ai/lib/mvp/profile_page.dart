import 'package:flutter/material.dart';
import 'api.dart';
import 'ui.dart';

/// Permite editar o perfil e manter endereços favoritos do usuário autenticado.
class ProfilePage extends StatefulWidget {
  final Api api;
  final Json user;
  final ValueChanged<Json> onSaved;

  /// Recebe a sessão e a ação que atualiza os dados do perfil no app raiz.
  const ProfilePage({
    super.key,
    required this.api,
    required this.user,
    required this.onSaved,
  });
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

/// Controla formulários, carregamento e mensagens da página de perfil.
class _ProfilePageState extends State<ProfilePage> {
  late final name = TextEditingController(text: widget.user['name']);
  late final phone = TextEditingController(text: widget.user['phone']);
  final addressName = TextEditingController();
  String? message;
  bool busy = false;
  List<dynamic> addresses = [];
  Json? selected;
  @override
  /// Busca os endereços salvos ao abrir a página.
  void initState() {
    super.initState();
    load();
  }

  /// Atualiza a lista de endereços favoritos vinda da API.
  Future<void> load() async {
    try {
      final data = await widget.api.call('/addresses');
      if (mounted) setState(() => addresses = data);
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    }
  }

  @override
  /// Libera os controladores de texto usados nos formulários.
  void dispose() {
    name.dispose();
    phone.dispose();
    addressName.dispose();
    super.dispose();
  }

  /// Envia nome e telefone alterados e propaga o usuário atualizado.
  Future<void> save() async {
    setState(() => busy = true);
    try {
      final u = await widget.api.call(
        '/me',
        method: 'PATCH',
        body: {'name': name.text, 'phone': phone.text},
      );
      widget.onSaved(u);
      if (mounted) setState(() => message = 'Perfil atualizado.');
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Salva o endereço selecionado e recarrega a lista de favoritos.
  Future<void> saveAddress() async {
    if (selected == null) return;
    setState(() => busy = true);
    try {
      await widget.api.call(
        '/addresses',
        method: 'POST',
        body: {'name': addressName.text, 'point': selected},
      );
      await load();
      if (mounted) setState(() => message = 'Endereço salvo.');
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  /// Monta o formulário de perfil e a seção de endereços favoritos.
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          context,
          'Seus dados',
          'Mantenha seu nome e telefone atualizados.',
        ),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Nome completo'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Telefone com DDD'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : save,
          child: const Text('Salvar perfil'),
        ),
        if (message != null) Notice(message!),
        const SizedBox(height: 24),
        const Divider(),
        sectionTitle(
          context,
          'Endereços favoritos',
          'Use seus endereços na próxima busca.',
        ),
        for (final a in addresses)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined),
            title: Text(a['name']),
            subtitle: Text(a['point']['label']),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: addressName,
          decoration: const InputDecoration(
            labelText: 'Nome do endereço',
            hintText: 'Casa, trabalho…',
          ),
        ),
        const SizedBox(height: 16),
        AddressField(
          api: widget.api,
          label: 'Buscar endereço',
          value: selected,
          onChanged: (p) => setState(() => selected = p),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: busy || selected == null ? null : saveAddress,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Salvar endereço'),
        ),
      ],
    ),
  );
}
