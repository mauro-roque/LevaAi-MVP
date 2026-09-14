import '../entities/freighter_entity.dart';
import '../repositories/i_freight_repository.dart';

class GetFreightersUseCase {
  final IFreightRepository repository;

  GetFreightersUseCase(this.repository);

  Future<List<FreighterEntity>> call() async {
    return await repository.getFreighters();
  }
}
