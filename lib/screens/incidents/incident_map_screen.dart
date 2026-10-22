import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class IncidentMapScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final bool requireExplicitSelection;

  const IncidentMapScreen(
      {super.key,
      this.initialLatitude,
      this.initialLongitude,
      this.requireExplicitSelection = false});

  @override
  State<IncidentMapScreen> createState() => _IncidentMapScreenState();
}

class _IncidentMapScreenState extends State<IncidentMapScreen> {
  // Default location: Tunis, Tunisia.
  late LatLng selectedLocation;
  bool _hasExplicitSelection = false;

  @override
  void initState() {
    super.initState();
    final lat = widget.initialLatitude;
    final lon = widget.initialLongitude;
    selectedLocation = lat != null &&
            lon != null &&
            lat >= -90 &&
            lat <= 90 &&
            lon >= -180 &&
            lon <= 180
        ? LatLng(lat, lon)
        : const LatLng(36.8065, 10.1815);
    _hasExplicitSelection = lat != null &&
        lon != null &&
        lat >= -90 &&
        lat <= 90 &&
        lon >= -180 &&
        lon <= 180;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Localisation de l’incident'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: selectedLocation,
                initialZoom: 13,
                onTap: (tapPosition, point) {
                  setState(() {
                    selectedLocation = point;
                    _hasExplicitSelection = true;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // Replace with your real Android application ID.
                  userAgentPackageName: 'com.example.flutter_mobile_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLocation,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 42,
                      ),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.requireExplicitSelection && !_hasExplicitSelection
                        ? 'Touchez la carte pour choisir le lieu de l’incident'
                        : 'Position sélectionnée',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Latitude : '
                    '${selectedLocation.latitude.toStringAsFixed(6)}',
                  ),
                  Text(
                    'Longitude : '
                    '${selectedLocation.longitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.requireExplicitSelection &&
                              !_hasExplicitSelection
                          ? null
                          : () {
                              Navigator.pop<Map<String, double>>(
                                context,
                                {
                                  'latitude': selectedLocation.latitude,
                                  'longitude': selectedLocation.longitude,
                                },
                              );
                            },
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmer la position'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
