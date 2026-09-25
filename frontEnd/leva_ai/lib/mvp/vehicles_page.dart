import 'package:flutter/material.dart';
import 'api.dart';
import 'ui.dart';

/// Área do prestador para consultar e administrar os veículos disponíveis.
class VehiclesPage extends StatefulWidget {
  final Api api;
  final Json config;

  /// Recebe a sessão do prestador e a configuração de veículos do Worker.
  const VehiclesPage({super.key, required this.api, required this.config});
  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

/// Carrega a frota e abre o editor de inclusão ou alteração de veículos.
class _VehiclesPageState extends State<VehiclesPage> {
  List<dynamic>? vehicles;
  String? error;
  bool updating = false;
  @override
  /// Consulta a frota cadastrada ao abrir a página.
  void initState() {
    super.initState();
    load();
  }

  /// Atualiza a lista de veículos do prestador autenticado.
  Future<void> load() async {
    try {
      final rows = await widget.api.call('/vehicles');
      if (mounted) {
        setState(() {
          vehicles = rows;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  /// Abre o editor para criar ou alterar um veículo e atualiza a lista ao salvar.
  Future<void> edit([Json? vehicle]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => VehicleEditor(
            api: widget.api,
            config: widget.config,
            vehicle: vehicle,
          ),
    );
    if (saved == true) await load();
  }

  /// Altera apenas a disponibilidade, preservando preços e reservas já feitas.
  Future<void> toggleAvailability(Json vehicle) async {
    if (updating) return;
    setState(() {
      updating = true;
      error = null;
    });
    try {
      final updated = await widget.api.call(
        '/vehicles/${vehicle['id']}/availability',
        method: 'PATCH',
        body: {'active': !vehicleIsActive(vehicle)},
      );
      if (!mounted) return;
      setState(() {
        final index = vehicles!.indexWhere((v) => v['id'] == vehicle['id']);
        if (index >= 0) vehicles![index] = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vehicleIsActive(updated)
                ? 'Veículo ativado para novas buscas.'
                : 'Veículo pausado. Seus serviços já contratados continuam.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  @override
  /// Exibe estados de carregamento, erro, vazio e os cartões da frota.
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      sectionTitle(
        context,
        'Sua frota, suas condições.',
        'Cadastre veículos, valores e ajudantes para receber solicitações.',
      ),
      FilledButton.icon(
        onPressed: updating ? null : edit,
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar veículo'),
      ),
      const SizedBox(height: 24),
      if (error != null) ...[
        Notice(error!, error: true),
        TextButton(onPressed: load, child: const Text('Tentar novamente')),
      ],
      if (vehicles == null && error == null)
        const Center(child: CircularProgressIndicator()),
      if (vehicles?.isEmpty == true)
        const Panel(
          child: Notice(
            'Você ainda não cadastrou um veículo. Adicione o primeiro para aparecer nas cotações.',
          ),
        ),
      for (final v in vehicles ?? [])
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      color: blue,
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        v['data']['model'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar veículo',
                      onPressed:
                          updating
                              ? null
                              : () => edit(Map<String, dynamic>.from(v)),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    Text(vehicleTypeLabel(v['data']['type'])),
                    Text(
                      '${decimal(v['data']['capacityKg'])} kg / ${decimal(v['data']['volumeM3'])} m³',
                    ),
                    Text(
                      '${money(v['data']['pricePerKmCents'])}/km',
                      style: const TextStyle(
                        color: blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(vehicleIsActive(v) ? 'Ativo' : 'Pausado'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${v['data']['helpers']} ajudante(s) • ${money(v['data']['helperPriceCents'])} por pessoa',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 8),
                Text(
                  'Base: ${v['data']['base']?['label'] ?? 'Edite para definir o endereço'} • raio de ${decimal(v['data']['radiusKm'])} km',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      updating
                          ? null
                          : () =>
                              toggleAvailability(Map<String, dynamic>.from(v)),
                  icon: Icon(
                    vehicleIsActive(v)
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                  ),
                  label: Text(
                    vehicleIsActive(v) ? 'Pausar veículo' : 'Ativar veículo',
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

/// Editor reutilizável para inclusão e alteração de veículos do prestador.
class VehicleEditor extends StatefulWidget {
  final Api api;
  final Json config;
  final Json? vehicle;

  /// Recebe o veículo opcional que define se o diálogo cria ou atualiza um registro.
  const VehicleEditor({
    super.key,
    required this.api,
    required this.config,
    this.vehicle,
  });
  @override
  State<VehicleEditor> createState() => _VehicleEditorState();
}

/// Mantém os campos e validações do diálogo de veículo.
class _VehicleEditorState extends State<VehicleEditor> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  Json? base;
  String type = 'utilitario';
  int helpers = 0;
  bool active = true, saving = false;
  String? error;
  @override
  /// Inicializa os campos com valores do veículo existente ou valores iniciais.
  void initState() {
    super.initState();
    final d = widget.vehicle?['data'];
    fields = {
      'model': TextEditingController(text: d?['model'] ?? ''),
      'capacityKg': TextEditingController(text: '${d?['capacityKg'] ?? 650}'),
      'volumeM3': TextEditingController(text: '${d?['volumeM3'] ?? 3.3}'),
      'price': TextEditingController(
        text: '${(d?['pricePerKmCents'] ?? 400) / 100}',
      ),
      'helperPrice': TextEditingController(
        text: '${(d?['helperPriceCents'] ?? 8000) / 100}',
      ),
      'radiusKm': TextEditingController(text: '${d?['radiusKm'] ?? 50}'),
    };
    base = d?['base'];
    type = d?['type'] ?? type;
    helpers = d?['helpers'] ?? 0;
    active = widget.vehicle == null || vehicleIsActive(widget.vehicle!);
  }

  @override
  /// Libera todos os controladores mantidos no mapa de campos.
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Converte um campo numérico usando vírgula ou ponto como separador decimal.
  double value(String key) =>
      double.parse(fields[key]!.text.replaceAll(',', '.'));

  /// Valida o formulário e envia inclusão ou alteração para a API.
  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    if (base == null) {
      setState(() => error = 'Busque e selecione o endereço base do veículo.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.call(
        '/vehicles${widget.vehicle == null ? '' : '/${widget.vehicle!['id']}'}',
        method: widget.vehicle == null ? 'POST' : 'PUT',
        body: {
          'model': fields['model']!.text,
          'type': type,
          'capacityKg': value('capacityKg'),
          'volumeM3': value('volumeM3'),
          'pricePerKmCents': (value('price') * 100).round(),
          'helperPriceCents': (value('helperPrice') * 100).round(),
          'helpers': helpers,
          'base': base,
          'radiusKm': value('radiusKm'),
          'active': active,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          saving = false;
        });
      }
    }
  }

  /// Cria um campo do formulário com a validação adequada ao seu tipo.
  Widget field(String key, String label, {bool numeric = true}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (!numeric) {
          return (v?.trim().length ?? 0) < 2 ? 'Informe o modelo.' : null;
        }
        final n = double.tryParse((v ?? '').replaceAll(',', '.'));
        return n == null || n < 0 || (!['helperPrice'].contains(key) && n == 0)
            ? 'Informe um valor válido.'
            : null;
      },
    ),
  );
  @override
  /// Constrói o diálogo responsivo para edição da frota.
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.vehicle == null ? 'Novo veículo' : 'Editar veículo'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: AbsorbPointer(
          absorbing: saving,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                field('model', 'Marca e modelo', numeric: false),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de veículo',
                  ),
                  items:
                      [
                            'motocicleta',
                            'utilitario',
                            'fiorino',
                            'saveiro',
                            'strada',
                            'van',
                            'caminhao_3_4',
                            'vuc',
                            'outros',
                          ]
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(vehicleTypeLabel(s)),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 16),
                field('capacityKg', 'Capacidade de carga (kg)'),
                field('volumeM3', 'Volume útil (m³)'),
                field('price', 'Valor por quilômetro (R\$)'),
                DropdownButtonFormField<int>(
                  value: helpers,
                  decoration: const InputDecoration(
                    labelText: 'Ajudantes disponíveis para este veículo',
                  ),
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text('$i ajudante(s)'),
                    ),
                  ),
                  onChanged: (v) => setState(() => helpers = v!),
                ),
                const SizedBox(height: 16),
                field('helperPrice', 'Valor por ajudante (R\$)'),
                field('radiusKm', 'Raio de atendimento a partir da base (km)'),
                AddressField(
                  api: widget.api,
                  label: 'Endereço base do veículo',
                  value: base,
                  onChanged: (v) => setState(() => base = v),
                ),
                if (widget.config['demo'] == true)
                  TextButton(
                    onPressed:
                        () => setState(
                          () =>
                              base = Map<String, dynamic>.from(
                                widget.config['demoPlaces'][0],
                              ),
                        ),
                    child: const Text('Usar base de exemplo: São Paulo'),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Veículo ativo'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
                if (error != null) Notice(error!, error: true),
              ],
            ),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Voltar'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Salvando…' : 'Salvar veículo'),
      ),
    ],
  );
}
