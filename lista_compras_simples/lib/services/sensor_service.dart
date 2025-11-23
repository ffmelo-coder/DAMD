import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  static final SensorService instance = SensorService._init();
  SensorService._init();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Function()? _onShake;
  Function()? _onLongShake;

  static const double _shakeThreshold = 15.0;
  static const Duration _shakeCooldown = Duration(milliseconds: 500);
  static const Duration _longShakeDuration = Duration(seconds: 6);
  static const Duration _maxShakePause = Duration(
    seconds: 1,
  ); // Pausa máxima permitida

  DateTime? _lastShakeTime;
  DateTime? _shakeStartTime;
  bool _isActive = false;
  bool _isShaking = false;
  Timer? _longShakeTimer;
  Timer? _shakePauseTimer;

  bool get isActive => _isActive;

  void startShakeDetection(Function() onShake, {Function()? onLongShake}) {
    if (_isActive) {
      print('⚠️ Detecção já ativa');
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
        print('❌ Erro no acelerômetro: $error');
      },
    );

    print('📱 Detecção de shake iniciada');
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

      // Cancela o timer de pausa se existir
      _shakePauseTimer?.cancel();

      if (!_isShaking) {
        // Primeiro shake - inicia o timer
        _isShaking = true;
        _shakeStartTime = now;
        print('🔳 Shake iniciado! Magnitude: ${magnitude.toStringAsFixed(2)}');

        _longShakeTimer?.cancel();
        _longShakeTimer = Timer(_longShakeDuration, () {
          if (_isShaking && _onLongShake != null) {
            print('🌀 Shake longo detectado (6 segundos)!');
            _onLongShake?.call();
            _resetShakeState();
          }
        });
      } else {
        // Shake contínuo - apenas atualiza o tempo
        print(
          '🔳 Shake contínuo... Magnitude: ${magnitude.toStringAsFixed(2)}',
        );
      }

      // Inicia timer para detectar pausa
      _shakePauseTimer?.cancel();
      _shakePauseTimer = Timer(_maxShakePause, () {
        // Se passou 1 segundo sem shake, cancela
        if (_isShaking) {
          print('⏹️ Shake interrompido (pausa detectada)');
          _resetShakeState();
        }
      });

      _onShake?.call();
    } else {
      // Se não está mais agitando, cancela o timer
      if (_isShaking && magnitude < _shakeThreshold * 0.3) {
        print('⏹️ Shake interrompido');
        _resetShakeState();
      }
    }
  }

  void _resetShakeState() {
    _isShaking = false;
    _shakeStartTime = null;
    _longShakeTimer?.cancel();
    _shakePauseTimer?.cancel();
    print('🔄 Estado de shake resetado');
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
    print('⏹️ Detecção de shake parada');
  }
}
