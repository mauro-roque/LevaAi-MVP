import 'package:flutter/material.dart';
import 'api.dart';

const blue = Color(0xFF2156E8);
const ink = Color(0xFF192840);
const muted = Color(0xFF728097);
const background = Color(0xFFF5F7FB);
String money(num cents) =>
    'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';
String decimal(num n) =>
    n.toStringAsFixed(n % 1 == 0 ? 0 : 1).replaceAll('.', ',');
String dateLabel(String date) => date.split('-').reversed.join('/');
const statusNames = {
  'aguardando_prestador': 'Aguardando prestador',
  'pagamento_pendente': 'Aguardando Pix',
  'agendado': 'Agendado',
  'a_caminho': 'Prestador a caminho',
  'em_andamento': 'Em andamento',
  'concluido': 'Concluído',
  'avaliado': 'Avaliado',
  'cancelado_cliente': 'Cancelado',
  'recusado_prestador': 'Recusado pelo prestador',
  'pagamento_recusado': 'Pagamento recusado',
};

/// Tema visual centralizado para manter as telas consistentes durante a evolução.
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: blue,
    primary: blue,
    surface: Colors.white,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: ink,
      letterSpacing: -1.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: ink,
      letterSpacing: -.7,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: ink),
    bodySmall: TextStyle(fontSize: 12, height: 1.5, color: muted),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFFAFBFD),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E6EF)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E6EF)),
    ),
    labelStyle: const TextStyle(color: muted, fontSize: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      side: const BorderSide(color: Color(0xFFDFE5EE)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFFE9EDF3)),
);

/// Cartão padrão usado para agrupar conteúdo com o mesmo espaçamento e borda.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5EAF2)),
    ),
    child: child,
  );
}

/// Assinatura visual do LevaAí, reutilizada em cabeçalhos e telas de acesso.
class Brand extends StatelessWidget {
  final bool light;
  const Brand({super.key, this.light = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: light ? Colors.white24 : blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.local_shipping_rounded,
          color: Colors.white,
          size: 25,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'LevaAí',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: light ? Colors.white : ink,
        ),
      ),
    ],
  );
}

/// Etiqueta que transforma o status técnico da reserva em um texto visível.
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final done = ['concluido', 'avaliado', 'agendado'].contains(status);
    final negative =
        status.contains('cancelado') || status.contains('recusado');
    final color =
        negative
            ? const Color(0xFFAE4555)
            : done
            ? const Color(0xFF15856B)
            : blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusNames[status] ?? status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Caixa de mensagem reutilizável para avisos, erros e orientações ao usuário.
class Notice extends StatelessWidget {
  final String message;
  final bool error;
  const Notice(this.message, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFEFF0) : const Color(0xFFEDF3FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline : Icons.info_outline,
          size: 19,
          color: error ? Colors.red.shade700 : blue,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: error ? Colors.red.shade800 : ink,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Campo de endereço com busca remota e retorno do ponto geocodificado escolhido.
class AddressField extends StatefulWidget {
  final Api api;
  final String label;
  final Json? value;
  final ValueChanged<Json?> onChanged;
  const AddressField({
    super.key,
    required this.api,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
  late final TextEditingController controller;
  List<dynamic> results = [];
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value?['label'] ?? '');
  }

  @override
  void didUpdateWidget(covariant AddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null && widget.value != oldWidget.value) {
      controller.text = widget.value!['label'];
      results = [];
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> search() async {
    if (loading) return;
    if (controller.text.trim().length < 4) {
      setState(() => error = 'Digite rua, número e cidade.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
      results = [];
    });
    try {
      final found =
          await widget.api.call(
                '/maps/search?q=${Uri.encodeQueryComponent(controller.text)}',
              )
              as List;
      if (mounted) {
        setState(() {
          results = found;
          if (found.isEmpty) {
            error = 'Endereço não encontrado. Inclua a cidade e o estado.';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: controller,
        onChanged: (_) {
          widget.onChanged(null);
          setState(() => results = []);
        },
        onSubmitted: (_) => search(),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: 'Rua, número, cidade e estado',
          prefixIcon: Icon(
            widget.value == null
                ? Icons.location_on_outlined
                : Icons.check_circle_outline,
            color: widget.value == null ? muted : Colors.teal,
          ),
          suffixIcon:
              loading
                  ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                  : IconButton(
                    tooltip: 'Buscar endereço',
                    onPressed: search,
                    icon: const Icon(Icons.search),
                  ),
        ),
      ),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
        ),
      if (results.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDE5F2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children:
                results
                    .map(
                      (r) => ListTile(
                        leading: const Icon(Icons.place_outlined, size: 19),
                        title: Text(
                          r['label'],
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          widget.onChanged(Map<String, dynamic>.from(r));
                          setState(() {
                            controller.text = r['label'];
                            results = [];
                          });
                        },
                      ),
                    )
                    .toList(),
          ),
        ),
    ],
  );
}

Widget sectionTitle(BuildContext context, String title, String subtitle) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: muted)),
        ],
      ),
    );
