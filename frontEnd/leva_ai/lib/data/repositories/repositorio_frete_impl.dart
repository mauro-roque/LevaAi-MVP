import '../../domain/entities/transportador_entidade.dart'; import '../../domain/repositories/repositorio_frete.dart'; import '../datasources/fonte_remota_frete.dart';
class RepositorioFreteImpl implements RepositorioFrete { const RepositorioFreteImpl(this.fonte); final FonteRemotaFrete fonte; @override Future<List<TransportadorEntidade>> listarTransportadores() => fonte.obterTransportadores(); }
