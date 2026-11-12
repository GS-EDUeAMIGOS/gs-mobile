import 'package:flutter/material.dart';
import '../models/ocorrencia_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/occurrence_card.dart';

/// Camada: Screens (Tela 3 — Listagem e Filtro de Ocorrências Cidadãs)
/// Responsabilidade Única: Exibir todas as ocorrências paginadas do endpoint `GET /api/ocorrencias`
/// e permitir filtrar dinamicamente por termo, tipo de ocorrência e impacto na acessibilidade PcD
/// (consumindo a `OcorrenciaSpecification` que você implementou no Java).
class OccurrencesScreen extends StatefulWidget {
  const OccurrencesScreen({super.key});

  @override
  State<OccurrencesScreen> createState() => _OccurrencesScreenState();
}

class _OccurrencesScreenState extends State<OccurrencesScreen> {
  final _termoController = TextEditingController();
  TipoOcorrencia? _tipoSelecionado;
  bool _somenteAcessibilidade = false;

  List<OcorrenciaModel> _ocorrencias = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _buscarOcorrencias();
  }

  @override
  void dispose() {
    _termoController.dispose();
    super.dispose();
  }

  Future<void> _buscarOcorrencias() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lista = await ApiService.instance.listarOcorrencias(
        tipo: _tipoSelecionado,
        afetaAcessibilidade: _somenteAcessibilidade ? true : null,
        termo: _termoController.text,
      );
      if (!mounted) return;
      setState(() {
        _ocorrencias = lista;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _limparFiltros() {
    setState(() {
      _termoController.clear();
      _tipoSelecionado = null;
      _somenteAcessibilidade = false;
    });
    _buscarOcorrencias();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ocorrências Cidadãs'),
        actions: [
          IconButton(
            tooltip: 'Recarregar lista',
            icon: const Icon(Icons.refresh),
            onPressed: _buscarOcorrencias,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Filtros Dinâmicos (conectada à Specification do Spring Data JPA)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _termoController,
                        onSubmitted: (_) => _buscarOcorrencias(),
                        decoration: InputDecoration(
                          hintText: 'Buscar por título ou descrição...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _termoController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _termoController.clear();
                                    _buscarOcorrencias();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _buscarOcorrencias,
                      child: const Text('Filtrar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Chips de filtro rápido por Acessibilidade e Tipo
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        avatar: const Icon(Icons.accessible, size: 16),
                        label: const Text('Somente Impacto PcD'),
                        selected: _somenteAcessibilidade,
                        selectedColor: AppTheme.secondaryTeal.withValues(alpha: 0.2),
                        onSelected: (val) {
                          setState(() => _somenteAcessibilidade = val);
                          _buscarOcorrencias();
                        },
                      ),
                      const SizedBox(width: 8),
                      ...TipoOcorrencia.values.map((tipo) {
                        final isSelected = _tipoSelecionado == tipo;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(tipo.label),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _tipoSelecionado = selected ? tipo : null;
                              });
                              _buscarOcorrencias();
                            },
                          ),
                        );
                      }),
                      if (_tipoSelecionado != null ||
                          _somenteAcessibilidade ||
                          _termoController.text.isNotEmpty)
                        TextButton.icon(
                          onPressed: _limparFiltros,
                          icon: const Icon(Icons.filter_alt_off, size: 16),
                          label: const Text('Limpar'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de Resultados
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppTheme.dangerRed),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.dangerRed),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _buscarOcorrencias,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _ocorrencias.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Nenhuma ocorrência encontrada para os filtros selecionados.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _buscarOcorrencias,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _ocorrencias.length,
                              itemBuilder: (context, index) {
                                final item = _ocorrencias[index];
                                return OccurrenceCard(
                                  ocorrencia: item,
                                  onTap: () async {
                                    // Passagem de parâmetro na navegação para a Tela 4 (Detalhes)
                                    await Navigator.pushNamed(
                                      context,
                                      '/occurrence-detail',
                                      arguments: item,
                                    );
                                    _buscarOcorrencias();
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/occurrence-form');
          _buscarOcorrencias();
        },
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Ocorrência'),
      ),
    );
  }
}
