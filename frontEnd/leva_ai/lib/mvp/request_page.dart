import 'package:flutter/material.dart';
import 'api.dart';
import 'ui.dart';
import 'route_map.dart';

class RequestPage extends StatefulWidget {
  final Api api;
  final Json config;
  final VoidCallback onBooked;
  const RequestPage({
    super.key,
    required this.api,
    required this.config,
    required this.onBooked,
  });
  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  final form = GlobalKey<FormState>();
  final items = TextEditingController(),
      weight = TextEditingController(text: '100'),
      volume = TextEditingController(text: '2');
  DateTime date = DateTime.now().add(const Duration(days: 1));
  Json? origin, destination, result;
  bool demoRoute = false, loading = false;
  String type = 'frete';
  int helpers = 0;
  String? error;
  @override
  void dispose() {
    items.dispose();
    weight.dispose();
    volume.dispose();
    super.dispose();
  }

  void invalidate() {
    if (result != null) setState(() => result = null);
  }

  void useExample() {
    final places = widget.config['demoPlaces'] as List;
    setState(() {
      origin = Map<String, dynamic>.from(places[0]);
      destination = Map<String, dynamic>.from(places[1]);
      demoRoute = true;
      items.text = '1 sofá de dois lugares e 4 caixas';
      weight.text = '100';
      volume.text = '2';
      helpers = 1;
      result = null;
      error = null;
    });
  }

