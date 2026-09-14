import '../entities/transportador_entidade.dart'; import '../repositories/repositorio_frete.dart';
class ObterTransportadoresCasoDeUso { const ObterTransportadoresCasoDeUso(this.repositorio); final RepositorioFrete repositorio; Future<List<TransportadorEntidade>> call() => repositorio.listarTransportadores(); }
