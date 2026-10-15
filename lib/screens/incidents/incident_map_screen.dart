import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class IncidentMapScreen extends StatefulWidget {
  const IncidentMapScreen({super.key});

  @override
  State<IncidentMapScreen> createState() =>
      _IncidentMapScreenState();
}

class _IncidentMapScreenState extends State<IncidentMapScreen> {
  // Example incident location in Tunis.
  LatLng selectedLocation = const LatLng(36.8065, 10.1815);

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
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ekrili_karhba',
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
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Position sélectionnée',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Latitude : ${selectedLocation.latitude.toStringAsFixed(6)}',
                ),
                Text(
                  'Longitude : ${selectedLocation.longitude.toStringAsFixed(6)}',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, {
                        'latitude': selectedLocation.latitude,
                        'longitude': selectedLocation.longitude,
                      });
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmer la position'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}