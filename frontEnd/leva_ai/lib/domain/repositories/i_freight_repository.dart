import '../entities/freighter_entity.dart';

abstract class IFreightRepository {
  Future<List<FreighterEntity>> getFreighters();
}
