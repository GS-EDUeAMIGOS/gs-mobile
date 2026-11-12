import 'package:flutter/material.dart';
import '../models/ocorrencia_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Camada: Screens (Tela 5 — Formulário de Nova Ocorrência Cidadã)
/// Responsabilidade Única: Capturar e validar os dados de um relato do cidadão usando
/// `Form` + `GlobalKey<FormState>` e enviar via `POST /api/ocorrencias` (protegido por JWT)
/// para a API Java Spring Boot.
class OccurrenceFormScreen extends StatefulWidget {
  const OccurrenceFormScreen({super.key});

  @override
  State<OccurrenceFormScreen> createState() => _OccurrenceFormScreenState();
}

class _OccurrenceFormScreenState extends State<OccurrenceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _codigoLinhaController = TextEditingController(text: '2506');
  final _codigoParadaController = TextEditingController(text: '340015329');
  final _prefixoVeiculoController = TextEditingController();

  TipoOcorrencia _tipo = TipoOcorrencia.ELEVADOR_INOPERANTE;
  NivelGravidade _gravidade = NivelGravidade.ALTA;
  bool _afetaAcessibilidade = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _codigoLinhaController.dispose();
    _codigoParadaController.dispose();
    _prefixoVeiculoController.dispose();
    super.dispose();
  }

  Future<void> _salvarOcorrencia() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ApiService.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça login primeiro para registrar uma ocorrência com Token JWT.'),
          backgroundColor: AppTheme.accentAmber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final novaOcorrencia = OcorrenciaModel(
        usuarioId: user.usuarioId,
        titulo: _tituloController.text.trim(),
        descricao: _descricaoController.text.trim(),
        tipo: _tipo,
        gravidade: _gravidade,
        status: StatusOcorrencia.ABERTA,
        codigoLinha: int.tryParse(_codigoLinhaController.text.trim()),
        codigoParada: int.tryParse(_codigoParadaController.text.trim()),
        prefixoVeiculo: _prefixoVeiculoController.text.trim(),
        afetaAcessibilidade: _afetaAcessibilidade,
      );

      await ApiService.instance.criarOcorrencia(novaOcorrencia);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocorrência registrada com sucesso no banco de dados!'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ApiService.instance.isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Nova Ocorrência'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isAuthenticated)
                  Card(
                    color: const Color(0xFFFFFBEB),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, color: AppTheme.accentAmber),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'O endpoint POST /api/ocorrencias exige autenticação JWT no Spring Security.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                            child: const Text('Fazer Login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Relato de Mobilidade e Acessibilidade',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Suas informações ajudam outros cidadãos e pessoas com deficiência (PcD) em tempo real.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 20),

                          // Campo: Título (Validação alinhada ao @Size(min=3, max=120) do Java)
                          TextFormField(
                            controller: _tituloController,
                            decoration: const InputDecoration(
                              labelText: 'Título da Ocorrência *',
                              hintText: 'Ex.: Elevador PcD travado no ônibus 12540',
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().length < 3) {
                                return 'O título deve ter pelo menos 3 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Seletor: Tipo da Ocorrência (Enum TipoOcorrencia do Java)
                          DropdownButtonFormField<TipoOcorrencia>(
                            initialValue: _tipo,
                            decoration: const InputDecoration(
                              labelText: 'Categoria do Problema *',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: TipoOcorrencia.values
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t.label),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _tipo = val;
                                  if (val == TipoOcorrencia.ELEVADOR_INOPERANTE ||
                                      val == TipoOcorrencia.ACESSIBILIDADE) {
                                    _afetaAcessibilidade = true;
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Seletor: Nível de Gravidade (Enum NivelGravidade do Java)
                          DropdownButtonFormField<NivelGravidade>(
                            initialValue: _gravidade,
                            decoration: const InputDecoration(
                              labelText: 'Nível de Gravidade *',
                              prefixIcon: Icon(Icons.warning_amber_rounded),
                            ),
                            items: NivelGravidade.values
                                .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g.label),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _gravidade = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Campo: Descrição detalhada (Validação alinhada ao @Size(min=5, max=1000) do Java)
                          TextFormField(
                            controller: _descricaoController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Descrição Detalhada *',
                              hintText: 'Descreva o que aconteceu na parada ou no veículo...',
                              alignLabelWithHint: true,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().length < 5) {
                                return 'A descrição deve ter no mínimo 5 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Campos opcionais de identificação SPTrans
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _codigoLinhaController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Cód. Linha (SPTrans)',
                                    hintText: 'Ex.: 2506',
                                    prefixIcon: Icon(Icons.directions_bus_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _prefixoVeiculoController,
                                  decoration: const InputDecoration(
                                    labelText: 'Prefixo do Veículo',
                                    hintText: 'Ex.: 12540',
                                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _codigoParadaController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Código da Parada SPTrans (opcional)',
                              hintText: 'Ex.: 340015329 (Parada Paulista)',
                              prefixIcon: Icon(Icons.place_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Afeta diretamente a Acessibilidade (PcD)?',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: const Text(
                              'Destaca esta ocorrência no painel de alertas críticos de acessibilidade',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _afetaAcessibilidade,
                            activeThumbColor: AppTheme.secondaryTeal,
                            onChanged: (val) => setState(() => _afetaAcessibilidade = val),
                          ),
                          const SizedBox(height: 20),

                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : _salvarOcorrencia,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                            label: Text(_isSaving ? 'Enviando para API Java...' : 'Publicar Ocorrência'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
