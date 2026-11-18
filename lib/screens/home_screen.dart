import 'package:flutter/material.dart';
import '../models/ocorrencia_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/occurrence_card.dart';
import '../widgets/theme_selector_button.dart';

/// Camada: Screens (Tela 2 — Painel Principal / Dashboard Cidadão)
/// Responsabilidade Única: Apresentar o resumo da sessão do usuário, atalhos de navegação
/// para os módulos do app e os Alertas Críticos de Acessibilidade vindos do endpoint
/// `/api/ocorrencias/acessibilidade-criticas` (que usa JPQL + `@Cacheable` no Java).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<OcorrenciaModel> _criticas = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _carregarPainel();
  }

  Future<void> _carregarPainel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lista = await ApiService.instance.listarCriticasAcessibilidade();
      if (!mounted) return;
      setState(() {
        _criticas = lista;
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

  @override
  Widget build(BuildContext context) {
    final user = ApiService.instance.currentUser;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ViaCidadã'),
        actions: [
          const ThemeSelectorButton(),
          IconButton(
            tooltip: 'Atualizar dados',
            icon: const Icon(Icons.refresh),
            onPressed: _carregarPainel,
          ),
          IconButton(
            tooltip: user != null ? 'Sair (${user.nome})' : 'Ir para Login',
            icon: Icon(user != null ? Icons.logout : Icons.login),
            onPressed: () {
              ApiService.instance.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregarPainel,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            // Banner de Boas-Vindas
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.secondaryTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user != null ? 'Olá, ${user.nome}' : 'Modo Visitante (Leitura)',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              user != null
                                  ? user.email
                                  : 'Faça login para registrar novas ocorrências',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Seção Estilo Moovit: "Para onde você quer ir?"
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pushNamed(context, '/route-planner'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: colors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Para onde você quer ir?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 14, color: colors.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            'Destinos rápidos: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          ...[
                            {'label': 'Av. Paulista', 'destino': 'PAULISTA'},
                            {'label': 'Pinheiros', 'destino': 'PINHEIROS'},
                            {'label': 'Centro / Ramos', 'destino': 'RAMOS'},
                            {'label': 'Ibirapuera', 'destino': 'IBIRAPUERA'},
                            {'label': 'Vila Mariana', 'destino': 'VILA MARIANA'},
                          ].map((d) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  avatar: Icon(Icons.place, size: 14, color: colors.primary),
                                  label: Text(
                                    d['label']!,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/route-planner',
                                      arguments: {
                                        'origem': 'LAPA',
                                        'destino': d['destino'],
                                      },
                                    );
                                  },
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Seção de Ações Rápidas (Navegação entre as 7 telas)
            Text(
              'Serviços de Mobilidade e Cidadania',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final isDark = AppTheme.isDarkMode(context);
                return GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 4 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: isWide ? 142 : 156,
                  ),
                  children: [
                    _QuickActionCard(
                      icon: Icons.route,
                      title: 'Como Chegar',
                      subtitle: 'Melhor ônibus e baldeação',
                      color: colors.primary,
                      onTap: () {
                        Navigator.pushNamed(context, '/route-planner');
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.radar,
                      title: 'Radar no Ponto',
                      subtitle: 'Previsão de chegada SPTrans',
                      color: colors.secondary,
                      onTap: () {
                        Navigator.pushNamed(context, '/sptrans');
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.campaign_outlined,
                      title: 'Ocorrências Cidadãs',
                      subtitle: 'Filtrar e consultar relatos',
                      color: isDark
                          ? const Color(0xFFA5B4FC)
                          : const Color(0xFF4F46E5),
                      onTap: () async {
                        await Navigator.pushNamed(context, '/occurrences');
                        _carregarPainel();
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.add_location_alt_outlined,
                      title: 'Nova Ocorrência',
                      subtitle: 'Relatar falha ou elevador PcD',
                      color: AppTheme.adaptiveWarning(context),
                      onTap: () async {
                        await Navigator.pushNamed(context, '/occurrence-form');
                        _carregarPainel();
                      },
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            // Seção de Ocorrências Críticas de Acessibilidade (Endpoint @Cacheable do Java)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alertas de Acessibilidade Ativos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        'Atualizado com os alertas de acessibilidade disponíveis',
                        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/occurrences');
                    _carregarPainel();
                  },
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Card(
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
                              'Não foi possível carregar os alertas de acessibilidade',
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
                        '$_errorMessage',
                        style: TextStyle(fontSize: 13, color: colors.onErrorContainer),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _carregarPainel,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_criticas.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Nenhuma ocorrência crítica de acessibilidade no momento.'),
                  ),
                ),
              )
            else
              ..._criticas.map(
                (item) => OccurrenceCard(
                  ocorrencia: item,
                  onTap: () async {
                    // Passagem de parâmetro via arguments na rota!
                    await Navigator.pushNamed(
                      context,
                      '/occurrence-detail',
                      arguments: item,
                    );
                    _carregarPainel();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
