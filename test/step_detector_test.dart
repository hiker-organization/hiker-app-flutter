import 'dart:math';

import 'package:app_hiker/src/utils/step_detector.dart';
import 'package:flutter_test/flutter_test.dart';

const _gravity = 9.81;
const _sampleRate = 50; // Hz, próximo do SensorInterval.gameInterval.

// Alimenta [seconds] segundos de aceleração vertical dada por [signal] (m/s², sem a
// gravidade) e retorna quantos passos foram contados.
int _countSignal(double seconds, double Function(double t, Random random) signal, {int seed = 1}) {
  final detector = StepDetector();
  final random = Random(seed);
  final start = DateTime(2026);
  var steps = 0;

  for (var i = 0; i < (seconds * _sampleRate).round(); i++) {
    final t = i / _sampleRate;
    final timestamp = start.add(Duration(microseconds: (t * 1e6).round()));
    steps += detector.addSample(0.3, 0.2, _gravity + signal(t, random), timestamp);
  }
  return steps;
}

double _noise(Random random, double amount) => (random.nextDouble() * 2 - 1) * amount;

// Caminhada constante: [frequency] passos por segundo.
int _countSteps({
  required double seconds,
  required double frequency,
  required double amplitude,
  double noise = 0,
}) {
  return _countSignal(seconds, (t, r) => amplitude * sin(2 * pi * frequency * t) + _noise(r, noise));
}

// Pico curto centrado em [center] segundos, como um único solavanco do celular.
double _bump(double t, double center, double amplitude) {
  final x = (t - center) / 0.06;
  return amplitude * exp(-x * x);
}

void main() {
  group('caminhada', () {
    test('conta um passo por oscilação', () {
      // 2 passos por segundo durante 30 s.
      final steps = _countSteps(seconds: 30, frequency: 2, amplitude: 3);
      expect(steps, inInclusiveRange(57, 61));
    });

    test('lida com caminhada com ruído', () {
      final steps = _countSteps(seconds: 30, frequency: 1.8, amplitude: 3, noise: 0.8);
      expect(steps, inInclusiveRange(50, 56));
    });

    test('conta caminhada leve', () {
      // Passos lentos e suaves (celular no bolso de alguém andando com calma).
      final steps = _countSteps(seconds: 30, frequency: 1.6, amplitude: 1.2, noise: 0.3);
      expect(steps, inInclusiveRange(45, 49));
    });

    test('conta caminhada acelerada', () {
      final steps = _countSteps(seconds: 30, frequency: 2.4, amplitude: 2, noise: 0.5);
      expect(steps, inInclusiveRange(69, 73));
    });

    test('continua contando depois de ficar parado um tempo', () {
      // 10 s andando, 4 s parado, 10 s andando: uns 40 passos. Os primeiros passos depois
      // da parada só são confirmados mais tarde, mas não se perdem.
      final steps = _countSignal(24, (t, r) {
        final walking = t < 10 || t >= 14;
        return (walking ? 2 * sin(2 * pi * 2 * t) : 0) + _noise(r, 0.3);
      });
      expect(steps, inInclusiveRange(37, 41));
    });
  });

  group('passos falsos', () {
    test('ignora colocar o celular no bolso', () {
      // Parado, depois três solavancos irregulares enquanto o celular vai para o bolso, depois parado.
      final steps = _countSignal(8, (t, r) {
        return _bump(t, 2.0, 6) + _bump(t, 2.35, -4) + _bump(t, 2.5, 5) + _bump(t, 3.4, 4) + _noise(r, 0.3);
      });
      expect(steps, 0);
    });

    test('ignora o manuseio do celular', () {
      // 15 s de solavancos em momentos irregulares, como pegar o celular e digitar.
      final jolts = <double>[];
      final random = Random(42);
      for (var t = 0.5; t < 15; t += 0.25 + random.nextDouble() * 1.8) {
        jolts.add(t);
      }
      final steps = _countSignal(16, (t, r) {
        return jolts.fold(0.0, (sum, center) => sum + _bump(t, center, 3 + (center * 7) % 3)) + _noise(r, 0.4);
      });
      expect(steps, lessThanOrEqualTo(4));
    });

    test('ignora o celular parado na mão', () {
      final steps = _countSteps(seconds: 30, frequency: 2, amplitude: 0, noise: 0.5);
      expect(steps, 0);
    });

    test('ignora o celular parado sobre uma superfície', () {
      final steps = _countSteps(seconds: 30, frequency: 2, amplitude: 0, noise: 0.2);
      expect(steps, 0);
    });

    test('não conta vibrações mais rápidas do que uma pessoa consegue andar', () {
      // Uma vibração de 8 Hz daria 240 passos em 30 s; o intervalo mínimo limita isso.
      final steps = _countSteps(seconds: 30, frequency: 8, amplitude: 4);
      expect(steps, lessThanOrEqualTo(100));
    });
  });
}
