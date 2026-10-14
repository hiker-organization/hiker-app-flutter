import 'package:app_hiker/src/models/review.dart';

class UserProfile {
  final String nomeExibicao;
  final String nomeUsuario;
  final String? fotoUrl;
  final num reputacao;
  final List<Review> reviews;
  // Private data, only returned by /user/me.
  final String? email;
  final DateTime? dataNascimento;
  final String? numeroCelular;
  // Whether the account also enters with Google; only known on the own profile.
  final bool googleVinculado;

  UserProfile({
    required this.nomeExibicao,
    required this.nomeUsuario,
    required this.fotoUrl,
    required this.reputacao,
    required this.reviews,
    this.email,
    this.dataNascimento,
    this.numeroCelular,
    this.googleVinculado = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final autor = ReviewAutor.fromJson(json);
    // The API doesn't order profile reviews, newest first here.
    final reviews = (json['reviews'] as List<dynamic>)
        .map((item) => Review.fromJson(item as Map<String, dynamic>, autor: autor))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final dataNascimento = json['data_nascimento'] as String?;

    return UserProfile(
      nomeExibicao: autor.nomeExibicao,
      nomeUsuario: autor.nomeUsuario,
      fotoUrl: autor.fotoUrl,
      reputacao: autor.reputacao,
      reviews: reviews,
      email: json['email'] as String?,
      dataNascimento: dataNascimento != null ? DateTime.parse(dataNascimento).toLocal() : null,
      numeroCelular: json['numero_celular'] as String?,
      googleVinculado: json['google_vinculado'] as bool? ?? false,
    );
  }
}
