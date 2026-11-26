import 'package:flutter/material.dart';
import '../models/favorito_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';

/// Camada: Screens (Meus Favoritos — Paradas e Linhas Favoritas)
/// Responsabilidade Única: Apresentar as paradas e linhas favoritas do usuário
/// autenticado consumindo `/api/paradas-favoritas` e `/api/linhas-favoritas`.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TextEditingController _buscaLinhaController = TextEditingController();

  List<ParadaFavoritaModel> _paradas = [];
  List<LinhaFavoritaModel> _linhas = [];

  bool _isLoadingParadas = false;
  bool _isLoadingLinhas = false;
  bool _somenteAcessiveis = false;

  String? _erroParadas;
  String? _erroLinhas;

  @override
  void initState() {
    super.initState();
    if (ApiService.instance.isAuthenticated) {
      _carregarTudo();
    }
  }

  @override
  void dispose() {
    _buscaLinhaController.dispose();
    super.dispose();
  }

  Future<void> _carregarTudo() async {
    await Future.wait([
      _carregarParadas(),
      _carregarLinhas(),
    ]);
  }

  Future<void> _carregarParadas() async {
    final user = ApiService.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingParadas = true;
      _erroParadas = null;
    });

    try {
      final resultado = _somenteAcessiveis
          ? await ApiService.instance.listarParadasFavoritasAcessiveis(
              usuarioId: user.usuarioId,
            )
          : await ApiService.instance.listarParadasFavoritas(
              usuarioId: user.usuarioId,
            );
      if (!mounted) return;
      setState(() {
        _paradas = resultado;
        _isLoadingParadas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroParadas = e.toString().replaceFirst('Exception: ', '');
        _isLoadingParadas = false;
      });
    }
  }

  Future<void> _carregarLinhas() async {
    final user = ApiService.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingLinhas = true;
      _erroLinhas = null;
    });

    try {
      final termo = _buscaLinhaController.text.trim();
      final resultado = termo.isEmpty
          ? await ApiService.instance.listarLinhasFavoritas(
              usuarioId: user.usuarioId,
            )
          : await ApiService.instance.buscarLinhasFavoritasPorTermo(
              usuarioId: user.usuarioId,
              termo: termo,
            );
      if (!mounted) return;
      setState(() {
        _linhas = resultado;
        _isLoadingLinhas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroLinhas = e.toString().replaceFirst('Exception: ', '');
        _isLoadingLinhas = false;
      });
    }
  }

  Future<void> _removerParada(ParadaFavoritaModel parada) async {
    try {
      await ApiService.instance.removerParadaFavorita(parada.id);
      if (!mounted) return;
      setState(() {
        _paradas.removeWhere((p) => p.id == parada.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Parada "${parada.nomeParada}" removida dos favoritos.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _removerLinha(LinhaFavoritaModel linha) async {
    try {
      await ApiService.instance.removerLinhaFavorita(linha.id);
      if (!mounted) return;
      setState(() {
        _linhas.removeWhere((l) => l.id == linha.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Linha "${linha.letreiro}" removida dos favoritos.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ApiService.instance.isAuthenticated;

    if (!isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Meus Favoritos'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Faça login para ver seus favoritos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Suas paradas e linhas favoritas ficam vinculadas à sua conta de cidadão.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Ir para Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Meus Favoritos'),
          actions: [
            IconButton(
              tooltip: 'Atualizar favoritos',
              icon: const Icon(Icons.refresh),
              onPressed: _carregarTudo,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.place_outlined),
                text: 'Paradas Favoritas',
              ),
              Tab(
                icon: Icon(Icons.directions_bus_outlined),
                text: 'Linhas Favoritas',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildParadasTab(context),
            _buildLinhasTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildParadasTab(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _carregarParadas,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                selected: _somenteAcessiveis,
                avatar: Icon(
                  Icons.accessible,
                  size: 18,
                  color: _somenteAcessiveis ? colors.onSecondaryContainer : colors.primary,
                ),
                label: const Text('Somente Acessíveis (Rampa / Piso Tátil)'),
                onSelected: (value) {
                  setState(() {
                    _somenteAcessiveis = value;
                  });
                  _carregarParadas();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingParadas)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erroParadas != null)
            _buildErrorCard(
              context,
              titulo: 'Erro ao carregar paradas favoritas',
              mensagem: _erroParadas!,
              onRetry: _carregarParadas,
            )
          else if (_paradas.isEmpty)
            _buildEmptyCard(
              context,
              icon: Icons.place_outlined,
              titulo: _somenteAcessiveis
                  ? 'Nenhuma parada favorita acessível encontrada'
                  : 'Nenhuma parada favorita cadastrada',
              subtitulo: _somenteAcessiveis
                  ? 'Desmarque o filtro acima para visualizar todas as paradas salvas.'
                  : 'Quando houver paradas favoritadas na sua conta, elas aparecerão aqui.',
            )
          else
            ..._paradas.map(
              (parada) => _ParadaFavoritaCard(
                parada: parada,
                onRemover: () => _removerParada(parada),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLinhasTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _carregarLinhas,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _buscaLinhaController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _carregarLinhas(),
                  decoration: InputDecoration(
                    hintText: 'Buscar por letreiro, apelido ou terminal...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _buscaLinhaController.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Limpar busca',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _buscaLinhaController.clear();
                              _carregarLinhas();
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _carregarLinhas,
                child: const Text('Buscar'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingLinhas)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erroLinhas != null)
            _buildErrorCard(
              context,
              titulo: 'Erro ao carregar linhas favoritas',
              mensagem: _erroLinhas!,
              onRetry: _carregarLinhas,
            )
          else if (_linhas.isEmpty)
            _buildEmptyCard(
              context,
              icon: Icons.directions_bus_outlined,
              titulo: _buscaLinhaController.text.trim().isNotEmpty
                  ? 'Nenhuma linha favorita encontrada para essa busca'
                  : 'Nenhuma linha favorita cadastrada',
              subtitulo: _buscaLinhaController.text.trim().isNotEmpty
                  ? 'Tente outro termo ou limpe o campo de busca.'
                  : 'Quando houver linhas favoritadas na sua conta, elas aparecerão aqui.',
            )
          else
            ..._linhas.map(
              (linha) => _LinhaFavoritaCard(
                linha: linha,
                onRemover: () => _removerLinha(linha),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(
    BuildContext context, {
    required IconData icon,
    required String titulo,
    required String subtitulo,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 42, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    required VoidCallback onRetry,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: colors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              style: TextStyle(fontSize: 13, color: colors.onErrorContainer),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParadaFavoritaCard extends StatelessWidget {
  final ParadaFavoritaModel parada;
  final VoidCallback onRemover;

  const _ParadaFavoritaCard({
    required this.parada,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final successColor = AppTheme.adaptiveSuccess(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.place, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parada.nomeParada,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (parada.endereco != null &&
                          parada.endereco!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          parada.endereco!,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Código da Parada: ${parada.codigoParada}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remover dos favoritos',
                  icon: Icon(Icons.delete_outline, color: colors.error),
                  onPressed: onRemover,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _AcessibilidadeBadge(
                  icon: Icons.accessible,
                  label: parada.possuiRampaAcessivel
                      ? 'Rampa Acessível'
                      : 'Sem Rampa Informada',
                  ativo: parada.possuiRampaAcessivel,
                  activeColor: successColor,
                ),
                _AcessibilidadeBadge(
                  icon: Icons.texture,
                  label: parada.possuiPisoTatil
                      ? 'Piso Tátil'
                      : 'Sem Piso Tátil',
                  ativo: parada.possuiPisoTatil,
                  activeColor: successColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaFavoritaCard extends StatelessWidget {
  final LinhaFavoritaModel linha;
  final VoidCallback onRemover;

  const _LinhaFavoritaCard({
    required this.linha,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                linha.letreiro,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (linha.apelido != null && linha.apelido!.trim().isNotEmpty) ...[
                    Text(
                      linha.apelido!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    linha.descricaoTrajeto,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sentido ${linha.sentido} • Código SPTrans: ${linha.codigoLinha}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remover dos favoritos',
              icon: Icon(Icons.delete_outline, color: colors.error),
              onPressed: onRemover,
            ),
          ],
        ),
      ),
    );
  }
}

class _AcessibilidadeBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ativo;
  final Color activeColor;

  const _AcessibilidadeBadge({
    required this.icon,
    required this.label,
    required this.ativo,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = ativo ? activeColor : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
