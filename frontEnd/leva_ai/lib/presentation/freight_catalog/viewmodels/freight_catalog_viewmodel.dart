import 'package:flutter/foundation.dart';
import '../../../domain/entities/freighter_entity.dart';
import '../../../domain/usecases/get_freighters_usecase.dart';

class FreightCatalogViewModel extends ChangeNotifier {
  final GetFreightersUseCase getFreightersUseCase;

  FreightCatalogViewModel(this.getFreightersUseCase);

  List<FreighterEntity> _freighters = [];
  List<FreighterEntity> get freighters => _freighters;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadFreighters() async {
    _isLoading = true;
    notifyListeners();
    try {
      _freighters = await getFreightersUseCase();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
