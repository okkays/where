import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:where/settings.dart';
import 'package:where/share.dart';
import 'package:where/store.dart';

const double _avatarSize = 40;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<StatefulWidget> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  bool isRefreshing = true;
  bool isUploading = false;
  List<Polyline> polylines = [];

  List<Marker> markers = [];

  List<Share> shares = [];
  Map<String, Color> colors = {};

  MapController controller = MapController();

  @override
  void initState() {
    initAsync();
    super.initState();
  }

  Future<void> initAsync() async {
    await initFromSettings();
    await refresh(updateFit: true);
  }

  Future<void> initFromSettings() async {
    final settings = await Settings.getSingleton();
    if (settings.storage != null) {
      colors[settings.storage!] = Colors.blue;
    }
    colors.addEntries(
      settings.friends.mapIndexed(
        (index, storage) => MapEntry(
          storage,
          Colors.primaries[index % Colors.primaries.length],
        ),
      ),
    );
  }

  Future<void> refresh({bool updateFit = false}) async {
    setState(() {
      isRefreshing = true;
    });
    final store = await Store.fromSettings();
    await store?.refreshSharesFromStore();
    final List<Polyline> newPolylines = [];
    final List<Marker> newMarkers = [];
    final List<LatLng> newCoordinates = [];
    await Share.iterateOverDb().forEach((share) {
      print(share);
      if (share.locations.isEmpty) return;
      final sortedLocations = share.locations.sorted(
        (l, r) => r.timestamp.compareTo(l.timestamp),
      );
      final color = colors.containsKey(share.storage)
          ? colors[share.storage]
          : Colors.grey;

      newMarkers.add(
        Marker(
          point: sortedLocations.first.location,
          width: _avatarSize * 4,
          height: _avatarSize * 3,
          child: Column(
            spacing: 2,
            crossAxisAlignment: .center,
            mainAxisAlignment: .center,
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(
                  Icons.person_pin_circle,
                  size: _avatarSize,
                  color: Colors.white,
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: .all(.circular(5)),
                ),
                child: Padding(
                  padding: .all(4),
                  child: Text(
                    share.name,
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      newCoordinates.addAll(sortedLocations.map((l) => l.location));

      newPolylines.add(
        Polyline(
          points: sortedLocations.map((l) => l.location).toList(),
          color: color ?? Colors.grey,
        ),
      );
    });
    print('POINTS: ${newCoordinates.length}');
    if (updateFit && newCoordinates.isNotEmpty) {
      controller.fitCamera(
        CameraFit.coordinates(coordinates: newCoordinates, maxZoom: 12),
      );
    }
    setState(() {
      markers = newMarkers;
      polylines = newPolylines;
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
    mine
      ..locations.add(location)
      ..updated = DateTime.now().toUtc();

    await mine.save();
    await store.updateMyShare(mine);
    await refresh();
    setState(() {
      isUploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: [LatLng(43.18449, -109.65367)],
          maxZoom: 12,
        ),
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.okkays.where',
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
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
                heroTag: null,
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
