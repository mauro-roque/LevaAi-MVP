import '../../domain/entities/freighter_entity.dart';
import '../../domain/repositories/i_freight_repository.dart';
import '../datasources/freight_remote_datasource.dart';

class FreightRepositoryImpl implements IFreightRepository {
  final IFreightRemoteDataSource remoteDataSource;

  FreightRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<FreighterEntity>> getFreighters() async {
    return await remoteDataSource.fetchFreighters();
  }
}
