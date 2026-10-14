// Same rules as the API sign-up (CreateUserDTO). Each returns the message to show, or null.

String nomeUsuarioSemArroba(String text) => text.trim().replaceFirst(RegExp(r'^@+'), '');

String celularDigits(String text) => text.replaceAll(RegExp(r'\D'), '');

String? validateNomeUsuario(String nomeUsuario) {
  if (nomeUsuario.length < 3 || nomeUsuario.length > 20) {
    return 'O nome de usuário deve ter entre 3 e 20 caracteres.';
  }
  if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(nomeUsuario)) {
    return "O nome de usuário só pode ter letras, números, '_' ou '.'.";
  }
  return null;
}

String? validateNomeExibicao(String nomeExibicao) {
  if (nomeExibicao.isEmpty || nomeExibicao.length > 30) {
    return 'O nome de exibição deve ter entre 1 e 30 caracteres.';
  }
  return null;
}

String? validateCelular(String digits) {
  if (digits.length < 10 || digits.length > 11) return 'Insira um celular válido com DDD.';
  return null;
}

String? validateSenha(String senha, String confirmacao) {
  if (senha.length < 8 ||
      !RegExp(r'[A-Z]').hasMatch(senha) ||
      !RegExp(r'[a-z]').hasMatch(senha) ||
      !RegExp(r'\d').hasMatch(senha) ||
      !RegExp(r'[^A-Za-z0-9]').hasMatch(senha)) {
    return 'A senha precisa ter no mínimo 8 caracteres, 1 maiúscula, 1 minúscula, 1 número e 1 símbolo.';
  }
  if (senha != confirmacao) return 'As senhas não coincidem.';
  return null;
}
