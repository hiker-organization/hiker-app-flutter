import 'package:app_hiker/src/models/place_info.dart';
import 'package:flutter_test/flutter_test.dart';

PlaceInfo _place({bool isCidade = false, String? cidade = 'Jundiaí', String? siglaEstado = 'SP'}) {
  return PlaceInfo(
    placeId: 'x',
    nome: 'Parque da Cidade',
    cidade: cidade,
    estado: 'São Paulo',
    siglaEstado: siglaEstado,
    pais: 'Brasil',
    siglaPais: 'BR',
    isCidade: isCidade,
  );
}

void main() {
  test('mostra cidade, estado e país de um local', () {
    expect(_place().localidade, 'Jundiaí, SP, BR');
  });

  test('não repete o nome quando o local é uma cidade', () {
    expect(_place(isCidade: true).localidade, 'SP, BR');
  });

  test('usa o nome do estado como alternativa e ignora o que estiver faltando', () {
    expect(_place(cidade: null, siglaEstado: null).localidade, 'São Paulo, BR');
  });

  test('lê a resposta da API', () {
    final place = PlaceInfo.fromJson({
      'place_id': 'abc',
      'nome': 'Jundiaí',
      'cidade': 'Jundiaí',
      'estado': 'São Paulo',
      'sigla_estado': 'SP',
      'pais': 'Brasil',
      'sigla_pais': 'BR',
      'is_cidade': true,
      'endereco': null,
    });
    expect(place.localidade, 'SP, BR');
  });
}
