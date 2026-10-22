import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/overpass_service.dart';
import '../../data/osrm_route_service.dart';
import '../../models/driving_route.dart';
import '../../models/nearby_garage.dart';

class NearbyGaragesScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  const NearbyGaragesScreen(
      {super.key, required this.latitude, required this.longitude});

  @override
  State<NearbyGaragesScreen> createState() => _NearbyGaragesScreenState();
}

class _NearbyGaragesScreenState extends State<NearbyGaragesScreen> {
  final _service = OverpassService();
  final _routeService = OsrmRouteService();
  final _mapController = MapController();
  late Future<List<NearbyGarage>> _request;
  NearbyGarage? _selected;
  DrivingRoute? _route;
  bool _routeLoading = false;
  String? _routeError;
  int _routeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _request = _service.findGarages(widget.latitude, widget.longitude);
  }

  void _retry() {
    _routeRequestId++;
    setState(() {
      _selected = null;
      _route = null;
      _routeLoading = false;
      _routeError = null;
      _request = _service.findGarages(widget.latitude, widget.longitude);
    });
  }

  void _select(NearbyGarage garage) {
    _routeRequestId++;
    setState(() {
      _selected = garage;
      _route = null;
      _routeLoading = false;
      _routeError = null;
    });
    _mapController.move(LatLng(garage.latitude, garage.longitude), 15);
  }

  Future<void> _calculateRoute() async {
    final garage = _selected;
    if (garage == null || _routeLoading) return;
    final requestId = ++_routeRequestId;
    setState(() {
      _routeLoading = true;
      _route = null;
      _routeError = null;
    });
    try {
      final result = await _routeService.findDrivingRoute(
        startLatitude: widget.latitude,
        startLongitude: widget.longitude,
        endLatitude: garage.latitude,
        endLongitude: garage.longitude,
      );
      if (!mounted ||
          requestId != _routeRequestId ||
          _selected?.osmId != garage.osmId) {
        return;
      }
      setState(() => _route = result);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            requestId != _routeRequestId ||
            _selected?.osmId != garage.osmId) {
          return;
        }
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(result.coordinates),
          padding: const EdgeInsets.all(36),
        ));
      });
    } catch (error) {
      if (!mounted ||
          requestId != _routeRequestId ||
          _selected?.osmId != garage.osmId) {
        return;
      }
      setState(() {
        _routeError = error is OsrmException
            ? error.message
            : 'Le calcul de l’itinéraire a échoué. Réessayez.';
      });
    } finally {
      if (mounted && requestId == _routeRequestId) {
        setState(() => _routeLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Garages à proximité'),
          actions: [
            IconButton(
                onPressed: _retry,
                tooltip: 'Actualiser',
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: FutureBuilder<List<NearbyGarage>>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              final message = error is OverpassException
                  ? error.message
                  : 'Erreur inattendue (${error.runtimeType}). Vérifiez la connexion puis réessayez.';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.cloud_off,
                        size: 42, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer')),
                  ]),
                ),
              );
            }
            final garages = snapshot.data ?? const <NearbyGarage>[];
            if (garages.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.car_repair,
                        size: 42, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text('Aucun garage trouvé dans un rayon de 3 km.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualiser')),
                  ]),
                ),
              );
            }
            return Column(children: [
              SizedBox(
                height: 270,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                      initialCenter: LatLng(widget.latitude, widget.longitude),
                      initialZoom: 13),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.flutter_mobile_app',
                    ),
                    if (_route != null)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: _route!.coordinates,
                          color: AppColors.primaryBlue,
                          strokeWidth: 5,
                        ),
                      ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(widget.latitude, widget.longitude),
                        width: 42,
                        height: 42,
                        child: const Icon(Icons.warning_rounded,
                            color: Colors.red, size: 34),
                      ),
                      ...garages.map((garage) => Marker(
                            point: LatLng(garage.latitude, garage.longitude),
                            width: 42,
                            height: 48,
                            child: GestureDetector(
                              onTap: () => _select(garage),
                              child: Icon(Icons.location_on,
                                  color: _selected?.osmId == garage.osmId
                                      ? AppColors.redDark
                                      : AppColors.primaryBlue,
                                  size: 38),
                            ),
                          )),
                    ]),
                    RichAttributionWidget(attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors')
                    ]),
                  ],
                ),
              ),
              if (_selected != null) _selectedCard(_selected!),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      '${garages.length} garage${garages.length > 1 ? 's' : ''} • triés par distance',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: garages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final garage = garages[index];
                    final selected = _selected?.osmId == garage.osmId;
                    return Card(
                      color: selected ? AppColors.blueLight : Colors.white,
                      child: ListTile(
                        onTap: () => _select(garage),
                        leading: const Icon(Icons.car_repair,
                            color: AppColors.primaryBlue),
                        title: Text(garage.name ?? 'Garage sans nom',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            [
                              _distanceLabel(garage.distanceMetres),
                              if (garage.address != null) garage.address!,
                            ].join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
              ),
            ]);
          },
        ),
      );

  Widget _selectedCard(NearbyGarage garage) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(garage.name ?? 'Garage sans nom',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(_distanceLabel(garage.distanceMetres)),
          if (garage.address != null) Text('Adresse : ${garage.address}'),
          if (garage.phone != null) Text('Téléphone : ${garage.phone}'),
          if (garage.website != null) Text('Site web : ${garage.website}'),
          if (garage.openingHours != null)
            Text('Horaires indiqués : ${garage.openingHours}'),
          if (_route != null) ...[
            const SizedBox(height: 8),
            Text(
                'Distance routière : ${(_route!.distanceMetres / 1000).toStringAsFixed(1)} km'),
            Text('Durée estimée : ${_durationLabel(_route!.durationSeconds)}'),
          ],
          if (_routeLoading) ...[
            const SizedBox(height: 10),
            const Row(children: [
              SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Calcul de l’itinéraire…'),
            ]),
          ],
          if (_routeError != null) ...[
            const SizedBox(height: 8),
            Text(_routeError!,
                style: const TextStyle(color: AppColors.redDark)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _routeLoading ? null : _calculateRoute,
                  icon: const Icon(Icons.alt_route),
                  label: Text(_routeError == null
                      ? 'Calculer l’itinéraire'
                      : 'Réessayer'),
                ),
                TextButton.icon(
                  onPressed: () => _openDirections(garage),
                  icon: const Icon(Icons.directions),
                  label: const Text('Ouvrir la navigation'),
                ),
              ],
            ),
          ),
        ]),
      );

  Future<void> _openDirections(NearbyGarage garage) async {
    final route =
        '${widget.latitude},${widget.longitude};${garage.latitude},${garage.longitude}';
    final uri = Uri.https('www.openstreetmap.org', '/directions', {
      'engine': 'fossgis_osrm_car',
      'route': route,
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Impossible d’ouvrir une application de carte.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Impossible d’ouvrir une application de carte.')));
      }
    }
  }

  String _distanceLabel(double metres) => metres < 1000
      ? '${metres.round()} m'
      : '${(metres / 1000).toStringAsFixed(1)} km';

  String _durationLabel(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? '$hours h'
        : '$hours h $remainingMinutes min';
  }
}
