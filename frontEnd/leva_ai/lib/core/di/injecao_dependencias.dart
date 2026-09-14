import 'package:flutter/material.dart';
import 'package:leva_ai/core/routes/rotas_app.dart';
import 'package:leva_ai/data/datasources/fonte_remota_frete.dart';
import 'package:leva_ai/data/repositories/repositorio_frete_impl.dart';
import 'package:leva_ai/domain/entities/transportador_entidade.dart';
import 'package:leva_ai/domain/usecases/obter_transportadores_caso_de_uso.dart';
import 'package:leva_ai/presentation/freight_catalog/viewmodels/catalogo_fretes_viewmodel.dart';
import 'package:leva_ai/presentation/freight_catalog/views/catalogo_fretes_pagina.dart';
import 'package:leva_ai/presentation/freight_details/views/detalhes_frete_pagina.dart';


abstract final class InjecaoDependencias {
  static final _obter = ObterTransportadoresCasoDeUso(
    RepositorioFreteImpl(FonteRemotaFreteMock()),
  );
  static Route<dynamic> gerarRota(RouteSettings ajustes) {
    switch (ajustes.name) {
      case RotasApp.inicio:
      case RotasApp.catalogo:
        return MaterialPageRoute(
          builder: (_) =>
              CatalogoFretesPagina(viewModel: CatalogoFretesViewModel(_obter)),
        );
      case RotasApp.detalhes:
        return MaterialPageRoute(
          builder: (_) => DetalhesFretePagina(
            transportador: ajustes.arguments! as TransportadorEntidade,
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Página não encontrada')),
          ),
        );
    }
  }
}
