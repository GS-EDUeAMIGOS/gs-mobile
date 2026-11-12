import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Camada: Screens (Tela 1 — Autenticação e Cadastro Cidadão)
/// Responsabilidade Única: Autenticar o usuário no endpoint `/api/auth/login` ou
/// cadastrar um novo cidadão em `/api/auth/register`, gerenciando o estado do formulário.
///
/// É um `StatefulWidget` porque a tela muda dinamicamente: alterna entre modo Login/Cadastro,
/// exibe indicador de carregamento (`_isLoading`) e controla o switch de mobilidade reduzida.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController(text: 'cidadao@viacidada.com.br');
  final _senhaController = TextEditingController(text: 'Cidadao@123');

  bool _isLoginMode = true;
  bool _possuiMobilidadeReduzida = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  /// Preenche rapidamente com as contas criadas pelo `DataSeederConfig.java` do backend
  void _preencherContaDemo({required bool admin}) {
    setState(() {
      _isLoginMode = true;
      if (admin) {
        _emailController.text = 'admin@viacidada.com.br';
        _senhaController.text = 'Admin@123';
      } else {
        _emailController.text = 'cidadao@viacidada.com.br';
        _senhaController.text = 'Cidadao@123';
      }
    });
  }

  Future<void> _submeterFormulario() async {
    // Aciona os validadores de cada TextFormField
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        await ApiService.instance.login(
          _emailController.text,
          _senhaController.text,
        );
      } else {
        await ApiService.instance.registrar(
          nome: _nomeController.text,
          email: _emailController.text,
          senha: _senhaController.text,
          possuiMobilidadeReduzida: _possuiMobilidadeReduzida,
        );
      }

      if (!mounted) return;
      // Navega para a Home substituindo a tela de login na pilha
      Navigator.pushReplacementNamed(context, '/home');
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho da Marca ViaCidadã
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.directions_bus_filled,
                          size: 52,
                          color: Colors.white,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'ViaCidadã',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Mobilidade Urbana e Acessibilidade Cidadã (SPTrans)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Card do Formulário
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isLoginMode ? 'Entrar na Plataforma' : 'Criar Conta Cidadã',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isLoginMode
                                  ? 'Autentique-se via JWT na API Java Spring Boot'
                                  : 'Cadastre-se para registrar ocorrências e alertas PcD',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (!_isLoginMode) ...[
                              TextFormField(
                                controller: _nomeController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome Completo',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().length < 2) {
                                    return 'Informe um nome válido (mín. 2 caracteres)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'E-mail',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                if (value == null || !value.contains('@')) {
                                  return 'Informe um e-mail válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _senhaController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'A senha deve ter no mínimo 6 caracteres';
                                }
                                return null;
                              },
                            ),

                            if (!_isLoginMode) ...[
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Possuo mobilidade reduzida / PcD',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Prioriza alertas de elevadores e rampas acessíveis',
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: _possuiMobilidadeReduzida,
                                activeThumbColor: AppTheme.secondaryTeal,
                                onChanged: (val) {
                                  setState(() => _possuiMobilidadeReduzida = val);
                                },
                              ),
                            ],

                            const SizedBox(height: 24),

                            ElevatedButton(
                              onPressed: _isLoading ? null : _submeterFormulario,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_isLoginMode ? 'Entrar com JWT' : 'Concluir Cadastro'),
                            ),

                            const SizedBox(height: 12),

                            TextButton(
                              onPressed: () {
                                setState(() => _isLoginMode = !_isLoginMode);
                              },
                              child: Text(
                                _isLoginMode
                                    ? 'Não tem conta? Cadastre-se aqui'
                                    : 'Já possui conta? Faça login',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Atalhos para preenchimento rápido durante a demonstração para os professores
                  Card(
                    color: const Color(0xFFEFF6FF),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bolt, size: 18, color: AppTheme.primaryBlue),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Contas de Demonstração (DataSeeder H2 Java):',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.accessible, size: 16),
                                label: const Text('Maria Silva (Cidadã PcD)'),
                                onPressed: () => _preencherContaDemo(admin: false),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.admin_panel_settings, size: 16),
                                label: const Text('Administrador'),
                                onPressed: () => _preencherContaDemo(admin: true),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.public, size: 16),
                                label: const Text('Explorar sem Login (GET Público)'),
                                onPressed: () {
                                  Navigator.pushReplacementNamed(context, '/home');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
