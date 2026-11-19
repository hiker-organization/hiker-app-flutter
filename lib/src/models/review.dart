class ReviewAutor {
  final String nomeExibicao;
  final String nomeUsuario;
  final String? fotoUrl;
  final num reputacao;

  ReviewAutor({
    required this.nomeExibicao,
    required this.nomeUsuario,
    required this.fotoUrl,
    required this.reputacao,
  });

  factory ReviewAutor.fromJson(Map<String, dynamic> json) {
    return ReviewAutor(
      nomeExibicao: json['nome_exibicao'] as String,
      nomeUsuario: json['nome_usuario'] as String,
      fotoUrl: json['foto_url'] as String?,
      reputacao: json['reputacao'] as num,
    );
  }
}

class Review {
  final int id;
  final String descricao;
  final String local;
  // Google place id; links the review to the place page.
  final String? idLocal;
  final int qntLikes;
  final int qntDislikes;
  final int nota;
  final DateTime createdAt;
  final ReviewAutor autor;
  final List<String> fotos;
  final List<String> tags;
  final bool liked;
  final bool disliked;
  final bool favorited;
  // Hidden reviews are only returned to their own author.
  final bool oculto;

  Review({
    required this.id,
    required this.descricao,
    required this.local,
    this.idLocal,
    required this.qntLikes,
    required this.qntDislikes,
    required this.nota,
    required this.createdAt,
    required this.autor,
    required this.fotos,
    required this.tags,
    required this.liked,
    required this.disliked,
    this.favorited = false,
    this.oculto = false,
  });

  // Profile endpoints return reviews without "autor", so the profile owner is passed in.
  factory Review.fromJson(Map<String, dynamic> json, {ReviewAutor? autor}) {
    return Review(
      id: json['id'] as int,
      descricao: json['descricao'] as String,
      local: json['local'] as String,
      idLocal: json['id_local'] as String?,
      qntLikes: json['qnt_likes'] as int,
      qntDislikes: json['qnt_dislikes'] as int,
      nota: json['nota'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      autor: autor ?? ReviewAutor.fromJson(json['autor'] as Map<String, dynamic>),
      fotos: (json['fotos'] as List<dynamic>)
          .map((foto) => foto['url'] as String)
          .toList(),
      tags: (json['tags'] as List<dynamic>)
          .map((tag) => tag['tag']['descritivo'] as String)
          .toList(),
      liked: json['liked'] as bool? ?? false,
      disliked: json['disliked'] as bool? ?? false,
      favorited: json['favorited'] as bool? ?? false,
      oculto: json['oculto'] as bool? ?? false,
    );
  }
}
