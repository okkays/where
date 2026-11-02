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
  bool showTimeAgo = false;
  bool isRefreshing = true;
  bool isUploading = false;
  List<Polyline> polylines = [];

  List<Marker> markers = [];
  List<Marker> timeAgoLabels = [];

  List<Share> shares = [];
  Map<String, Color> colors = {};

  CameraFit fit = const CameraFit.coordinates(
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

  void toggleTimeAgo() async {
    setState(() {
      showTimeAgo = !showTimeAgo;
    });
    await refresh();
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
    controller.move(controller.camera.center, controller.camera.zoom - 0.5);
  }

  Future<void> refresh({bool updateFit = false}) async {
    setState(() {
      isRefreshing = true;
    });
    final store = await Store.fromSettings();
    await store?.refreshSharesFromStore();
    final List<Polyline> newPolylines = [];
    final List<Marker> newMarkers = [];
    final List<Marker> newTimeAgoLabels = [];
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

      newTimeAgoLabels.addAll(
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
                    padding: const .all(4),
                    child: Text(
                      location.timestamp.timeAgo(),
                      style: mounted
                          ? TextTheme.of(context).labelMedium!
                                .copyWith(fontStyle: .italic)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      );

      final nowLocation = sortedLocations.first;
      newMarkers.add(
        Marker(
          point: nowLocation.location,
          width: _avatarSize * 4,
          height: _avatarSize * 4,
          child: GestureDetector(
            onTap: () {
              controller.fitCamera(
                CameraFit.coordinates(
                  coordinates: [nowLocation.location],
                  maxZoom: 14,
                ),
              );
            },
            child: Column(
              spacing: 2,
              crossAxisAlignment: .center,
              mainAxisAlignment: .center,
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  child: const Icon(
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
                    padding: const .all(4),
                    child: Text(
                      share.name,
                      style: mounted ? TextTheme.of(context).labelLarge : null,
                    ),
                  ),
                ),
                Visibility(
                  visible: showTimeAgo,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: .all(.circular(5)),
                    ),
                    child: Padding(
                      padding: const .all(4),
                      child: Text(
                        '(${nowLocation.timestamp.timeAgo()})',
                        style: mounted
                            ? TextTheme.of(context).labelMedium!
                                  .copyWith(fontStyle: .italic)
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      newCoordinates.addAll(sortedLocations.map((l) => l.location));

      newPolylines.add(
        Polyline(
          points: sortedLocations.map((l) => l.location).toList(),
          color: color ?? Colors.grey,
          strokeWidth: 5,
        ),
      );
    });
    print('POINTS: ${newCoordinates.length}');
    fit = CameraFit.coordinates(coordinates: newCoordinates, maxZoom: 12);
    if (updateFit && newCoordinates.isNotEmpty) {
      controller.fitCamera(fit);
      controller.move(controller.camera.center, controller.camera.zoom - 0.5);
    }
    setState(() {
      markers = newMarkers;
      timeAgoLabels = newTimeAgoLabels;
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
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.okkays.where',
        ),
        PolylineLayer(polylines: polylines),
        Visibility(
          visible: showTimeAgo,
          child: MarkerLayer(markers: timeAgoLabels),
        ),
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
                    : const Icon(Icons.cloud_upload),
              ),
              FloatingActionButton(
                heroTag: null,
                backgroundColor: isRefreshing ? Colors.orange.shade100 : null,
                onPressed: isRefreshing ? null : refresh,
                child: isRefreshing
                    ? Icon(Icons.hourglass_top, color: Colors.orange.shade800)
                    : const Icon(Icons.refresh),
              ),
              FloatingActionButton(
                heroTag: null,
                onPressed: refit,
                child: const Icon(Icons.fit_screen),
              ),
              FloatingActionButton(
                backgroundColor: !showTimeAgo ? Colors.grey.shade300 : null,
                heroTag: null,
                onPressed: toggleTimeAgo,
                child: !showTimeAgo
                    ? Icon(
                        Icons.history_toggle_off,
                        color: Colors.grey.shade600,
                      )
                    : const Icon(Icons.schedule),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
