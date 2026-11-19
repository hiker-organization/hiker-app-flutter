import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

// Same date as POLITICA_PRIVACIDADE_VERSAO in the API, which stores the version each
// account accepted. Change both when the text changes.
const politicaPrivacidadeAtualizadaEm = '19/11/2026';

class _Secao {
  final String titulo;
  final List<String> paragrafos;

  const _Secao(this.titulo, this.paragrafos);
}

const _secoes = [
  _Secao('Quem somos', [
    'O Hiker é um aplicativo para registrar trilhas e avaliar locais de natureza, desenvolvido como '
        'Projeto Integrador na Fatec. Esta política explica quais dados pessoais o app coleta, por que '
        'coleta e o que você pode fazer com eles, conforme a Lei Geral de Proteção de Dados (Lei 13.709/2018).',
  ]),
  _Secao('Dados que coletamos', [
    'Cadastro: nome de usuário, nome de exibição, e-mail, número de celular, data de nascimento, senha '
        'e, se você quiser, uma foto de perfil.',
    'Entrada com Google: e-mail, nome, foto e o identificador da sua conta Google.',
    'Trilhas: a rota percorrida (localização GPS), distância, duração, passos contados pelos sensores do '
        'aparelho, cidade e estado, além do nome, descrição, nota, fotos e tags que você informar.',
    'Avaliações: texto, nota, fotos e o local avaliado, além das curtidas, favoritos e denúncias que você fizer.',
  ]),
  _Secao('Como usamos seus dados', [
    'Para criar e manter sua conta, autenticar seu acesso, enviar códigos de recuperação de senha e de troca '
        'de e-mail, registrar suas trilhas, mostrar o conteúdo que você publica e moderar denúncias.',
    'Não usamos seus dados para publicidade e não vendemos seus dados.',
  ]),
  _Secao('Localização', [
    'A localização só é usada enquanto você grava uma trilha. Durante a gravação ela continua sendo lida com o '
        'app em segundo plano, e o Android mostra uma notificação enquanto isso acontece. Fora da gravação, o '
        'app não acompanha sua localização.',
  ]),
  _Secao('O que fica visível para outras pessoas', [
    'Seu nome de exibição, nome de usuário, foto, reputação, avaliações publicadas e as trilhas que você '
        'escolher compartilhar. Trilhas não compartilhadas ficam visíveis só para você.',
    'Seu e-mail, celular e data de nascimento não aparecem para outros usuários.',
  ]),
  _Secao('Serviços de terceiros', [
    'Google: entrada com a conta Google e informações dos locais (Google Places).',
    'Microsoft Azure: armazenamento das fotos enviadas no app.',
    'OpenStreetMap: imagens dos mapas, que recebem a área do mapa exibida.',
    'Serviço de e-mail: envio dos códigos de recuperação de senha e de troca de e-mail.',
    'Cada serviço trata os dados conforme a própria política de privacidade.',
  ]),
  _Secao('Armazenamento e segurança', [
    'A senha é guardada como hash, uma forma irreversível, e nunca em texto puro. Os dados de acesso ficam no armazenamento '
        'seguro do aparelho, e uma trilha em andamento fica salva no aparelho até ser concluída ou descartada.',
  ]),
  _Secao('Exclusão da conta', [
    'Ao excluir a conta, seu e-mail, nome de usuário, nome de exibição, celular e o vínculo com o Google são '
        'apagados. Avaliações e trilhas já publicadas podem continuar visíveis, identificadas como '
        '"Usuário desativado".',
  ]),
  _Secao('Seus direitos', [
    'Você pode, a qualquer momento, pedir acesso aos seus dados, corrigi-los (a maior parte pode ser editada '
        'no próprio perfil), pedir a exclusão da conta, saber com quem os dados são compartilhados e revogar '
        'este consentimento.',
  ]),
  _Secao('Alterações nesta política', [
    'Se esta política mudar, a nova versão será mostrada no app e poderá ser pedido um novo aceite.',
  ]),
  _Secao('Contato', [
    'Dúvidas ou pedidos sobre seus dados podem ser enviados à equipe Hiker - hikerapp.dsm@gmail.com.',
  ]),
];

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mutedColor = Pallete.whiteColor.withAlpha(180);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: Pallete.whiteColor),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Política de Privacidade',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  Text(
                    'Última atualização: $politicaPrivacidadeAtualizadaEm',
                    style: TextStyle(color: mutedColor),
                  ),
                  for (final secao in _secoes) ...[
                    const SizedBox(height: 24),
                    Text(
                      secao.titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Pallete.primaryColor,
                      ),
                    ),
                    for (final paragrafo in secao.paragrafos) ...[
                      const SizedBox(height: 8),
                      Text(paragrafo, style: const TextStyle(fontSize: 15, height: 1.45)),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
