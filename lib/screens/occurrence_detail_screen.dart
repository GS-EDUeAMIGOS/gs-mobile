import 'package:flutter/material.dart';
import '../models/ocorrencia_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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

  Future<void> _confirmarExclusao(OcorrenciaModel ocorrencia) async {
    if (ocorrencia.id == null) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Ocorrência?'),
        content: Text(
          'Deseja remover permanentemente a ocorrência "${ocorrencia.titulo}" (#${ocorrencia.id}) na API Java?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
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
          content: Text('Ocorrência removida com sucesso!'),
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
        appBar: AppBar(title: const Text('Detalhes da Ocorrência')),
        body: const Center(
          child: Text('Nenhuma ocorrência selecionada.'),
        ),
      );
    }

    final ocorrencia = args;
    final isAuthenticated = ApiService.instance.isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ocorrência #${ocorrencia.id ?? "-"}'),
        actions: [
          if (isAuthenticated && ocorrencia.id != null)
            IconButton(
              tooltip: 'Excluir ocorrência (Requer JWT)',
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              onPressed: _isDeleting ? null : () => _confirmarExclusao(ocorrencia),
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
                              avatar: const Icon(Icons.category_outlined, size: 16),
                              label: Text(ocorrencia.tipo.label),
                            ),
                            Chip(
                              avatar: const Icon(Icons.priority_high, size: 16),
                              label: Text('Gravidade: ${ocorrencia.gravidade.label}'),
                            ),
                            Chip(
                              avatar: const Icon(Icons.info_outline, size: 16),
                              label: Text('Status: ${ocorrencia.status.label}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ocorrencia.titulo,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ocorrencia.descricao,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Color(0xFF334155),
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
                          value: ocorrencia.nomeUsuario ?? 'Usuário #${ocorrencia.usuarioId}',
                        ),
                        if (ocorrencia.codigoLinha != null)
                          _InfoRow(
                            icon: Icons.directions_bus,
                            label: 'Código da Linha SPTrans (cl)',
                            value: '${ocorrencia.codigoLinha}',
                          ),
                        if (ocorrencia.codigoParada != null)
                          _InfoRow(
                            icon: Icons.place_outlined,
                            label: 'Código da Parada SPTrans (cp)',
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
                            value: ocorrencia.criadoEm!.replaceAll('T', ' ').split('.').first,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botão de integração direta com o Radar SPTrans caso a ocorrência tenha linha vinculada
                if (ocorrencia.codigoLinha != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryTeal,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/sptrans',
                        arguments: ocorrencia.codigoLinha,
                      );
                    },
                    icon: const Icon(Icons.radar),
                    label: Text(
                      'Consultar Veículos em Tempo Real da Linha #${ocorrencia.codigoLinha}',
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: highlight ? AppTheme.secondaryTeal : const Color(0xFF64748B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: highlight ? AppTheme.secondaryTeal : const Color(0xFF1E293B),
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
