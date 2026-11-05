import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_hiker/src/models/trilha.dart';
import 'package:app_hiker/src/utils/session_user.dart';
import 'package:app_hiker/src/utils/step_detector.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TrailStatus { idle, tracking, paused, finished }

class TrailPermissionException implements Exception {
  final String message;
  TrailPermissionException(this.message);

  @override
  String toString() => message;
}

// Records the trail in progress (RF24-RF26): steps from the accelerometer and the
// route from the GPS. The state is saved on the device so a paused or finished trail
// survives the app being closed (RN25.1). It is tied to the account that started it, so
// another account logging in on the same phone doesn't get it.
class TrailTracker extends ChangeNotifier {
  TrailTracker._();
  static final instance = TrailTracker._();

  static const _storageKey = 'current_trail';
  // GPS fixes worse than this are ignored, they make the distance jump.
  static const _maxAccuracyM = 30.0;
  static const _distanceFilterM = 5;

  final _stepDetector = StepDetector();
  final _geocoding = Geocoding(locale: const Locale('pt', 'BR'));

  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<Position>? _positionSub;
  Timer? _saveDebounce;

  TrailStatus status = TrailStatus.idle;
  int steps = 0;
  double distanceM = 0;
  TrailRoute route = [];
  DateTime? startedAt;
  String? cidade;
  String? estado;
  Duration _elapsedBeforeRun = Duration.zero;
  DateTime? _runStartedAt;
  // Id of the user that started the trail.
  String? _ownerId;

  Duration get elapsed => _runStartedAt == null
      ? _elapsedBeforeRun
      : _elapsedBeforeRun + DateTime.now().difference(_runStartedAt!);

  bool get hasTrail => status != TrailStatus.idle;

  Future<void> start() async {
    if (status != TrailStatus.idle) return;
    await _ensureLocationPermission();
    _ownerId = await currentUserId();
    startedAt = DateTime.now();
    await _run();
  }

  Future<void> resume() async {
    if (status != TrailStatus.paused) return;
    await _ensureLocationPermission();
    await _run();
  }

  // RF25: stops counting but keeps steps, distance and route.
  Future<void> pause() async {
    if (status != TrailStatus.tracking) return;
    await _stopSensors();
    status = TrailStatus.paused;
    notifyListeners();
    await _save();
  }

  // RF26: the trail waits on the device until it is saved or discarded.
  Future<void> finish() async {
    if (status != TrailStatus.tracking && status != TrailStatus.paused) return;
    await _stopSensors();
    status = TrailStatus.finished;
    notifyListeners();
    await _save();
  }

  Future<void> discard() async {
    await _stopSensors();
    status = TrailStatus.idle;
    steps = 0;
    distanceM = 0;
    route = [];
    startedAt = null;
    cidade = null;
    estado = null;
    _elapsedBeforeRun = Duration.zero;
    _ownerId = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  // Called on app start. A trail that was being tracked when the app died comes back paused.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final saved = TrailStatus.values.byName(json['status'] as String);
      status = saved == TrailStatus.tracking ? TrailStatus.paused : saved;
      steps = json['steps'] as int;
      distanceM = (json['distanceM'] as num).toDouble();
      route = parseRoute(json['route']);
      startedAt = DateTime.parse(json['startedAt'] as String);
      cidade = json['cidade'] as String?;
      estado = json['estado'] as String?;
      _elapsedBeforeRun = Duration(seconds: json['elapsedS'] as int);
      _ownerId = json['ownerId'] as String?;
      notifyListeners();
    } catch (e) {
      debugPrint('Could not restore the trail in progress: $e');
    }
  }

  // Called when a session starts. A trail left by another account is thrown away.
  Future<void> claimFor(String? userId) async {
    if (!hasTrail || userId == null) return;
    if (_ownerId == null) {
      // Trail saved before the owner was recorded: it stays with whoever logs in.
      _ownerId = userId;
      await _save();
    } else if (_ownerId != userId) {
      await discard();
    }
  }

  Future<void> _run() async {
    route.add([]);
    _stepDetector.reset();
    _runStartedAt = DateTime.now();
    status = TrailStatus.tracking;
    notifyListeners();

    _accelerometerSub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((event) {
      final confirmed = _stepDetector.addSample(event.x, event.y, event.z, event.timestamp);
      if (confirmed > 0) {
        steps += confirmed;
        notifyListeners();
        _scheduleSave();
      }
    });

    _positionSub = Geolocator.getPositionStream(locationSettings: _locationSettings()).listen(
      _onPosition,
      onError: (Object e) => debugPrint('GPS error: $e'),
    );
    await _save();
  }

  void _onPosition(Position position) {
    if (position.accuracy > _maxAccuracyM) return;

    final point = LatLng(position.latitude, position.longitude);
    final segment = route.last;
    if (segment.isNotEmpty) {
      final last = segment.last;
      distanceM += Geolocator.distanceBetween(last.latitude, last.longitude, point.latitude, point.longitude);
    }
    segment.add(point);

    if (cidade == null && estado == null) _detectPlace(point);
    notifyListeners();
    _scheduleSave();
  }

  // Name of the place from the first GPS fix; the user can rename it when saving.
  Future<void> _detectPlace(LatLng point) async {
    cidade = '';
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isEmpty) return;
      final place = placemarks.first;
      cidade = [place.locality, place.subAdministrativeArea]
          .firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null);
      estado = place.administrativeArea;
      notifyListeners();
      _scheduleSave();
    } catch (e) {
      cidade = null;
      debugPrint('Reverse geocoding failed: $e');
    }
  }

  LocationSettings _locationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: _distanceFilterM,
        intervalDuration: const Duration(seconds: 2),
        // Keeps the GPS (and the app process, with the accelerometer) alive with the screen off.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Hiker',
          notificationText: 'Registrando sua trilha',
          notificationChannelName: 'Trilha em andamento',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: _distanceFilterM,
        activityType: ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: _distanceFilterM);
  }

  Future<void> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw TrailPermissionException('Ative a localização do celular para registrar a trilha.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw TrailPermissionException('Precisamos da sua localização para registrar o caminho da trilha.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw TrailPermissionException('A localização está bloqueada para o Hiker. Libere nas configurações do celular.');
    }
  }

  Future<void> _stopSensors() async {
    await _accelerometerSub?.cancel();
    await _positionSub?.cancel();
    _accelerometerSub = null;
    _positionSub = null;
    if (_runStartedAt != null) {
      _elapsedBeforeRun += DateTime.now().difference(_runStartedAt!);
      _runStartedAt = null;
    }
    _saveDebounce?.cancel();
  }

  void _scheduleSave() {
    if (_saveDebounce?.isActive ?? false) return;
    _saveDebounce = Timer(const Duration(seconds: 5), _save);
  }

  Future<void> _save() async {
    if (startedAt == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'status': status.name,
        'steps': steps,
        'distanceM': distanceM,
        'route': routeToJson(route),
        'startedAt': startedAt!.toIso8601String(),
        'cidade': cidade,
        'estado': estado,
        'elapsedS': elapsed.inSeconds,
        'ownerId': _ownerId,
      }),
    );
  }
}