  Future<void> quote() async {
    if (loading || !form.currentState!.validate()) return;
    if (origin == null || destination == null) {
      setState(
        () => error = 'Busque e selecione os dois endereços para continuar.',
      );
      return;
    }
    setState(() {
      loading = true;
      error = null;
      result = null;
    });
    try {
      final data = await widget.api.call(
        '/quotes',
        method: 'POST',
        body: {
          'origin': origin,
          'destination': destination,
          'date': date.toIso8601String().substring(0, 10),
          'type': type,
          'items': items.text,
          'weightKg': double.parse(weight.text.replaceAll(',', '.')),
          'volumeM3': double.parse(volume.text.replaceAll(',', '.')),
          'helpers': helpers,
          'demoRoute': demoRoute,
        },
      );
      if (mounted) setState(() => result = data);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> book(Json quote) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.call(
        '/bookings',
        method: 'POST',
        body: {'quoteId': quote['id']},
      );
      if (mounted) widget.onBooked();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String? positive(String? value) {
    final n = double.tryParse((value ?? '').replaceAll(',', '.'));
    return n == null || n <= 0 ? 'Informe um valor maior que zero.' : null;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1150;
    final formPanel = Panel(
      child: AbsorbPointer(
        absorbing: loading,
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.route_outlined, color: blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'De onde para onde?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              AddressField(
                api: widget.api,
                label: 'Endereço de origem',
                value: origin,
                onChanged:
                    (v) => setState(() {
                      origin = v;
                      result = null;
                      if (v == null) demoRoute = false;
                    }),
              ),
              const SizedBox(height: 16),
              AddressField(
                api: widget.api,
                label: 'Endereço de destino',
                value: destination,
                onChanged:
                    (v) => setState(() {
                      destination = v;
                      result = null;
                      if (v == null) demoRoute = false;
                    }),
              ),
              if (widget.config['demo'] == true) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: useExample,
                  icon: const Icon(Icons.science_outlined, size: 17),
                  label: const Text('Preencher um frete de exemplo'),
                ),
              ],
              if (demoRoute)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Usar rota simulada',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Desative para consultar o trajeto real.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: demoRoute,
                  onChanged:
                      (v) => setState(() {
                        demoRoute = v;
                        result = null;
                      }),
                ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'O que vamos levar?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Pequeno frete'),
                    avatar: const Icon(Icons.inventory_2_outlined, size: 17),
                    selected: type == 'frete',
                    onSelected:
                        (_) => setState(() {
                          type = 'frete';
                          result = null;
                        }),
                  ),
                  ChoiceChip(
                    label: const Text('Mudança'),
                    avatar: const Icon(Icons.home_outlined, size: 17),
                    selected: type == 'mudanca',
                    onSelected:
                        (_) => setState(() {
                          type = 'mudanca';
                          result = null;
                        }),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: items,
                maxLines: 3,
                onChanged: (_) => invalidate(),
                decoration: const InputDecoration(
                  labelText: 'Itens e quantidades',
                  hintText: 'Ex.: 1 geladeira, 1 cama e 8 caixas',
                ),
                validator:
                    (v) =>
                        (v?.trim().length ?? 0) < 3
                            ? 'Descreva os itens e suas quantidades.'
                            : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: weight,
                      onChanged: (_) => invalidate(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Peso total (kg)',
                      ),
                      validator: positive,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: volume,
                      onChanged: (_) => invalidate(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Volume total (m³)',
                      ),
                      validator: positive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          helpText: 'Quando será o frete?',
                          cancelText: 'Voltar',
                          confirmText: 'Selecionar',
                        );
                        if (picked != null) {
                          setState(() {
                            date = picked;
                            result = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        dateLabel(date.toIso8601String().substring(0, 10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: helpers,
                      selectedItemBuilder:
                          (context) => List.generate(
                            7,
                            (i) => Text(
                              i == 0 ? 'Nenhum' : '$i',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      decoration: const InputDecoration(labelText: 'Ajudantes'),
                      items: List.generate(
                        7,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text(
                            i == 0
                                ? 'Sem ajudante'
                                : '$i ${i == 1 ? 'ajudante' : 'ajudantes'}',
                          ),
                        ),
                      ),
                      onChanged:
                          (v) => setState(() {
                            helpers = v!;
                            result = null;
                          }),
                    ),
                  ),
                ],
              ),
              if (error != null) Notice(error!, error: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading ? null : quote,
                  icon:
                      loading
                          ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.search, size: 20),
                  label: Text(
                    loading ? 'Consultando…' : 'Encontrar prestadores',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Compare os valores antes de contratar.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final summary = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CADA DETALHE CONTA',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              color: blue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            result == null ? 'Seu frete começa aqui.' : 'Sua rota, calculada.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (result != null) ...[
            RouteMap(route: result!['route']),
            const SizedBox(height: 16),
            Text(
              '${decimal(result!['route']['distanceKm'])} km • aproximadamente ${result!['route']['durationMinutes']} min',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'O tempo é uma estimativa do trajeto, sem carga e descarga.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ] else ...[
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: blue,
                size: 76,
              ),
            ),
            const SizedBox(height: 24),
            tip(
              Icons.location_on_outlined,
              'Informe o percurso',
              'Busque os endereços completos e escolha a data.',
            ),
            tip(
              Icons.tune,
              'Encontre a combinação certa',
              'Filtramos capacidade, ajudantes e região de atendimento.',
            ),
            tip(
              Icons.handshake_outlined,
              'Escolha com tranquilidade',
              'O Pix é liberado depois do aceite do prestador.',
            ),
          ],
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Como calculamos',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quilômetros × valor por km\n+ quantidade × valor do ajudante',
            style: TextStyle(fontSize: 12, height: 1.8, color: muted),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          context,
          'Vamos levar o quê hoje?',
          'Um frete que cabe na sua rotina. E no seu bolso.',
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 22),
          child: Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              Text(
                '01  Detalhes do frete',
                style: TextStyle(
                  color: blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                '02  Escolha do prestador',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                '03  Confirmação e Pix',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: formPanel),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: summary),
            ],
          )
        else ...[
          formPanel,
          const SizedBox(height: 20),
          summary,
        ],
        if (result != null) ...[
          const SizedBox(height: 32),
          sectionTitle(
            context,
            'Prestadores para o seu frete',
            '${(result!['quotes'] as List).length} opções compatíveis • valores válidos por 15 minutos',
          ),
          if ((result!['quotes'] as List).isEmpty)
            const Panel(
              child: Notice(
                'Nenhum veículo disponível para essa data e carga. Tente outra data ou confira peso, volume e ajudantes.',
              ),
            ),
          for (final q in result!['quotes'])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: quoteCard(Map<String, dynamic>.from(q)),
            ),
        ],
      ],
    );
  }

  Widget tip(IconData icon, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget quoteCard(Json q) {
    final d = q['data'], v = d['vehicle'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEDF2FF),
                child: Icon(Icons.local_shipping_outlined, color: blue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d['providerName'],
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${v['model']} • ${v['type']}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFE9A934),
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                d['rating'] == null
                    ? 'Novo'
                    : '${decimal(d['rating'])} (${d['reviewCount']})',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Text(
                '${decimal(v['capacityKg'])} kg / ${decimal(v['volumeM3'])} m³',
              ),
              Text('${decimal(d['providerDistanceKm'])} km da origem'),
              Text('${money(v['pricePerKmCents'])}/km'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Transporte ${money(d['transportCents'])} + ajudantes ${money(d['helpersCents'])}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                money(d['totalCents']),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              FilledButton(
                onPressed: loading ? null : () => book(q),
                child: const Text('Solicitar este prestador'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
