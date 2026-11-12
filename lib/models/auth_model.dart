/// Camada: Models (Domínio / DTOs de Autenticação)
/// Responsabilidade Única: Representar os dados do usuário autenticado e o Token JWT
/// retornados pelo endpoint `/api/auth/login` e `/api/auth/register` da API Java (`AuthDTO.TokenResponse`).
class AuthUser {
  final String token;
  final String tipo;
  final int usuarioId;
  final String nome;
  final String email;
  final String role;

  const AuthUser({
    required this.token,
    required this.tipo,
    required this.usuarioId,
    required this.nome,
    required this.email,
    required this.role,
  });

  /// Factory Constructor: Converte um Map (JSON vindo da API Java) em um objeto Dart tipado.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      token: json['token'] as String? ?? '',
      tipo: json['tipo'] as String? ?? 'Bearer',
      usuarioId: (json['usuarioId'] as num?)?.toInt() ?? 0,
      nome: json['nome'] as String? ?? 'Cidadão',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'ROLE_CIDADAO',
    );
  }

  bool get isAdmin => role == 'ROLE_ADMIN';
}
