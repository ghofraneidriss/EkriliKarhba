import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/nearby_garage.dart';

class OverpassService {
  static const endpoint = 'https://overpass-api.de/api/interpreter';
  static const radiusMetres = 3000;

  Future<List<NearbyGarage>> findGarages(
      double latitude, double longitude) async {
    final query = '[out:json][timeout:25];('
        'node["shop"="car_repair"](around:$radiusMetres,$latitude,$longitude);'
        'way["shop"="car_repair"](around:$radiusMetres,$latitude,$longitude);'
        'relation["shop"="car_repair"](around:$radiusMetres,$latitude,$longitude);'
        'node["amenity"="car_repair"](around:$radiusMetres,$latitude,$longitude);'
        'way["amenity"="car_repair"](around:$radiusMetres,$latitude,$longitude);'
        'relation["amenity"="car_repair"](around:$radiusMetres,$latitude,$longitude);'
        'node["shop"="car"](around:$radiusMetres,$latitude,$longitude);'
        'way["shop"="car"](around:$radiusMetres,$latitude,$longitude);'
        'relation["shop"="car"](around:$radiusMetres,$latitude,$longitude);'
        ');out center tags;';

    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse(endpoint),
        headers: const {'Accept': 'application/json'},
        body: {'data': query},
      ).timeout(const Duration(seconds: 35));
      if (response.statusCode == 429 ||
          response.statusCode == 503 ||
          response.statusCode == 504 ||
          response.statusCode >= 500) {
        throw const OverpassException(
            'Le service de recherche est temporairement chargé. Réessayez dans quelques instants.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const OverpassException(
            'La recherche de garages a échoué. Vous pouvez réessayer.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['elements'] is! List) {
        throw const OverpassException(
            'La réponse du service est invalide. Réessayez.');
      }
      final seen = <String>{};
      final results = <NearbyGarage>[];
      for (final dynamic element in decoded['elements'] as List) {
        if (element is! Map) continue;
        final type = element['type']?.toString();
        final id = element['id']?.toString();
        if (type == null || id == null || !seen.add('$type/$id')) continue;
        final lat =
            _number(element['lat'] ?? (element['center'] as Map?)?['lat']);
        final lon =
            _number(element['lon'] ?? (element['center'] as Map?)?['lon']);
        if (lat == null ||
            lon == null ||
            lat < -90 ||
            lat > 90 ||
            lon < -180 ||
            lon > 180) {
          continue;
        }
        final tags = element['tags'] is Map ? element['tags'] as Map : const {};
        final distance = _distanceMetres(latitude, longitude, lat, lon);
        results.add(NearbyGarage(
          osmType: type,
          osmId: id,
          latitude: lat,
          longitude: lon,
          distanceMetres: distance,
          name: _first(tags, ['name']),
          address: _address(tags),
          phone: _first(tags, ['phone', 'contact:phone']),
          website: _first(tags, ['website', 'contact:website']),
          openingHours: _first(tags, ['opening_hours']),
        ));
      }
      results.sort((a, b) => a.distanceMetres.compareTo(b.distanceMetres));
      return results.take(20).toList();
    } on OverpassException {
      rethrow;
    } on http.ClientException {
      throw const OverpassException(
          'Connexion au service impossible. Vérifiez Internet puis réessayez.');
    } on TimeoutException {
      throw const OverpassException(
          'La recherche a pris trop de temps. Vous pouvez réessayer.');
    } on FormatException {
      throw const OverpassException(
          'La réponse du service est invalide. Réessayez.');
    } on Exception {
      throw const OverpassException(
          'La recherche a pris trop de temps. Vous pouvez réessayer.');
    } catch (_) {
      throw const OverpassException(
          'La recherche a échoué. Vérifiez votre connexion puis réessayez.');
    } finally {
      client.close();
    }
  }

  static double? _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  static String? _first(Map tags, List<String> keys) {
    for (final key in keys) {
      final value = tags[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _address(Map tags) {
    final full = _first(tags, ['addr:full']);
    if (full != null) return full;
    final parts = [
      _first(tags, ['addr:housenumber']),
      _first(tags, ['addr:street']),
      _first(tags, ['addr:postcode']),
      _first(tags, ['addr:city']),
    ].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  static double _distanceMetres(
      double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}

class OverpassException implements Exception {
  final String message;
  const OverpassException(this.message);
  @override
  String toString() => message;
}
