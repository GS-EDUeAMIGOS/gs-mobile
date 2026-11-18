import 'package:flutter/material.dart';
import '../models/ocorrencia_model.dart';
import '../theme/app_theme.dart';

/// Camada: Widgets (Componentes Visuais Reutilizáveis)
/// Responsabilidade Única: Renderizar um cartão visual padronizado para uma `OcorrenciaModel`.
/// É um `StatelessWidget` porque não guarda estado mutável próprio: ele apenas recebe
/// os dados prontos via construtor e desenha na tela (como uma peça de LEGO).
class OccurrenceCard extends StatelessWidget {
  final OcorrenciaModel ocorrencia;
  final VoidCallback? onTap;

  const OccurrenceCard({super.key, required this.ocorrencia, this.onTap});

  Color _gravidadeColor(NivelGravidade gravidade, BuildContext context) {
    switch (gravidade) {
      case NivelGravidade.CRITICA:
      case NivelGravidade.ALTA:
        return AppTheme.adaptiveDanger(context);
      case NivelGravidade.MEDIA:
        return AppTheme.adaptiveWarning(context);
      case NivelGravidade.BAIXA:
        return Theme.of(context).colorScheme.secondary;
    }
  }

  IconData _tipoIcon(TipoOcorrencia tipo) {
    switch (tipo) {
      case TipoOcorrencia.ELEVADOR_INOPERANTE:
      case TipoOcorrencia.ACESSIBILIDADE:
        return Icons.accessible_forward;
      case TipoOcorrencia.LOTACAO_EXCESSIVA:
        return Icons.groups;
      case TipoOcorrencia.ATRASO:
        return Icons.schedule;
      case TipoOcorrencia.SEGURANCA:
        return Icons.shield_outlined;
      case TipoOcorrencia.INFRAESTRUTURA_PARADA:
        return Icons.bus_alert;
      case TipoOcorrencia.OUTROS:
        return Icons.report_problem_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final gravidadeCor = _gravidadeColor(ocorrencia.gravidade, context);
    final linha = ocorrencia.linhaEmDestaque;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha superior: no máximo 2 indicadores (Categoria à esquerda + Gravidade/PcD à direita)
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _tipoIcon(ocorrencia.tipo),
                            size: 15,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              ocorrencia.tipo.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: gravidadeCor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ocorrencia.afetaAcessibilidade) ...[
                          Icon(Icons.accessible, size: 14, color: gravidadeCor),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          ocorrencia.afetaAcessibilidade
                              ? 'PcD • ${ocorrencia.gravidade.label}'
                              : 'Gravidade ${ocorrencia.gravidade.label}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: gravidadeCor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (linha != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.secondary.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_bus_filled_outlined,
                        size: 19,
                        color: colors.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Linha: $linha',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSecondaryContainer,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Título da Ocorrência
              Text(
                ocorrencia.titulo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),

              // Descrição resumida (máximo de 2 linhas no card)
              Text(
                ocorrencia.descricaoSemTagLinha,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),

              // Rodapé com Linha/Parada, Status e seta indicando navegação para detalhes
              Row(
                children: [
                  if (ocorrencia.prefixoVeiculo != null &&
                      ocorrencia.prefixoVeiculo!.isNotEmpty) ...[
                    Icon(
                      Icons.directions_bus,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ônibus nº ${ocorrencia.prefixoVeiculo}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  Text(
                    ocorrencia.status.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: colors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
