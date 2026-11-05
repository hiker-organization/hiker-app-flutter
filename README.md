# Hiker - App

Aplicativo mobile do Hiker, feito em Flutter. Consome a [hiker-api](https://github.com/hiker-organization/hiker-api).

## Requisitos

| Ferramenta | Versão |
| --- | --- |
| Flutter | 3.44.0 ou superior (canal stable) |
| Dart | 3.13.3 ou superior (já vem com o Flutter) |
| Android | Android Studio com um emulador ou celular com depuração USB |
| iOS (opcional) | macOS com Xcode |

As versões mínimas vêm do `pubspec.yaml` (`sdk: ^3.13.3`) e do `pubspec.lock` (`flutter: >=3.44.0`). Com versões mais antigas, o `flutter pub get` falha. Para conferir a sua:

```bash
flutter --version
```

Se precisar atualizar: `flutter upgrade`.

## Configuração

1. Instale as dependências:

   ```bash
   flutter pub get
   ```

2. Crie o `.env` a partir do exemplo:

   ```bash
   cp .env.example .env
   ```

   O `.env` é obrigatório: o app carrega esse arquivo na inicialização e não abre sem ele.

   | Variável | Descrição |
   | --- | --- |
   | `API_BASE_URL` | URL base da hiker-api, sem barra no final. No emulador Android, `http://10.0.2.2:3000` aponta para a API rodando no seu computador. Num celular físico, use o IP do computador na rede local. |

3. Suba a hiker-api (veja o README dela) e confira se ela responde na URL configurada.

## Rodando

```bash
flutter run
```

Para gerar um APK de debug:

```bash
flutter build apk --debug
```

## Login com Google

Os client IDs do Google ficam em `lib/src/services/google_sign_in_service.dart` e em `ios/Runner/Info.plist`. No Android, o login com Google só funciona se o SHA-1 da chave que assina o build estiver cadastrado no projeto do Google Cloud. Para ver o SHA-1 da chave de debug:

```bash
cd android && ./gradlew signingReport
```

Login e cadastro com e-mail e senha funcionam sem essa etapa.

## Testes

```bash
flutter analyze
flutter test
```
