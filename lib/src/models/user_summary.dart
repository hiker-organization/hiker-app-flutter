// A person in the search results.
class UserSummary {
  final String nomeUsuario;
  final String nomeExibicao;
  final String? fotoUrl;
  final num reputacao;

  UserSummary({
    required this.nomeUsuario,
    required this.nomeExibicao,
    required this.fotoUrl,
    required this.reputacao,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      nomeUsuario: json['nome_usuario'] as String,
      nomeExibicao: json['nome_exibicao'] as String,
      fotoUrl: json['foto_url'] as String?,
      reputacao: json['reputacao'] as num,
    );
  }
}
