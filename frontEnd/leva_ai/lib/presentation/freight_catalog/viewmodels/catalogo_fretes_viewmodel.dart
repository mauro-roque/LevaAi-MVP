import 'package:flutter/foundation.dart';

import '../../../domain/usecases/obter_transportadores_caso_de_uso.dart';
import '../../../domain/entities/transportador_entidade.dart';

class CatalogoFretesViewModel extends ChangeNotifier {
  CatalogoFretesViewModel(this._obter);
  final ObterTransportadoresCasoDeUso _obter;
  List<TransportadorEntidade> transportadores = [];
  bool carregando = false;
  
  Future<void> carregar() async {
    carregando = true;
    notifyListeners();
    transportadores = await _obter();
    carregando = false;
    notifyListeners();
  }
}
