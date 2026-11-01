import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsGeometry.only(left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: 40,
          children: [
            const Spacer(),
            Expanded(
              key: const Key('landing.map'),
              flex: 1,
              child: ElevatedButton(
                onPressed: () => context.go('/map'),
                child: Row(
                  mainAxisAlignment: .start,
                  crossAxisAlignment: .center,
                  spacing: 10,
                  children: [
                    const Padding(
                      padding: EdgeInsetsGeometry.fromLTRB(10, 0, 10, 0),
                      child: Icon(Icons.map_outlined, size: 30),
                    ),
                    const VerticalDivider(width: 1),
                    const Spacer(),
                    Text(
                      'Map',
                      style: TextTheme.of(context).headlineSmall!
                          .copyWith(color: ColorScheme.of(context).primary),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: ElevatedButton(
                key: const Key('landing.sharing'),
                onPressed: () => context.go('/sharing'),
                child: Row(
                  mainAxisAlignment: .start,
                  crossAxisAlignment: .center,
                  spacing: 10,
                  children: [
                    const Padding(
                      padding: EdgeInsetsGeometry.fromLTRB(10, 0, 10, 0),
                      child: Icon(Icons.cloud_upload_outlined, size: 30),
                    ),
                    const VerticalDivider(width: 1),
                    const Spacer(),
                    Text(
                      'Sharing',
                      style: TextTheme.of(context).headlineSmall!
                          .copyWith(color: ColorScheme.of(context).primary),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: ElevatedButton(
                key: const Key('landing.permissions'),
                onPressed: () => context.go('/permissions'),
                child: Row(
                  mainAxisAlignment: .start,
                  crossAxisAlignment: .center,
                  spacing: 10,
                  children: [
                    const Padding(
                      padding: EdgeInsetsGeometry.fromLTRB(10, 0, 10, 0),
                      child: Icon(Icons.key_outlined, size: 30),
                    ),
                    const VerticalDivider(width: 1),
                    const Spacer(),
                    Text(
                      'Permissions',
                      style: TextTheme.of(context).headlineSmall!
                          .copyWith(color: ColorScheme.of(context).primary),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            Text(
              "ℹ️ To get set up, start with Permissions, then go to Sharing. Once you're done, use the Map to see location history of yourself and friends.",
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
