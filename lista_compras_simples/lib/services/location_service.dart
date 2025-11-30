import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';

class LocationService {
  static final LocationService instance = LocationService._init();
  LocationService._init();

  final Map<String, GeofenceRegion> _geofences = {};
  StreamSubscription<Position>? _positionStream;
  Function(String geofenceId, bool entered)? _onGeofenceEvent;

  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('⚠️ Serviço de localização desabilitado');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ Permissão negada');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('⚠️ Permissão negada permanentemente');
      return false;
    }

    debugPrint('✅ Permissão de localização concedida');
    return true;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('❌ Erro ao obter localização: $e');
      return null;
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  String formatCoordinates(double lat, double lon) {
    return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
  }

  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return await _getAddressFromNominatim(lat, lon);
      }

      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].where((p) => p != null && p.isNotEmpty).take(3);

        return parts.join(', ');
      }
    } catch (e) {
      debugPrint('❌ Erro ao obter endereço: $e');
    }
    return null;
  }

  Future<Position?> getLocationFromAddress(String address) async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return await _getLocationFromNominatim(address);
      }

      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao buscar endereço: $e');
    }
    return null;
  }

  Future<String?> _getAddressFromNominatim(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterApp/1.0 (Lista de Compras)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];

        final parts = <String>[];
        if (address['road'] != null) parts.add(address['road']);
        if (address['suburb'] != null) parts.add(address['suburb']);
        if (address['city'] != null) parts.add(address['city']);
        if (address['state'] != null) parts.add(address['state']);

        return parts.take(3).join(', ');
      }
    } catch (e) {
      debugPrint('❌ Erro ao obter endereço do Nominatim: $e');
    }
    return null;
  }

  Future<Position?> _getLocationFromNominatim(String address) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterApp/1.0 (Lista de Compras)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final location = data.first;
          final lat = double.parse(location['lat']);
          final lon = double.parse(location['lon']);

          return Position(
            latitude: lat,
            longitude: lon,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao buscar endereço no Nominatim: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCurrentLocationWithAddress() async {
    try {
      final position = await getCurrentLocation();
      if (position == null) return null;

      final address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return {
        'position': position,
        'address': address ?? 'Endereço não disponível',
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      debugPrint('❌ Erro: $e');
      return null;
    }
  }

  void addGeofence(String id, double lat, double lon, double radiusMeters) {
    _geofences[id] = GeofenceRegion(
      id: id,
      latitude: lat,
      longitude: lon,
      radius: radiusMeters,
    );
    debugPrint('✅ Geofence adicionada: $id');
  }

  void removeGeofence(String id) {
    _geofences.remove(id);
    debugPrint('🗑️ Geofence removida: $id');
  }

  void startGeofenceMonitoring(
    Function(String geofenceId, bool entered) onEvent,
  ) {
    if (_positionStream != null) {
      debugPrint('⚠️ Monitoramento já ativo');
      return;
    }

    _onGeofenceEvent = onEvent;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _checkGeofences(position);
          },
        );

    debugPrint('📍 Monitoramento de geofencing iniciado');
  }

  final Map<String, bool> _insideGeofence = {};

  void _checkGeofences(Position position) async {
    for (final entry in _geofences.entries) {
      final geofence = entry.value;
      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        geofence.latitude,
        geofence.longitude,
      );

      final isInside = distance <= geofence.radius;
      final wasInside = _insideGeofence[geofence.id] ?? false;

      if (isInside != wasInside) {
        _insideGeofence[geofence.id] = isInside;
        _onGeofenceEvent?.call(geofence.id, isInside);

        final locationName =
            await getAddressFromCoordinates(
              geofence.latitude,
              geofence.longitude,
            ) ??
            'Local definido';

        if (isInside) {
          await NotificationService.instance.showGeofenceNotification(
            title: '📍 Você entrou na área!',
            body: 'Você está próximo de: $locationName',
            payload: geofence.id,
          );
          debugPrint('🔔 Geofence ${geofence.id}: Entrou - $locationName');
        } else {
          await NotificationService.instance.showGeofenceNotification(
            title: '🚶 Você saiu da área',
            body: 'Você se afastou de: $locationName',
            payload: geofence.id,
          );
          debugPrint('🔔 Geofence ${geofence.id}: Saiu - $locationName');
        }
      }
    }
  }

  void stopGeofenceMonitoring() {
    _positionStream?.cancel();
    _positionStream = null;
    _onGeofenceEvent = null;
    _insideGeofence.clear();
    debugPrint('⏹️ Monitoramento de geofencing parado');
  }
}

class GeofenceRegion {
  final String id;
  final double latitude;
  final double longitude;
  final double radius;

  GeofenceRegion({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
}
