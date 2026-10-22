import 'package:latlong2/latlong.dart';

class DrivingRoute {
  final List<LatLng> coordinates;
  final double distanceMetres;
  final double durationSeconds;

  const DrivingRoute({
    required this.coordinates,
    required this.distanceMetres,
    required this.durationSeconds,
  });
}
