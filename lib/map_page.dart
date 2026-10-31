import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:where/share.dart';
import 'package:where/store.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<StatefulWidget> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  bool isRefreshing = true;
  bool isUploading = false;

  @override
  void initState() {
    refresh();
    super.initState();
  }

  Future<void> refresh() async {
    setState(() {
      isRefreshing = true;
    });
    final store = await Store.fromSettings();
    await store?.refreshSharesFromStore();
    Share.iterateOverDb().forEach((s) => print(s));
    setState(() {
      isRefreshing = false;
    });
  }

  Future<void> upload() async {
    setState(() {
      isUploading = true;
    });
    final store = await Store.fromSettings();
    if (store == null) return;
    final location = await ShareLocation.fromLocation(fresh: true);
    if (location == null) return;
    final mine = await store.getOrCreateMyShare();
    if (mine == null) return;

    await store.updateMyShare(mine..locations.add(location));
    setState(() {
      isUploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          child: Row(
            spacing: 10,
            children: [
              FloatingActionButton(
                onPressed: isUploading ? null : upload,
                backgroundColor: isUploading ? Colors.orange.shade100 : null,
                child: isUploading
                    ? Icon(Icons.hourglass_top, color: Colors.orange.shade800)
                    : Icon(Icons.cloud_upload),
              ),
              FloatingActionButton(
                backgroundColor: isRefreshing ? Colors.orange.shade100 : null,
                onPressed: isRefreshing ? null : refresh,
                child: isRefreshing
                    ? Icon(Icons.hourglass_top, color: Colors.orange.shade800)
                    : Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
