import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:where/share.dart';
import 'package:where/store.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    Share.iterateOverDb().forEach((s) => print(s));

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(43.18449, -109.65367),
        initialZoom: 9.2,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.okkays.where',
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () =>
                  launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
            ),
          ],
        ),
        Positioned(
          bottom: MediaQuery.of(context).viewInsets.bottom + 40,
          left: 20,
          child: FloatingActionButton(
            onPressed: () async {
              final store = await Store.fromSettings();
              await store?.refreshSharesFromStore();
              Share.iterateOverDb().forEach((s) => print(s));
            },
            child: Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }
}
