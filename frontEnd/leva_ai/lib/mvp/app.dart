import 'package:flutter/material.dart';
import 'api.dart';
import 'ui.dart';
import 'request_page.dart';
import 'bookings_page.dart';
import 'vehicles_page.dart';

/// Raiz do fluxo principal do MVP: sessão, navegação e carregamento inicial.
class LevaAiMvp extends StatefulWidget {
  final Api? api;
  const LevaAiMvp({super.key, this.api});
  @override
  State<LevaAiMvp> createState() => _LevaAiMvpState();
}

class _LevaAiMvpState extends State<LevaAiMvp> {
  late final Api api = widget.api ?? Api();
  Json? config, user;
  Object? error;
  int page = 0, revision = 0;

  bool get serviceStarting =>
      error is ApiException && (error as ApiException).status == 503;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final result = await api.call('/config');
      if (mounted) setState(() => config = result);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LevaAí • Fretes e mudanças',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home:
        config == null
            ? Scaffold(
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Brand(),
                        const SizedBox(height: 30),
                        if (error == null)
                          const CircularProgressIndicator()
                        else ...[
                          Icon(
                            serviceStarting
                                ? Icons.cloud_sync_outlined
                                : Icons.cloud_off_outlined,
                            size: 38,
                            color: serviceStarting ? blue : Colors.red.shade700,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            serviceStarting
                                ? 'Estamos preparando sua conexão segura.'
                                : 'Não foi possível conectar ao LevaAí.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Notice(
                            serviceStarting
                                ? 'O serviço ficará disponível em instantes. Seus dados permanecem protegidos.'
                                : error.toString(),
                            error: !serviceStarting,
                          ),
                          FilledButton(
                            onPressed: load,
                            child: Text(
                              serviceStarting
                                  ? 'Verificar novamente'
                                  : 'Tentar novamente',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            )
            : user == null
            ? AuthPage(
              api: api,
              demo: config!['demo'] == true,
              onAuthenticated: (data) {
                api.token = data['token'];
                setState(() {
                  user = data['user'];
                  page = 0;
                });
              },
            )
            : Builder(builder: (context) => shell(context)),
  );

  Widget shell(BuildContext context) {
    final provider = user!['role'] == 'prestador';
    final nav =
        provider
            ? ['Visão geral', 'Meus veículos', 'Meus serviços', 'Meu perfil']
            : ['Novo frete', 'Minhas solicitações', 'Histórico', 'Meu perfil'];
    final icons =
        provider
            ? [
              Icons.grid_view_rounded,
              Icons.local_shipping_outlined,
              Icons.receipt_long_outlined,
              Icons.person_outline,
            ]
            : [
              Icons.add_box_outlined,
              Icons.route_outlined,
              Icons.history,
              Icons.person_outline,
            ];
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    void select(int i) {
      setState(() {
        page = i;
        revision++;
      });
      if (!desktop) Navigator.pop(context);
    }

    final sidebar = Container(
      width: 244,
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(left: 12), child: Brand()),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  provider ? 'PAINEL DO PRESTADOR' : 'PAINEL DO CLIENTE',
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              for (var i = 0; i < nav.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color:
                        page == i
                            ? const Color(0xFFEEF3FF)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        icons[i],
                        color: page == i ? blue : muted,
                        size: 22,
                      ),
                      title: Text(
                        nav[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              page == i ? FontWeight.w700 : FontWeight.w500,
                          color: page == i ? blue : muted,
                        ),
                      ),
                      onTap: () => select(i),
                    ),
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.support_agent, color: blue),
                    SizedBox(height: 10),
                    Text(
                      'Seu próximo destino,\nmais perto.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Fretes e mudanças sem complicação.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'LevaAí  /  Projeto acadêmico',
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
    Widget content;
    if (page == 3) {
      content = Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(
              context,
              'Meu perfil',
              provider
                  ? 'Você está no perfil de prestador.'
                  : 'Você está no perfil de cliente.',
            ),
            Text(user!['name'], style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(user!['email']),
            Text(user!['phone']),
            if (provider)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponível para novos fretes'),
                value: user!['available'] == true,
                onChanged: (value) async {
                  try {
                    final data = await api.call(
                      '/me/availability',
                      method: 'PATCH',
                      body: {'available': value},
                    );
                    if (mounted) setState(() => user = data);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await api.call('/auth/logout', method: 'POST');
                } catch (_) {
                  /* A sessão expira em oito horas se estiver offline. */
                }
                api.token = null;
                if (mounted) setState(() => user = null);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
            ),
            if (config!['demo'] == true)
              const Notice(
                'Para testar os dois lados do serviço, saia e entre com a conta de demonstração do outro perfil. Os pedidos ficam salvos.',
              ),
          ],
        ),
      );
    } else if (!provider && page == 0) {
      content = RequestPage(
        api: api,
        config: config!,
        onBooked:
            () => setState(() {
              page = 1;
              revision++;
            }),
      );
    } else if (provider && page == 1) {
      content = VehiclesPage(api: api, config: config!);
    } else {
      content = BookingsPage(
        key: ValueKey('$page-$revision-${user!['id']}'),
        api: api,
        provider: provider,
        historyOnly: !provider && page == 2,
        dashboard: provider && page == 0,
      );
    }
    return Scaffold(
      drawer: desktop ? null : Drawer(child: sidebar),
      body: Row(
        children: [
          if (desktop) sidebar,
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 82,
                  padding: EdgeInsets.symmetric(horizontal: desktop ? 36 : 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE9EDF3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (!desktop)
                        Builder(
                          builder:
                              (context) => IconButton(
                                tooltip: 'Abrir menu',
                                onPressed:
                                    () => Scaffold.of(context).openDrawer(),
                                icon: const Icon(Icons.menu),
                              ),
                        ),
                      Text(
                        nav[page],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (config!['demo'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5DA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Demonstração',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF856219),
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: const Color(0xFFEAF0FF),
                        child: Text(
                          (user!['name'] as String)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (desktop) ...[
                        const SizedBox(width: 10),
                        Text(
                          user!['name'],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(desktop ? 36 : 18),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tela de acesso e criação de conta, usada antes da área protegida.
class AuthPage extends StatefulWidget {
  final Api api;
  final bool demo;
  final ValueChanged<Json> onAuthenticated;
  const AuthPage({
    super.key,
    required this.api,
    required this.demo,
    required this.onAuthenticated,
  });
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      phone = TextEditingController();
  final form = GlobalKey<FormState>();
  bool register = false, loading = false, hidden = true;
  String role = 'cliente';
  String? error;
  @override
  void dispose() {
    for (final c in [email, password, name, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (loading || !form.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.call(
        '/auth/${register ? 'register' : 'login'}',
        method: 'POST',
        body: {
          'email': email.text.trim(),
          'password': password.text,
          'name': name.text.trim(),
          'phone': phone.text.trim(),
          'role': role,
        },
      );
      if (mounted) widget.onAuthenticated(result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void demo(String profile) {
    setState(() {
      register = false;
      email.text = '$profile@levaai.demo';
      password.text = 'LevaAi@123';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) submit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    return Scaffold(
      body: Row(
        children: [
          if (wide)
            Expanded(
              child: Container(
                color: const Color(0xFF1748CD),
                padding: const EdgeInsets.all(64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Brand(light: true),
                    const Spacer(),
                    const Text(
                      'Uma nova forma\nde levar a vida.',
                      style: TextStyle(
                        fontSize: 48,
                        height: 1.12,
                        letterSpacing: -1.8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Do pequeno frete à próxima mudança.\nEncontre quem leva, do seu jeito.',
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.6,
                        color: Color(0xFFCCDAFF),
                      ),
                    ),
                    const SizedBox(height: 38),
                    SizedBox(
                      height: 155,
                      width: double.infinity,
                      child: CustomPaint(painter: _TruckPainter()),
                    ),
                    const Spacer(),
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Compare. Escolha. Acompanhe.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 48 : 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!wide) ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Brand(),
                          ),
                          const SizedBox(height: 40),
                        ],
                        Text(
                          register
                              ? 'Vamos começar?'
                              : 'Bom ter você por aqui.',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          register
                              ? 'Crie sua conta e escolha como quer usar o LevaAí.'
                              : 'Entre para encontrar seu próximo frete.',
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 30),
                        if (register) ...[
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'cliente',
                                label: Text('Sou cliente'),
                              ),
                              ButtonSegment(
                                value: 'prestador',
                                label: Text('Sou prestador'),
                              ),
                            ],
                            selected: {role},
                            onSelectionChanged:
                                (v) => setState(() => role = v.first),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'Nome completo',
                            ),
                            validator:
                                (v) =>
                                    (v?.trim().length ?? 0) < 2
                                        ? 'Informe seu nome.'
                                        : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Telefone com DDD',
                            ),
                            validator:
                                (v) =>
                                    (v?.length ?? 0) < 10
                                        ? 'Informe telefone e DDD.'
                                        : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator:
                              (v) =>
                                  v == null || !v.contains('@')
                                      ? 'Informe um e-mail válido.'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: password,
                          obscureText: hidden,
                          onFieldSubmitted: (_) => submit(),
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip:
                                  hidden ? 'Mostrar senha' : 'Ocultar senha',
                              onPressed: () => setState(() => hidden = !hidden),
                              icon: Icon(
                                hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator:
                              (v) =>
                                  (v?.length ?? 0) < (register ? 8 : 1)
                                      ? 'Use ${register ? 8 : 1} ou mais caracteres.'
                                      : null,
                        ),
                        if (error != null) Notice(error!, error: true),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: loading ? null : submit,
                          child: Text(
                            loading
                                ? 'Aguarde…'
                                : register
                                ? 'Criar minha conta'
                                : 'Entrar na minha conta',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed:
                              loading
                                  ? null
                                  : () => setState(() {
                                    register = !register;
                                    error = null;
                                  }),
                          child: Text(
                            register
                                ? 'Já tenho uma conta • Entrar'
                                : 'Ainda não tem conta? Cadastre-se',
                          ),
                        ),
                        if (widget.demo) ...[
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 14),
                          const Text(
                            'EXPLORE O MVP',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.8,
                              color: muted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      loading ? null : () => demo('cliente'),
                                  child: const Text('Testar cliente'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      loading ? null : () => demo('prestador'),
                                  child: const Text('Testar prestador'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Contas de exemplo • Nenhum pagamento real',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TruckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: .12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(18, 20, 170, 98),
        const Radius.circular(14),
      ),
      p,
    );
    p.color = Colors.white.withValues(alpha: .75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(190, 58, 74, 60),
        const Radius.circular(12),
      ),
      p,
    );
    p.color = const Color(0xFF1748CD);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(204, 65, 43, 24),
        const Radius.circular(5),
      ),
      p,
    );
    p.color = Colors.white;
    for (final x in [60.0, 219.0]) {
      canvas.drawCircle(Offset(x, 123), 17, p);
    }
    p.color = const Color(0xFF1748CD);
    for (final x in [60.0, 219.0]) {
      canvas.drawCircle(Offset(x, 123), 8, p);
    }
    p.color = Colors.white.withValues(alpha: .3);
    p.strokeWidth = 2;
    canvas.drawLine(const Offset(0, 146), Offset(size.width, 146), p);
    p.color = const Color(0xFFFFD88A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(92, 40, 48, 46),
        const Radius.circular(5),
      ),
      p,
    );
    p.color = Colors.white.withValues(alpha: .55);
    canvas.drawRect(const Rect.fromLTWH(111, 40, 9, 18), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
