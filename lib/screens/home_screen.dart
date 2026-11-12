import 'package:flutter/material.dart';
import '../models/ocorrencia_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/occurrence_card.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('ViaCidadã • Painel'),
        actions: [
          IconButton(
            tooltip: 'Atualizar dados da API Java',
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
          padding: const EdgeInsets.all(20),
          children: [
            // Banner de Boas-Vindas e Status de Autenticação JWT
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
                              user != null ? 'Olá, ${user.nome}!' : 'Modo Visitante (Leitura)',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              user != null
                                  ? '${user.email} • Sessão JWT Ativa'
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

            // Seção de Ações Rápidas (Navegação entre as 6 telas)
            const Text(
              'Serviços de Mobilidade e Cidadania',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return GridView.count(
                  crossAxisCount: isWide ? 3 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.8 : 1.35,
                  children: [
                    _QuickActionCard(
                      icon: Icons.campaign_outlined,
                      title: 'Ocorrências Cidadãs',
                      subtitle: 'Filtrar e consultar relatos',
                      color: AppTheme.primaryBlue,
                      onTap: () async {
                        await Navigator.pushNamed(context, '/occurrences');
                        _carregarPainel();
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.add_location_alt_outlined,
                      title: 'Nova Ocorrência',
                      subtitle: 'Relatar falha ou elevador PcD',
                      color: AppTheme.accentAmber,
                      onTap: () async {
                        await Navigator.pushNamed(context, '/occurrence-form');
                        _carregarPainel();
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.radar,
                      title: 'Radar SPTrans',
                      subtitle: 'Linhas e ônibus acessíveis',
                      color: AppTheme.secondaryTeal,
                      onTap: () {
                        Navigator.pushNamed(context, '/sptrans');
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alertas de Acessibilidade Ativos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Dados em tempo real de GET /api/ocorrencias/acessibilidade-criticas',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                color: const Color(0xFFFEF2F2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error_outline, color: AppTheme.dangerRed),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Não foi possível conectar à API Java em localhost:8080',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.dangerRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Detalhe técnico: $_errorMessage\nCertifique-se de que o backend ViaCidadã está rodando (mvnw spring-boot:run).',
                        style: const TextStyle(fontSize: 13),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/occurrence-form');
          _carregarPainel();
        },
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment),
        label: const Text('Relatar Problema'),
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
