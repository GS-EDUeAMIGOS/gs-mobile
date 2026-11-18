import 'package:flutter/material.dart';
import '../models/ocorrencia_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/theme_selector_button.dart';

/// Camada: Screens (Tela 4 — Detalhes da Ocorrência Cidadã)
/// Responsabilidade Única: Receber um objeto `OcorrenciaModel` via passagem de parâmetros
/// na rota (`ModalRoute.of(context)!.settings.arguments`), exibir todos os seus metadados
/// e permitir excluir o registro (`DELETE /api/ocorrencias/{id}`) caso o usuário esteja autenticado.
class OccurrenceDetailScreen extends StatefulWidget {
  const OccurrenceDetailScreen({super.key});

  @override
  State<OccurrenceDetailScreen> createState() => _OccurrenceDetailScreenState();
}

class _OccurrenceDetailScreenState extends State<OccurrenceDetailScreen> {
  bool _isDeleting = false;

  String _formatarDataRegistro(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw.replaceAll('T', ' ').split('.').first;
    }
    final local = parsed.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y às $hh:$mm';
  }

  Future<void> _confirmarExclusao(OcorrenciaModel ocorrencia) async {
    if (ocorrencia.id == null) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Ocorrência?'),
        content: Text(
          'Deseja remover permanentemente a ocorrência "${ocorrencia.titulo}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    setState(() => _isDeleting = true);

    try {
      await ApiService.instance.removerOcorrencia(ocorrencia.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocorrência removida com sucesso.'),
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
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Recupera o parâmetro enviado pelo Navigator.pushNamed(..., arguments: item)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! OcorrenciaModel) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/occurrences'),
          title: const Text('Detalhes da Ocorrência'),
          actions: const [ThemeSelectorButton()],
        ),
        body: const Center(child: Text('Nenhuma ocorrência selecionada.')),
      );
    }

    final ocorrencia = args;
    final isAuthenticated = ApiService.instance.isAuthenticated;
    final colors = Theme.of(context).colorScheme;
    final linha = ocorrencia.linhaEmDestaque;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/occurrences'),
        title: const Text('Detalhes do Relato'),
        actions: [
          const ThemeSelectorButton(),
          if (isAuthenticated && ocorrencia.id != null)
            IconButton(
              tooltip: 'Excluir ocorrência',
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.delete_outline),
              onPressed: _isDeleting
                  ? null
                  : () => _confirmarExclusao(ocorrencia),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card Principal da Ocorrência
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(
                                Icons.category_outlined,
                                size: 16,
                              ),
                              label: Text(ocorrencia.tipo.label),
                            ),
                            Chip(
                              avatar: const Icon(Icons.priority_high, size: 16),
                              label: Text(
                                'Gravidade: ${ocorrencia.gravidade.label}',
                              ),
                            ),
                            Chip(
                              avatar: const Icon(Icons.info_outline, size: 16),
                              label: Text('Status: ${ocorrencia.status.label}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (linha != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: colors.secondary),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.directions_bus_filled_outlined,
                                  color: colors.onSecondaryContainer,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Linha informada',
                                        style: TextStyle(
                                          color: colors.onSecondaryContainer,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        linha,
                                        style: TextStyle(
                                          color: colors.onSecondaryContainer,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          ocorrencia.titulo,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ocorrencia.descricaoSemTagLinha,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),

                        // Metadados Técnicos de Transporte e Acessibilidade
                        _InfoRow(
                          icon: Icons.accessible_forward,
                          label: 'Afeta Acessibilidade (PcD)?',
                          value: ocorrencia.afetaAcessibilidade
                              ? 'Sim — Prioridade de Acessibilidade'
                              : 'Não informado como crítico PcD',
                          highlight: ocorrencia.afetaAcessibilidade,
                        ),
                        _InfoRow(
                          icon: Icons.person_outline,
                          label: 'Reportado por',
                          value: ocorrencia.nomeUsuario ?? 'Cidadão cadastrado',
                        ),
                        if (ocorrencia.codigoLinha != null &&
                            ocorrencia.codigoLinha! > 0 &&
                            linha != ocorrencia.codigoLinha.toString())
                          _InfoRow(
                            icon: Icons.directions_bus,
                            label: 'Código oficial da linha na SPTrans',
                            value: '${ocorrencia.codigoLinha}',
                          ),
                        if (ocorrencia.codigoParada != null &&
                            ocorrencia.codigoParada! > 0)
                          _InfoRow(
                            icon: Icons.place_outlined,
                            label: 'Parada SPTrans',
                            value: '${ocorrencia.codigoParada}',
                          ),
                        if (ocorrencia.prefixoVeiculo != null &&
                            ocorrencia.prefixoVeiculo!.isNotEmpty)
                          _InfoRow(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Prefixo do Ônibus',
                            value: ocorrencia.prefixoVeiculo!,
                          ),
                        if (ocorrencia.criadoEm != null)
                          _InfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Data de Registro',
                            value: _formatarDataRegistro(ocorrencia.criadoEm!),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botão de integração direta com o Radar SPTrans caso a ocorrência tenha linha vinculada
                if (ocorrencia.codigoLinha != null &&
                    ocorrencia.codigoLinha! > 0)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryTeal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/sptrans',
                        arguments: ocorrencia.codigoLinha,
                      );
                    },
                    icon: const Icon(Icons.radar),
                    label: const Text('Ver Ônibus desta Linha no Mapa'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: highlight ? colors.secondary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: highlight ? colors.secondary : colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
