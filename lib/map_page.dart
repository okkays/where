import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
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

typedef _ShareAndLocation = ({Share share, ShareLocation location});

class _MapPageState extends State<MapPage> {
  bool showTimeAgo = false;
  bool isRefreshing = true;
  bool isUploading = false;
  List<Share> shares = [];
  Set<String> showUserMenu = {};

  List<ShareLocation> sortLocations(Share share) =>
      share.locations.sorted((l, r) => r.timestamp.compareTo(l.timestamp));

  Iterable<_ShareAndLocation> iterateShares(List<Share> shares) =>
      shares.expand(
        (share) =>
            sortLocations(share)
                .map((location) => (share: share, location: location)),
      );

  Iterable<_ShareAndLocation> iterateCurrentShares(List<Share> shares) =>
      shares.map(
        (share) => (
          share: share,
          location: share.locations
              .sorted((l, r) => r.timestamp.compareTo(l.timestamp))
              .first,
        ),
      );

  CameraFit fit = const CameraFit.coordinates(
    coordinates: [ll.LatLng(43.18449, -109.65367)],
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
    await refresh(updateFit: true);
  }

  void toggleTimeAgo() async {
    setState(() {
      showTimeAgo = !showTimeAgo;
    });
  }

  Future<void> refit() async {
    setState(() {
      showUserMenu.clear();
    });
    controller.fitCamera(fit);
    controller.move(controller.camera.center, controller.camera.zoom - 0.5);
  }

  Future<void> refresh({bool updateFit = false}) async {
    setState(() {
      isRefreshing = true;
    });
    final store = await Store.fromSettings();
    await store?.refreshSharesFromStore();
    final List<ll.LatLng> newCoordinates = [];
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
    final textTheme = TextTheme.of(context).labelMedium!;
    final textHeight = (textTheme.height ?? 20) * (textTheme.fontSize ?? 1);
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
                  color: share.image.color,
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
                    width: MediaQuery.of(context).size.width / 2,
                    height: textHeight * 2,
                    child: Column(
                      crossAxisAlignment: .center,
                      mainAxisAlignment: .center,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: BoxBorder.all(
                              color: Colors.black,
                              width: 1,
                            ),
                            color: Colors.white,
                            borderRadius: const .all(.circular(5)),
                          ),
                          child: Padding(
                            padding: const .all(4),
                            child: Text(
                              shareAndLocation.location.timestamp.timeAgo(),
                              style: mounted
                                  ? textTheme.copyWith(fontStyle: .italic)
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
                  width: MediaQuery.of(context).size.width / 2,
                  height: MediaQuery.of(context).size.height / 2,
                  child: Column(
                    spacing: 2,
                    crossAxisAlignment: .center,
                    mainAxisAlignment: .center,
                    children: [
                      Visibility(
                        visible: showUserMenu.contains(
                          shareAndLocation.share.storage,
                        ),
                        child: _MapBubble(
                          shareAndLocation: shareAndLocation,
                          onClosed: () {
                            setState(() {
                              showUserMenu.remove(
                                shareAndLocation.share.storage,
                              );
                            });
                          },
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            final key = shareAndLocation.share.storage;
                            showUserMenu.contains(key)
                                ? showUserMenu.remove(key)
                                : showUserMenu.add(key);
                          });
                          controller.fitCamera(
                            CameraFit.coordinates(
                              coordinates: [shareAndLocation.location.location],
                              maxZoom: 14,
                            ),
                          );
                        },
                        child: CircleAvatar(
                          backgroundColor: shareAndLocation.share.image.color,
                          child: shareAndLocation.share.image.avatar.isEmpty
                              ? const Icon(
                                  Icons.person_pin_circle,
                                  size: _avatarSize,
                                  color: Colors.white,
                                )
                              : FittedBox(
                                  fit: .cover,
                                  child: Text(
                                    shareAndLocation.share.image.avatar,
                                    style: TextStyle(
                                      color:
                                          shareAndLocation.share.image.color
                                                  .computeLuminance() >
                                              0.5
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: BoxBorder.all(color: Colors.black, width: 1),
                          color: Colors.white,
                          borderRadius: const .all(.circular(5)),
                        ),
                        child: Padding(
                          padding: const .all(4),
                          child: Text(
                            maxLines: 1,
                            shareAndLocation.share.name,
                            style: mounted ? textTheme : null,
                          ),
                        ),
                      ),
                      Visibility(
                        visible: showTimeAgo,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: BoxBorder.all(
                              color: Colors.black,
                              width: 1,
                            ),
                            color: Colors.white,
                            borderRadius: const .all(.circular(5)),
                          ),
                          child: Padding(
                            padding: const .all(4),
                            child: Text(
                              maxLines: 1,
                              '(${shareAndLocation.location.timestamp.timeAgo()})',
                              style: mounted
                                  ? textTheme.copyWith(fontStyle: .italic)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        RichAttributionWidget(
          alignment: .bottomLeft,
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
          right: 20,
          child: Column(
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

class _MapBubble extends StatelessWidget {
  final _ShareAndLocation shareAndLocation;
  final VoidCallback onClosed;
  final Color textColor;

  _MapBubble({required this.onClosed, required this.shareAndLocation})
    : textColor = shareAndLocation.share.image.color.computeLuminance() > 0.5
          ? Colors.black
          : Colors.white;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(bottom: 10),
    child: CustomPaint(
      painter: _MapBubblePainter(
        shareAndLocation: shareAndLocation,
        triangleSize: 10,
      ),
      child: Padding(
        padding: const .all(5),
        child: Column(
          children: [
            GestureDetector(
              onTap: () async {
                await MapLauncher.marker(
                  .coords(
                    shareAndLocation.location.location.latitude,
                    shareAndLocation.location.location.longitude,
                    title: shareAndLocation.share.name,
                  ),
                ).show();
              },
              child: Row(
                spacing: 5,
                children: [
                  Icon(Icons.directions, color: textColor),
                  Text('Get Directions', style: TextStyle(color: textColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MapBubblePainter extends CustomPainter {
  final double triangleSize;
  final _ShareAndLocation shareAndLocation;
  _MapBubblePainter({
    required this.shareAndLocation,
    required this.triangleSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.lineTo(0, 0);
    path.lineTo(0, size.height);

    path.lineTo((size.width / 2 - (triangleSize / 2)), size.height);
    path.lineTo((size.width / 2), size.height + triangleSize);
    path.lineTo((size.width / 2 + (triangleSize / 2)), size.height);

    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);

    final fill = Paint();
    fill.style = .fill;
    fill.color = shareAndLocation.share.image.color;

    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
