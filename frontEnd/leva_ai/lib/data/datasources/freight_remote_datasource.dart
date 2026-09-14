import '../models/freighter_model.dart';

abstract class IFreightRemoteDataSource {
  Future<List<FreighterModel>> fetchFreighters();
}
