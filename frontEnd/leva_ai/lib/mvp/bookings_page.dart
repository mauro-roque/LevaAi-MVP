import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'ui.dart';
import 'route_map.dart';

class BookingsPage extends StatefulWidget {
  final Api api;
  final bool provider, historyOnly, dashboard;
  const BookingsPage({
    super.key,
    required this.api,
    required this.provider,
    this.historyOnly = false,
    this.dashboard = false,
  });
  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  List<dynamic>? bookings;
  String? error, busy;
  String filter = 'Todos';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await widget.api.call('/bookings') as List;
      if (mounted) {
        setState(() {
          bookings = rows;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> action(Json booking, String endpoint, [Json? body]) async {
    if (busy != null) return;
    setState(() {
      busy = booking['id'];
      error = null;
    });
    try {
      final updated = await widget.api.call(
        '/bookings/${booking['id']}/$endpoint',
        method: 'POST',
        body: body ?? {},
      );
      if (mounted) {
        setState(() {
          final index = bookings!.indexWhere((b) => b['id'] == booking['id']);
          bookings![index] = updated;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  Future<void> review(Json booking) async {
    var rating = 5;
    final comment = TextEditingController();
    final result = await showDialog<Json>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, update) => AlertDialog(
                  title: const Text('Como foi seu frete?'),
                  content: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sua avaliação ajuda os próximos clientes.'),
                        const SizedBox(height: 18),
                        Wrap(
                          children: List.generate(
                            5,
                            (i) => IconButton(
                              tooltip: '${i + 1} estrelas',
                              onPressed: () => update(() => rating = i + 1),
                              icon: Icon(
                                i < rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: const Color(0xFFE9A934),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: comment,
                          maxLines: 3,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                            labelText: 'Comentário (opcional)',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Agora não'),
                    ),
                    FilledButton(
                      onPressed:
                          () => Navigator.pop(context, {
                            'rating': rating,
                            'comment': comment.text,
                          }),
                      child: const Text('Enviar avaliação'),
                    ),
                  ],
                ),
          ),
    );
    // O controller permanece vivo durante a animação de fechamento do diálogo.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    comment.dispose();
    if (result != null && mounted) await action(booking, 'review', result);
  }

  bool isClosed(Json b) => [
    'concluido',
    'avaliado',
    'cancelado_cliente',
    'recusado_prestador',
    'pagamento_recusado',
  ].contains(b['status']);
  @override
  Widget build(BuildContext context) {
    final rows =
        (bookings ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .where(
              (b) =>
                  widget.historyOnly
                      ? isClosed(b)
                      : filter == 'Em andamento'
                      ? !isClosed(b)
                      : filter == 'Finalizados'
                      ? isClosed(b)
                      : true,
            )
            .toList();
    final total = (bookings ?? [])
        .where((b) => ['concluido', 'avaliado'].contains(b['status']))
        .fold<num>(0, (sum, b) => sum + b['data']['totalCents']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: sectionTitle(
                context,
                widget.dashboard
                    ? 'Seu trabalho em movimento.'
                    : widget.historyOnly
                    ? 'Histórico de fretes'
                    : widget.provider
                    ? 'Meus serviços'
                    : 'Minhas solicitações',
                widget.provider
                    ? 'Organize seus serviços e acompanhe cada etapa.'
                    : 'Do primeiro contato à entrega, tudo em um só lugar.',
              ),
            ),
            IconButton(
              tooltip: 'Atualizar solicitações',
              onPressed: busy == null ? load : null,
              icon: const Icon(Icons.refresh, color: blue),
            ),
          ],
        ),
        if (widget.dashboard) ...[
          LayoutBuilder(
            builder:
                (context, constraints) => Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    statCard(
                      'Solicitações recebidas',
                      '${bookings?.length ?? 0}',
                      Icons.inbox_outlined,
                      constraints.maxWidth,
                    ),
                    statCard(
                      'Serviços em aberto',
                      '${(bookings ?? []).where((b) => !isClosed(Map<String, dynamic>.from(b))).length}',
                      Icons.route_outlined,
                      constraints.maxWidth,
                    ),
                    statCard(
                      'Total de serviços concluídos',
                      money(total),
                      Icons.account_balance_wallet_outlined,
                      constraints.maxWidth,
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 26),
        ],
        if (!widget.historyOnly)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Wrap(
              spacing: 10,
              children:
                  ['Todos', 'Em andamento', 'Finalizados']
                      .map(
                        (s) => ChoiceChip(
                          label: Text(s),
                          selected: filter == s,
                          onSelected: (_) => setState(() => filter = s),
                        ),
                      )
                      .toList(),
            ),
          ),
        if (error != null) Notice(error!, error: true),
        if (bookings == null && error == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
        if (bookings != null && rows.isEmpty)
          const Panel(
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: muted),
                    SizedBox(height: 16),
                    Text(
                      'Nenhum frete por aqui ainda.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Suas solicitações aparecerão nesta página.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        for (final b in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: bookingCard(b),
          ),
      ],
    );
  }

  Widget statCard(String title, String value, IconData icon, double width) =>
      SizedBox(
        width:
            width > 800
                ? (width - 32) / 3
                : width > 550
                ? (width - 16) / 2
                : width,
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: blue),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
      );
  Widget bookingCard(Json b) {
    final d = b['data'], input = d['input'], payment = b['payment'];
    final status = b['status'] as String, loading = busy != null;
    Widget button(String title, String next, {bool secondary = false}) =>
        secondary
            ? OutlinedButton(
              onPressed:
                  loading ? null : () => action(b, 'status', {'status': next}),
              child: Text(title),
            )
            : FilledButton(
              onPressed:
                  loading ? null : () => action(b, 'status', {'status': next}),
              child: Text(title),
            );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '#${(b['id'] as String).substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              StatusBadge(status),
              Text(
                dateLabel(b['service_date']),
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            widget.provider ? b['client']['name'] : d['providerName'],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${d['vehicle']['model']} • ${decimal(d['route']['distanceKm'])} km • ${input['helpers']} ajudante(s)',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          locationRow(Icons.trip_origin, input['origin']['label']),
          const SizedBox(height: 10),
          locationRow(
            Icons.location_on_outlined,
            input['destination']['label'],
          ),
          const SizedBox(height: 16),
          Text(input['items']),
          const SizedBox(height: 8),
          Text(
            '${decimal(input['weightKg'])} kg • ${decimal(input['volumeM3'])} m³',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                money(d['totalCents']),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Transporte ${money(d['transportCents'])} + ajudantes ${money(d['helpersCents'])}',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
          if (payment != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Pix ${payment['gateway'] == 'demo' ? '(simulado) ' : ''}• ${payment['status']}',
                style: const TextStyle(
                  color: blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (busy == b['id'])
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (widget.provider && status == 'aguardando_prestador') ...[
                button('Aceitar frete', 'pagamento_pendente'),
                button('Recusar', 'recusado_prestador', secondary: true),
              ],
              if (widget.provider && status == 'agendado')
                button('Estou a caminho', 'a_caminho'),
              if (widget.provider && status == 'a_caminho')
                button('Iniciar transporte', 'em_andamento'),
              if (widget.provider && status == 'em_andamento')
                button('Concluir serviço', 'concluido'),
              if (!widget.provider &&
                  status == 'pagamento_pendente' &&
                  payment == null)
                FilledButton.icon(
                  onPressed: loading ? null : () => action(b, 'payment'),
                  icon: const Icon(Icons.pix),
                  label: const Text('Gerar Pix'),
                ),
              if (!widget.provider &&
                  [
                    'aguardando_prestador',
                    'pagamento_pendente',
                  ].contains(status) &&
                  payment == null)
                button(
                  'Cancelar solicitação',
                  'cancelado_cliente',
                  secondary: true,
                ),
              if (!widget.provider && status == 'concluido')
                FilledButton.icon(
                  onPressed: loading ? null : () => review(b),
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Avaliar prestador'),
                ),
            ],
          ),
          if (status == 'aguardando_prestador' && !widget.provider)
            const Notice(
              'Solicitação enviada! O prestador precisa aceitar antes do pagamento. Use “Atualizar solicitações” para consultar o andamento.',
            ),
          if (status == 'pagamento_pendente' && widget.provider)
            const Notice(
              'Aguardando o pagamento do cliente. O serviço será agendado após a confirmação.',
            ),
          if (!widget.provider &&
              payment != null &&
              status == 'pagamento_pendente') ...[
            if (payment['gateway'] == 'demo') ...[
              const Notice(
                'Pix de demonstração: nenhuma cobrança foi gerada. O botão abaixo simula a confirmação do pagamento.',
              ),
              FilledButton.icon(
                onPressed: loading ? null : () => action(b, 'demo-pay'),
                icon: const Icon(Icons.science_outlined),
                label: const Text('Simular pagamento aprovado'),
              ),
            ] else ...[
              const Notice(
                'Pague pelo aplicativo do seu banco e consulte a confirmação abaixo.',
              ),
              if ((payment['data']['qrImage'] as String).isNotEmpty)
                Image.memory(
                  base64Decode(payment['data']['qrImage']),
                  width: 220,
                  height: 220,
                ),
              if ((payment['data']['qrCode'] as String).isNotEmpty) ...[
                SelectableText(
                  payment['data']['qrCode'],
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: payment['data']['qrCode']),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código Pix copiado.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 17),
                  label: const Text('Copiar código Pix'),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: loading ? null : () => action(b, 'payment-check'),
                child: const Text('Consultar pagamento'),
              ),
            ],
          ],
          if (b['review'] != null)
            Notice(
              'Sua avaliação: ${b['review']['rating']} estrelas${b['review']['comment'] == '' ? '' : ' • ${b['review']['comment']}'}',
            ),
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: const Text(
              'Ver rota e histórico',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            children: [
              RouteMap(route: d['route']),
              const SizedBox(height: 20),
              Text(
                'Contato: ${widget.provider ? b['client']['phone'] : b['provider']['phone']}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              for (final h in b['history'])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: blue,
                        size: 17,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusNames[h['status']] ?? h['status'],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        _time(h['created_at']),
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _time(String value) {
    final dt = DateTime.parse(value).toLocal();
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget locationRow(IconData icon, String label) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: blue, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
    ],
  );
}
