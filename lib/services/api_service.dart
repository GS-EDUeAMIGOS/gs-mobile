import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/auth_model.dart';
import '../models/ocorrencia_model.dart';
import '../models/olho_vivo_model.dart';

/// Camada: Services (Comunicação HTTP / Integração com Backend Java)
/// Responsabilidade Única: Isolar toda a lógica de rede, URLs, cabeçalhos HTTP,
/// tratamento de erros e gerenciamento do Token JWT da interface gráfica (Telas).
class ApiService {
  // Singleton simples para manter a sessão do usuário logado acessível em todas as telas
  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _currentUser!.token.isNotEmpty;

  /// Detecta automaticamente o endereço da API Java:
  /// - No Navegador (Web) ou Windows Desktop: usa localhost:8080
  /// - No Emulador Android: usa 10.0.2.2:8080 (que aponta para o localhost da máquina hospedeira)
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api';
    }
    return 'http://localhost:8080/api';
  }

  /// Monta os cabeçalhos HTTP padrão em UTF-8 e injeta o Token JWT ("Bearer ...") se estiver logado
  Map<String, String> _headers({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };
    if (includeAuth && _currentUser != null && _currentUser!.token.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${_currentUser!.token}';
    }
    return headers;
  }

  void logout() {
    _currentUser = null;
  }

  // ===========================================================================
  // 1. AUTENTICAÇÃO (/api/auth)
  // ===========================================================================

  Future<AuthUser> login(String email, String senha) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      uri,
      headers: _headers(includeAuth: false),
      body: jsonEncode({'email': email.trim(), 'senha': senha}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      _currentUser = AuthUser.fromJson(data);
      return _currentUser!;
    } else {
      throw Exception(_extractErrorMessage(response, 'Credenciais inválidas ou erro no servidor.'));
    }
  }

  Future<AuthUser> registrar({
    required String nome,
    required String email,
    required String senha,
    required bool possuiMobilidadeReduzida,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final response = await http.post(
      uri,
      headers: _headers(includeAuth: false),
      body: jsonEncode({
        'nome': nome.trim(),
        'email': email.trim(),
        'senha': senha,
        'possuiMobilidadeReduzida': possuiMobilidadeReduzida,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      _currentUser = AuthUser.fromJson(data);
      return _currentUser!;
    } else {
      throw Exception(_extractErrorMessage(response, 'Não foi possível concluir o cadastro.'));
    }
  }

  // ===========================================================================
  // 2. OCORRÊNCIAS CIDADÃS (/api/ocorrencias)
  // ===========================================================================

  Future<List<OcorrenciaModel>> listarOcorrencias({
    TipoOcorrencia? tipo,
    bool? afetaAcessibilidade,
    String? termo,
  }) async {
    final queryParams = <String, String>{
      'size': '50',
      'sort': 'criadoEm,desc',
    };
    if (tipo != null) queryParams['tipo'] = tipo.name;
    if (afetaAcessibilidade != null) {
      queryParams['afetaAcessibilidade'] = afetaAcessibilidade.toString();
    }
    if (termo != null && termo.trim().isNotEmpty) {
      queryParams['termo'] = termo.trim();
    }

    final uri = Uri.parse('$baseUrl/ocorrencias').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      // O endpoint /api/ocorrencias retorna um Page<OcorrenciaDTO.Response> do Spring Data,
      // onde a lista de itens fica dentro da propriedade "content".
      final content = decoded['content'] as List<dynamic>? ?? [];
      return content
          .map((item) => OcorrenciaModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(_extractErrorMessage(response, 'Erro ao carregar ocorrências.'));
    }
  }

  Future<List<OcorrenciaModel>> listarCriticasAcessibilidade() async {
    final uri = Uri.parse('$baseUrl/ocorrencias/acessibilidade-criticas');
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode == 200) {
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return list
          .map((item) => OcorrenciaModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(_extractErrorMessage(response, 'Erro ao buscar alertas críticos de acessibilidade.'));
    }
  }

  Future<OcorrenciaModel> criarOcorrencia(OcorrenciaModel ocorrencia) async {
    final uri = Uri.parse('$baseUrl/ocorrencias');
    final response = await http.post(
      uri,
      headers: _headers(includeAuth: true),
      body: jsonEncode(ocorrencia.toJson()),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return OcorrenciaModel.fromJson(data);
    } else {
      throw Exception(_extractErrorMessage(
        response,
        'Falha ao registrar ocorrência (verifique se você está autenticado).',
      ));
    }
  }

  Future<void> removerOcorrencia(int id) async {
    final uri = Uri.parse('$baseUrl/ocorrencias/$id');
    final response = await http.delete(uri, headers: _headers(includeAuth: true));

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, 'Não foi possível excluir a ocorrência.'));
    }
  }

  // ===========================================================================
  // 3. SPTRANS OLHO VIVO (/api/linhas)
  // ===========================================================================

  Future<List<LinhaResumoModel>> buscarLinhas(String termo) async {
    final uri = Uri.parse('$baseUrl/linhas').replace(
      queryParameters: {'termo': termo.trim().isEmpty ? '8000' : termo.trim()},
    );
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode == 200) {
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return list
          .map((item) => LinhaResumoModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(_extractErrorMessage(response, 'Erro ao consultar linhas da SPTrans.'));
    }
  }

  Future<PosicaoLinhaResponseModel> buscarVeiculosPorLinha(int codigoLinha) async {
    final uri = Uri.parse('$baseUrl/linhas/$codigoLinha/veiculos');
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return PosicaoLinhaResponseModel.fromJson(data);
    } else {
      throw Exception(_extractErrorMessage(response, 'Erro ao buscar veículos em tempo real.'));
    }
  }

  Future<List<ParadaResumoModel>> buscarParadasPorLinha(
    int codigoLinha, {
    String? termo,
  }) async {
    final queryParams = <String, String>{};
    if (termo != null && termo.trim().isNotEmpty) {
      queryParams['termo'] = termo.trim();
    }
    final uri = Uri.parse('$baseUrl/linhas/$codigoLinha/paradas').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode == 200) {
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return list
          .map((item) => ParadaResumoModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(_extractErrorMessage(response, 'Erro ao consultar paradas da linha.'));
    }
  }

  Future<List<ParadaResumoModel>> buscarParadas(String termo) async {
    final uri = Uri.parse('$baseUrl/paradas').replace(
      queryParameters: {'termo': termo.trim().isEmpty ? 'PAULISTA' : termo.trim()},
    );
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode == 200) {
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return list
          .map((item) => ParadaResumoModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(_extractErrorMessage(response, 'Erro ao consultar paradas de ônibus da SPTrans.'));
    }
  }

  Future<PrevisaoParadaResponseModel> buscarPrevisoesPorParada(int codigoParada) async {
    final uri = Uri.parse('$baseUrl/paradas/$codigoParada/previsoes');
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return PrevisaoParadaResponseModel.fromJson(data);
    } else {
      throw Exception(_extractErrorMessage(response, 'Erro ao consultar previsão de chegada na parada.'));
    }
  }

  Future<ParadasProximasGpsResponseModel> buscarParadasProximasPorGps({
    required double lat,
    required double lon,
    String? termo,
  }) async {
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lon': lon.toString(),
    };
    if (termo != null && termo.trim().isNotEmpty) {
      queryParams['termo'] = termo.trim();
    }
    final uri = Uri.parse('$baseUrl/paradas/proximas').replace(
      queryParameters: queryParams,
    );
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return ParadasProximasGpsResponseModel.fromJson(data);
    } else {
      throw Exception(_extractErrorMessage(response, 'Erro ao localizar paradas próximas pelo GPS.'));
    }
  }

  Future<List<LocalResolvidoModel>> buscarLocais(String query) async {
    final uri = Uri.parse('$baseUrl/locais/buscar').replace(
      queryParameters: {'q': query.trim()},
    );
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode == 200) {
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return list
          .map((item) => LocalResolvidoModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(_extractErrorMessage(response, 'Erro ao buscar local de destino.'));
    }
  }

  Future<RotaPlanejadaResponseModel> planejarRota({
    required String origem,
    required String destino,
    double? latOrigem,
    double? lonOrigem,
  }) async {
    final queryParams = <String, String>{
      'origem': origem.trim().isEmpty ? 'LAPA' : origem.trim(),
      'destino': destino.trim().isEmpty ? 'PAULISTA' : destino.trim(),
    };
    if (latOrigem != null && lonOrigem != null) {
      queryParams['latOrigem'] = latOrigem.toString();
      queryParams['lonOrigem'] = lonOrigem.toString();
    }
    final uri = Uri.parse('$baseUrl/rotas/planejar').replace(
      queryParameters: queryParams,
    );
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return RotaPlanejadaResponseModel.fromJson(data);
    } else {
      throw Exception(_extractErrorMessage(response, 'Erro ao calcular rota inteligente na SPTrans.'));
    }
  }

  String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        if (body['message'] != null) return body['message'].toString();
        if (body['erro'] != null) return body['erro'].toString();
        if (body['error'] != null) return body['error'].toString();
      }
    } catch (_) {
      // Ignora erro de parse caso a resposta não seja JSON
    }
    return '$fallback (HTTP ${response.statusCode})';
  }
}
