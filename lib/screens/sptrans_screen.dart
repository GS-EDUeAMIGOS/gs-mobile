import 'package:flutter/material.dart';
import '../models/olho_vivo_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Camada: Screens (Tela 6 — Radar SPTrans Olho Vivo em Tempo Real)
/// Responsabilidade Única: Consumir os endpoints `/api/linhas?termo=...` e
/// `/api/linhas/{codigo}/veiculos` do seu `OlhoVivoController.java`, exibindo as linhas
/// da SPTrans e a posição em tempo real dos ônibus com selo de Acessibilidade PcD (`a: true`).
class SptransScreen extends StatefulWidget {
  const SptransScreen({super.key});

  @override
  State<SptransScreen> createState() => _SptransScreenState();
}

class _SptransScreenState extends State<SptransScreen> {
  final _termoController = TextEditingController(text: '8000');
  List<LinhaResumoModel> _linhas = [];
  PosicaoLinhaResponseModel? _posicaoAtual;
  int? _codigoLinhaSelecionada;

  bool _isLoadingLinhas = false;
  bool _isLoadingVeiculos = false;
  String? _errorMessage;
  bool _initializedArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      _initializedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        _codigoLinhaSelecionada = args;
        _buscarLinhas();
        _carregarVeiculos(args);
      } else {
        _buscarLinhas();
      }
    }
  }

  @override
  void dispose() {
    _termoController.dispose();
    super.dispose();
  }

  Future<void> _buscarLinhas() async {
    setState(() {
      _isLoadingLinhas = true;
      _errorMessage = null;
    });

    try {
      final resultado = await ApiService.instance.buscarLinhas(_termoController.text);
      if (!mounted) return;
      setState(() {
        _linhas = resultado;
        _isLoadingLinhas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingLinhas = false;
      });
    }
  }

  Future<void> _carregarVeiculos(int codigoLinha) async {
    setState(() {
      _codigoLinhaSelecionada = codigoLinha;
      _isLoadingVeiculos = true;
      _errorMessage = null;
    });

    try {
      final pos = await ApiService.instance.buscarVeiculosPorLinha(codigoLinha);
      if (!mounted) return;
      setState(() {
        _posicaoAtual = pos;
        _isLoadingVeiculos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingVeiculos = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar SPTrans Olho Vivo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Caixa de Busca de Linhas SPTrans
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Consultar Linhas da SPTrans (GET /api/linhas)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Digite o número ou nome da linha (ex.: 8000, Lapa, Paulista, 875A)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _termoController,
                          onSubmitted: (_) => _buscarLinhas(),
                          decoration: const InputDecoration(
                            hintText: 'Termo ou letreiro da linha...',
                            prefixIcon: Icon(Icons.directions_bus),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isLoadingLinhas ? null : _buscarLinhas,
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null)
            Card(
              color: const Color(0xFFFEF2F2),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.w600),
                ),
              ),
            ),

          // Seção de Veículos em Tempo Real (quando uma linha é selecionada)
          if (_codigoLinhaSelecionada != null) ...[
            Card(
              color: const Color(0xFFF0FDF4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Frota em Operação • Linha #$_codigoLinhaSelecionada',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.secondaryTeal,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Atualizar posição GPS',
                          icon: const Icon(Icons.refresh, color: AppTheme.secondaryTeal),
                          onPressed: () => _carregarVeiculos(_codigoLinhaSelecionada!),
                        ),
                      ],
                    ),
                    if (_isLoadingVeiculos)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_posicaoAtual != null) ...[
                      Text(
                        'Horário de referência SPTrans: ${_posicaoAtual!.horarioReferencia} • '
                        '${_posicaoAtual!.veiculos.length} veículo(s) localizado(s)',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 12),
                      if (_posicaoAtual!.veiculos.isEmpty)
                        const Text('Nenhum veículo transmitindo GPS neste momento para esta linha.')
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _posicaoAtual!.veiculos.map((v) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: v.acessivelPcD
                                      ? AppTheme.secondaryTeal
                                      : const Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    v.acessivelPcD ? Icons.accessible : Icons.directions_bus,
                                    color: v.acessivelPcD
                                        ? AppTheme.secondaryTeal
                                        : AppTheme.primaryBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Prefixo ${v.prefixo}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        v.acessivelPcD
                                            ? 'Acessível PcD (Elevador OK)'
                                            : 'Sem acessibilidade PcD',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: v.acessivelPcD
                                              ? AppTheme.secondaryTeal
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                      Text(
                                        'GPS: ${v.latitude.toStringAsFixed(4)}, ${v.longitude.toStringAsFixed(4)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Lista de Linhas Encontradas
          const Text(
            'Linhas Encontradas (Toque em uma linha para ver os ônibus)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),

          if (_isLoadingLinhas)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_linhas.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Nenhuma linha retornada. Faça uma busca acima.'),
                ),
              ),
            )
          else
            ..._linhas.map(
              (linha) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
                    child: const Icon(Icons.directions_bus, color: AppTheme.primaryBlue),
                  ),
                  title: Text(
                    'Linha ${linha.letreiroCompleto} (Cód. #${linha.codigoLinha})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Sentido ${linha.sentido}: ${linha.descricaoSentido}',
                  ),
                  trailing: ElevatedButton.icon(
                    onPressed: () => _carregarVeiculos(linha.codigoLinha),
                    icon: const Icon(Icons.gps_fixed, size: 16),
                    label: const Text('Ver Frota'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
