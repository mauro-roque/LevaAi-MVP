import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'api.dart';
import 'ui.dart';
import 'open_link_stub.dart' if (dart.library.js_interop) 'open_link_web.dart';

/// Exibe uma prévia visual da rota sem tornar o mapa uma dependência crítica.
class RouteMap extends StatelessWidget {
  final Json route;
  const RouteMap({super.key, required this.route});
  @override
  Widget build(BuildContext context) {
    final points =
        (route['coordinates'] as List)
            .map(
              (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
            )
            .toList();
    if (route['demo'] == true) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFEDF3FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trip_origin, color: blue),
                SizedBox(width: 14),
                Text('────────────', style: TextStyle(color: blue)),
                SizedBox(width: 14),
                Icon(Icons.location_on, color: blue),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              '${decimal(route['distanceKm'])} km • percurso de exemplo',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Distância simulada para demonstração.\nDesative o exemplo para calcular uma rota real.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 300,
        child: FlutterMap(
          key: ValueKey(points.toString()),
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(38),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'br.com.levaai.mvp',
            ),
            PolylineLayer(
              polylines: [
                Polyline(points: points, strokeWidth: 5, color: blue),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: points.first,
                  child: const Icon(Icons.trip_origin, color: blue, size: 30),
                ),
                Marker(
                  point: points.last,
                  child: const Icon(Icons.location_on, color: blue, size: 36),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: ColoredBox(
                color: Colors.white,
                child: InkWell(
                  onTap: () {
                    const url = 'https://www.openstreetmap.org/copyright';
                    if (!openLink(url)) {
                      showDialog<void>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Créditos do mapa'),
                              content: const SelectableText(url),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Fechar'),
                                ),
                              ],
                            ),
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      '© OpenStreetMap contributors • OSRM',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
