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
  List<Share> shares = [];
  Map<String, Color> colors = {};

  Color getColor(Share share) =>
      colors.containsKey(share.storage) ? colors[share.storage]! : Colors.grey;

  List<ShareLocation> sortLocations(Share share) =>
      share.locations.sorted((l, r) => r.timestamp.compareTo(l.timestamp));

  Iterable<({Share share, ShareLocation location, Color color})> iterateShares(
    List<Share> shares,
  ) => shares.expand(
    (share) => sortLocations(share).map(
      (location) => (share: share, location: location, color: getColor(share)),
    ),
  );

  Iterable<({Share share, ShareLocation location, Color color})>
  iterateCurrentShares(List<Share> shares) => shares.map(
    (share) => (
      share: share,
      location: share.locations
          .sorted((l, r) => r.timestamp.compareTo(l.timestamp))
          .first,
      color: getColor(share),
    ),
  );

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
    final List<LatLng> newCoordinates = [];
    final List<Share> newShares = [];
    await Share.iterateOverDb().forEach((share) {
      if (share.locations.isEmpty) return;
      newShares.add(share);
      newCoordinates.addAll(share.locations.map((l) => l.location));
    });
    print('POINTS: ${newCoordinates.length}');
    fit = CameraFit.coordinates(coordinates: newCoordinates, maxZoom: 12);
    if (updateFit && newCoordinates.isNotEmpty) {
      controller.fitCamera(fit);
      controller.move(controller.camera.center, controller.camera.zoom - 0.5);
    }
    setState(() {
      shares = newShares;
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
        PolylineLayer(
          polylines: shares
              .map(
                (share) => Polyline(
                  points: sortLocations(share).map((l) => l.location).toList(),
                  color: getColor(share),
                  strokeWidth: 5,
                ),
              )
              .toList(),
        ),
        Visibility(
          visible: showTimeAgo,
          child: MarkerLayer(
            markers: iterateShares(shares)
                .skip(1)
                .map<Marker>(
                  (shareAndLocation) => Marker(
                    point: shareAndLocation.location.location,
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
                              shareAndLocation.location.timestamp.timeAgo(),
                              style: mounted
                                  ? TextTheme.of(context).labelMedium!
                                        .copyWith(fontStyle: .italic)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        MarkerLayer(
          markers: iterateCurrentShares(shares)
              .map<Marker>(
                (shareAndLocation) => Marker(
                  point: shareAndLocation.location.location,
                  width: _avatarSize * 4,
                  height: _avatarSize * 4,
                  child: GestureDetector(
                    onTap: () {
                      controller.fitCamera(
                        CameraFit.coordinates(
                          coordinates: [shareAndLocation.location.location],
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
                          backgroundColor: shareAndLocation.color,
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
                              shareAndLocation.share.name,
                              style: mounted
                                  ? TextTheme.of(context).labelLarge
                                  : null,
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
                                '(${shareAndLocation.location.timestamp.timeAgo()})',
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
              )
              .toList(),
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
