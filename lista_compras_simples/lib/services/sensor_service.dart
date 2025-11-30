import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';

class SensorService {
  static final SensorService instance = SensorService._init();
  SensorService._init();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Function()? _onShake;
  Function()? _onLongShake;

  static const double _shakeThreshold = 15.0;
  static const Duration _shakeCooldown = Duration(milliseconds: 500);
  static const Duration _longShakeDuration = Duration(seconds: 6);
  static const Duration _maxShakePause = Duration(seconds: 1);

  DateTime? _lastShakeTime;
  bool _isActive = false;
  bool _isShaking = false;
  Timer? _longShakeTimer;
  Timer? _shakePauseTimer;

  bool get isActive => _isActive;

  void startShakeDetection(Function() onShake, {Function()? onLongShake}) {
    if (_isActive) {
      debugPrint('⚠️ Detecção já ativa');
      return;
    }

    _onShake = onShake;
    _onLongShake = onLongShake;
    _isActive = true;

    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        _detectShake(event);
      },
      onError: (error) {
        debugPrint('❌ Erro no acelerômetro: $error');
      },
    );

    debugPrint('📱 Detecção de shake iniciada');
  }

  void _detectShake(AccelerometerEvent event) {
    final now = DateTime.now();

    if (_lastShakeTime != null &&
        now.difference(_lastShakeTime!) < _shakeCooldown) {
      return;
    }

    final double magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude > _shakeThreshold) {
      _lastShakeTime = now;

      _shakePauseTimer?.cancel();

      if (!_isShaking) {
        _isShaking = true;
        debugPrint(
          '🔳 Shake iniciado! Magnitude: ${magnitude.toStringAsFixed(2)}',
        );

        _longShakeTimer?.cancel();
        _longShakeTimer = Timer(_longShakeDuration, () {
          if (_isShaking && _onLongShake != null) {
            debugPrint('🌀 Shake longo detectado (6 segundos)!');
            _onLongShake?.call();
            _resetShakeState();
          }
        });
      } else {
        debugPrint(
          '🔳 Shake contínuo... Magnitude: ${magnitude.toStringAsFixed(2)}',
        );
      }

      _shakePauseTimer?.cancel();
      _shakePauseTimer = Timer(_maxShakePause, () {
        if (_isShaking) {
          debugPrint('⏹️ Shake interrompido (pausa detectada)');
          _resetShakeState();
        }
      });

      _onShake?.call();
    } else {
      if (_isShaking && magnitude < _shakeThreshold * 0.3) {
        debugPrint('⏹️ Shake interrompido');
        _resetShakeState();
      }
    }
  }

  void _resetShakeState() {
    _isShaking = false;
    _longShakeTimer?.cancel();
    _shakePauseTimer?.cancel();
    debugPrint('🔄 Estado de shake resetado');
  }

  void stop() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _longShakeTimer?.cancel();
    _longShakeTimer = null;
    _shakePauseTimer?.cancel();
    _shakePauseTimer = null;
    _onShake = null;
    _onLongShake = null;
    _isActive = false;
    _isShaking = false;
    debugPrint('⏹️ Detecção de shake parada');
  }
}
