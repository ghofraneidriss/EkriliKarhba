import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/driving_route.dart';

class OsrmRouteService {
  static const _host = 'router.project-osrm.org';

  Future<DrivingRoute> findDrivingRoute({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) async {
    _validateCoordinate(startLatitude, startLongitude);
    _validateCoordinate(endLatitude, endLongitude);

    final uri = Uri.parse(
      'https://$_host/route/v1/driving/'
      '$startLongitude,$startLatitude;$endLongitude,$endLatitude'
      '?overview=full&geometries=geojson&steps=false',
    );
    final client = http.Client();
    try {
      final response = await client.get(uri, headers: const {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 30));
      if (response.statusCode == 429 || response.statusCode >= 500) {
        throw const OsrmException(
            'Le service d’itinéraire est temporairement indisponible. Réessayez.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const OsrmException(
            'Impossible de calculer cet itinéraire. Réessayez.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map ||
          decoded['code'] != 'Ok' ||
          decoded['routes'] is! List) {
        throw const OsrmException(
            'Aucun itinéraire routier disponible pour ce garage.');
      }
      final routes = decoded['routes'] as List;
      if (routes.isEmpty || routes.first is! Map) {
        throw const OsrmException(
            'Aucun itinéraire routier disponible pour ce garage.');
      }
      final route = routes.first as Map;
      final distance = _number(route['distance']);
      final duration = _number(route['duration']);
      final geometry = route['geometry'];
      if (distance == null ||
          duration == null ||
          geometry is! Map ||
          geometry['coordinates'] is! List) {
        throw const OsrmException(
            'La réponse du service d’itinéraire est invalide.');
      }

      final points = <LatLng>[];
      for (final dynamic pair in geometry['coordinates'] as List) {
        if (pair is! List || pair.length < 2) continue;
        final longitude = _number(pair[0]);
        final latitude = _number(pair[1]);
        if (longitude == null ||
            latitude == null ||
            !_isValid(latitude, longitude)) {
          continue;
        }
        points.add(LatLng(latitude, longitude));
      }
      if (points.length < 2) {
        throw const OsrmException('La géométrie de l’itinéraire est invalide.');
      }
      return DrivingRoute(
          coordinates: points,
          distanceMetres: distance,
          durationSeconds: duration);
    } on OsrmException {
      rethrow;
    } on http.ClientException {
      throw const OsrmException(
          'La connexion au service a échoué. Vérifiez Internet puis réessayez.');
    } on TimeoutException {
      throw const OsrmException(
          'Le calcul de l’itinéraire a pris trop de temps. Réessayez.');
    } on FormatException {
      throw const OsrmException(
          'La réponse du service d’itinéraire est invalide.');
    } catch (_) {
      throw const OsrmException(
          'Le calcul de l’itinéraire a échoué. Vérifiez votre connexion puis réessayez.');
    } finally {
      client.close();
    }
  }

  static void _validateCoordinate(double latitude, double longitude) {
    if (!_isValid(latitude, longitude)) {
      throw const OsrmException(
          'Les coordonnées de l’incident ou du garage sont invalides.');
    }
  }

  static bool _isValid(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static double? _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
}

class OsrmException implements Exception {
  final String message;
  const OsrmException(this.message);

  @override
  String toString() => message;
}
