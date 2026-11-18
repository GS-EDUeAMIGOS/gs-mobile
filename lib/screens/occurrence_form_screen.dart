import 'package:flutter/material.dart';

import '../models/ocorrencia_model.dart';
import '../models/olho_vivo_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/theme_selector_button.dart';

/// Camada: Screens (Formulário de Nova Ocorrência Cidadã).
/// Responsabilidade única: capturar, validar e enviar o relato para a API.
class OccurrenceFormScreen extends StatefulWidget {
  const OccurrenceFormScreen({super.key});

  @override
  State<OccurrenceFormScreen> createState() => _OccurrenceFormScreenState();
}

class _OccurrenceFormScreenState extends State<OccurrenceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _linhaInformadaController = TextEditingController();
  final _codigoLinhaController = TextEditingController();
  final _codigoParadaController = TextEditingController();
  final _prefixoVeiculoController = TextEditingController();

  TipoOcorrencia _tipo = TipoOcorrencia.ELEVADOR_INOPERANTE;
  NivelGravidade _gravidade = NivelGravidade.ALTA;
  bool _afetaAcessibilidade = true;
  bool _isSaving = false;
  bool _initializedArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedArgs) return;
    _initializedArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) return;

    if (args['codigoLinha'] != null) {
      _codigoLinhaController.text = args['codigoLinha'].toString();
    }
    if (args['codigoParada'] != null) {
      _codigoParadaController.text = args['codigoParada'].toString();
    }
    if (args['prefixoVeiculo'] != null) {
      _prefixoVeiculoController.text = args['prefixoVeiculo'].toString();
    }
    if (args['letreiro'] != null) {
      _linhaInformadaController.text = args['letreiro'].toString();
      final prefixo = args['prefixoVeiculo']?.toString().trim();
      _tituloController.text = prefixo != null && prefixo.isNotEmpty
          ? 'Problema no ônibus $prefixo (Linha ${_linhaInformadaController.text})'
          : 'Problema na linha ${_linhaInformadaController.text}';
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _linhaInformadaController.dispose();
    _codigoLinhaController.dispose();
    _codigoParadaController.dispose();
    _prefixoVeiculoController.dispose();
    super.dispose();
  }

  String _montarDescricaoComLinha(String descricao) {
    final linha = _linhaInformadaController.text.trim();
    return linha.isEmpty ? descricao : '[Linha: $linha]\n$descricao';
  }

  String _nomeLinhaSptrans(LinhaResumoModel linha) {
    final terminais = [
      linha.terminalPrincipal,
      linha.terminalSecundario,
    ].where((nome) => nome.trim().isNotEmpty).join(' ↔ ');
    return terminais.isEmpty
        ? linha.letreiroCompleto
        : '${linha.letreiroCompleto} • $terminais';
  }

  Future<void> _abrirBuscaLinha() async {
    final linha = await showModalBottomSheet<LinhaResumoModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _LineSearchSheet(initialQuery: _linhaInformadaController.text.trim()),
    );

    if (linha == null || !mounted) return;
    setState(() {
      _linhaInformadaController.text = _nomeLinhaSptrans(linha);
      _codigoLinhaController.text = linha.codigoLinha.toString();
    });
  }

  Future<void> _salvarOcorrencia() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ApiService.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça login primeiro para registrar uma ocorrência.'),
          backgroundColor: AppTheme.accentAmber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefixo = _prefixoVeiculoController.text.trim();
      final novaOcorrencia = OcorrenciaModel(
        usuarioId: user.usuarioId,
        titulo: _tituloController.text.trim(),
        descricao: _montarDescricaoComLinha(_descricaoController.text.trim()),
        tipo: _tipo,
        gravidade: _gravidade,
        status: StatusOcorrencia.ABERTA,
        codigoLinha: int.tryParse(_codigoLinhaController.text.trim()),
        codigoParada: int.tryParse(_codigoParadaController.text.trim()),
        prefixoVeiculo: prefixo.isEmpty ? null : prefixo,
        afetaAcessibilidade: _afetaAcessibilidade,
      );

      await ApiService.instance.criarOcorrencia(novaOcorrencia);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocorrência registrada com sucesso.'),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ApiService.instance.isAuthenticated;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Nova Ocorrência'),
        actions: const [ThemeSelectorButton()],
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
                    color: colors.tertiaryContainer,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: colors.onTertiaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Entre na sua conta para publicar uma ocorrência.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.onTertiaryContainer,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              '/login',
                            ),
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
                          Text(
                            'Relato de Mobilidade e Acessibilidade',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Compartilhe detalhes para ajudar outras pessoas a se deslocarem com mais segurança.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _FormSectionHeading(
                            title: 'Sobre o problema',
                            icon: Icons.report_outlined,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _tituloController,
                            decoration: const InputDecoration(
                              labelText: 'Título da Ocorrência *',
                              hintText:
                                  'Ex.: Elevador PcD travado no ônibus 12540',
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (val) {
                              final texto = val?.trim() ?? '';
                              if (texto.length < 3) {
                                return 'O título deve ter pelo menos 3 caracteres';
                              }
                              if (texto.length > 120) {
                                return 'O título deve ter no máximo 120 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<TipoOcorrencia>(
                            initialValue: _tipo,
                            decoration: const InputDecoration(
                              labelText: 'Categoria do Problema *',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: TipoOcorrencia.values
                                .map(
                                  (tipo) => DropdownMenuItem(
                                    value: tipo,
                                    child: Text(tipo.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                _tipo = val;
                                if (val == TipoOcorrencia.ELEVADOR_INOPERANTE ||
                                    val == TipoOcorrencia.ACESSIBILIDADE) {
                                  _afetaAcessibilidade = true;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<NivelGravidade>(
                            initialValue: _gravidade,
                            decoration: const InputDecoration(
                              labelText: 'Nível de Gravidade *',
                              prefixIcon: Icon(Icons.warning_amber_rounded),
                            ),
                            items: NivelGravidade.values
                                .map(
                                  (gravidade) => DropdownMenuItem(
                                    value: gravidade,
                                    child: Text(gravidade.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _gravidade = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descricaoController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Descrição Detalhada *',
                              hintText:
                                  'Descreva o que aconteceu na parada ou no veículo...',
                              alignLabelWithHint: true,
                            ),
                            validator: (val) {
                              final texto = val?.trim() ?? '';
                              if (texto.length < 5) {
                                return 'A descrição deve ter no mínimo 5 caracteres';
                              }
                              if (_montarDescricaoComLinha(texto).length >
                                  1000) {
                                return 'Descrição e linha devem somar no máximo 1000 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          const _FormSectionHeading(
                            title: 'Localização e acessibilidade',
                            icon: Icons.place_outlined,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(
                                alpha: 0.38,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.primary,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.route, color: colors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Qual é a Linha do Ônibus?',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Recomendado para destacar o alerta. Digite o número ou nome livremente.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _linhaInformadaController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Número ou nome da linha (recomendado)',
                                    hintText:
                                        'Ex.: Vila Liviero, 5031-10 ou Terminal Lapa',
                                    prefixIcon: Icon(
                                      Icons.directions_bus_filled_outlined,
                                    ),
                                  ),
                                  onChanged: (_) {
                                    if (_codigoLinhaController.text.isEmpty) {
                                      return;
                                    }
                                    setState(
                                      () => _codigoLinhaController.clear(),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _abrirBuscaLinha,
                                  icon: const Icon(Icons.search),
                                  label: const Text(
                                    'Buscar e selecionar na SPTrans',
                                  ),
                                ),
                                if (_codigoLinhaController.text.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Linha oficial vinculada • código ${_codigoLinhaController.text}',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _prefixoVeiculoController,
                            decoration: const InputDecoration(
                              labelText:
                                  'Prefixo / Número do Ônibus (opcional)',
                              hintText:
                                  'Ex.: 51215 (número pintado na porta ou lateral)',
                              prefixIcon: Icon(
                                Icons.confirmation_number_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _codigoParadaController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Código da Parada SPTrans (opcional)',
                              hintText:
                                  'Informe somente se souber o código oficial',
                              prefixIcon: Icon(Icons.place_outlined),
                            ),
                            validator: (val) {
                              final texto = val?.trim() ?? '';
                              if (texto.isNotEmpty &&
                                  int.tryParse(texto) == null) {
                                return 'Digite apenas os números do código da parada';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Afeta diretamente a Acessibilidade (PcD)?',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Sinaliza prioridade PcD; todo relato aberto também aparece nos alertas da Home.',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _afetaAcessibilidade,
                            activeThumbColor: colors.secondary,
                            onChanged: (val) =>
                                setState(() => _afetaAcessibilidade = val),
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
                            label: Text(
                              _isSaving
                                  ? 'Enviando ocorrência...'
                                  : 'Publicar Ocorrência',
                            ),
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

/// Widget com estado isolado para a pesquisa na SPTrans. Assim, o formulário
/// principal continua responsável apenas pelo relato e pela seleção final.
class _LineSearchSheet extends StatefulWidget {
  final String initialQuery;

  const _LineSearchSheet({required this.initialQuery});

  @override
  State<_LineSearchSheet> createState() => _LineSearchSheetState();
}

class _LineSearchSheetState extends State<_LineSearchSheet> {
  late final TextEditingController _searchController;
  List<LinhaResumoModel> _linhas = const [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final termo = _searchController.text.trim();
    if (termo.isEmpty) {
      setState(
        () => _errorMessage = 'Digite o número, terminal ou nome da linha.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final linhas = await ApiService.instance.buscarLinhas(termo);
      if (!mounted) return;
      setState(() {
        _linhas = linhas;
        _isLoading = false;
        if (linhas.isEmpty) {
          _errorMessage =
              'Nenhuma linha encontrada. Você ainda pode digitar livremente.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Selecionar linha da SPTrans',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'A seleção vincula o código oficial usado pelo mapa.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: widget.initialQuery.isEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  labelText: 'Número, terminal ou nome',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Buscar',
                    onPressed: _isLoading ? null : _buscar,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading) const LinearProgressIndicator(),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  itemCount: _linhas.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final linha = _linhas[index];
                    return ListTile(
                      leading: const Icon(Icons.directions_bus_outlined),
                      title: Text(
                        linha.letreiroCompleto,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(linha.descricaoSentido),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, linha),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSectionHeading extends StatelessWidget {
  final String title;
  final IconData icon;

  const _FormSectionHeading({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
