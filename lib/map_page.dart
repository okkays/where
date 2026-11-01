import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:where/settings.dart';
import 'package:where/share.dart';
import 'package:where/store.dart';
import 'package:where/util.dart';

const double _avatarSize = 40;
const Duration updateDuration = Duration(seconds: 10);

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

  CameraFit fit = CameraFit.coordinates(
    coordinates: [LatLng(43.18449, -109.65367)],
    maxZoom: 12,
  );

  MapController controller = MapController();

  late Timer updateTimer;

  @override
  void initState() {
    updateTimer = Timer.periodic(updateDuration, (timer) => refresh());
    initAsync();
    super.initState();
  }

  @override
  void dispose() {
    updateTimer.cancel();
    super.dispose();
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

  Future<void> refit() async {
    controller.fitCamera(fit);
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

      newMarkers.addAll(
        sortedLocations.getRange(1, sortedLocations.length).map((location) {
          return Marker(
            point: location.location,
            width: _avatarSize * 3,
            height: _avatarSize * 1,
            child: Column(
              crossAxisAlignment: .center,
              mainAxisAlignment: .center,
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: .all(.circular(5)),
                  ),
                  child: Padding(
                    padding: .all(4),
                    child: Text(
                      location.timestamp.timeAgo(),
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      );

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
    fit = CameraFit.coordinates(coordinates: newCoordinates, maxZoom: 12);
    if (updateFit && newCoordinates.isNotEmpty) {
      controller.fitCamera(fit);
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
    await store.upload(fresh: true);
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
        initialCameraFit: fit,
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
                heroTag: null,
                backgroundColor: isRefreshing ? Colors.orange.shade100 : null,
                onPressed: isRefreshing ? null : refresh,
                child: isRefreshing
                    ? Icon(Icons.hourglass_top, color: Colors.orange.shade800)
                    : Icon(Icons.refresh),
              ),
              FloatingActionButton(
                heroTag: null,
                onPressed: refit,
                child: Icon(Icons.fit_screen),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
