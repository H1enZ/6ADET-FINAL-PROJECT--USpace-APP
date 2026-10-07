import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Loads what the first screens show everywhere, while Splash is already
/// waiting for the account, so Home doesn't appear with text in a stand-in
/// font that then shifts, or with icons popping in a moment later:
///
/// * the fonts the theme asked for (Inter and Playfair Display; the
///   letter and handwriting fonts load on their own screens), and
/// * every USpace icon (small SVG files, already parsed for drawing).
///
/// Never takes longer than [limit] and never fails: on a slow or broken
/// connection the app simply carries on and things load as they appear.
Future<void> preloadCritical({
  Duration limit = const Duration(milliseconds: 2500),
}) async {
  try {
    await Future.wait([GoogleFonts.pendingFonts(), _icons()]).timeout(limit);
  } catch (_) {
    // Timed out or offline: nothing to do, they load when shown.
  }
}

Future<void> _icons() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final icons = manifest.listAssets().where(
    (a) => a.startsWith('assets/icons/') && a.endsWith('.svg'),
  );
  // Same cache key UsIcon uses, so each icon draws on its first frame.
  await Future.wait([
    for (final path in icons)
      SvgAssetLoader(path).loadBytes(null).catchError((_) => ByteData(0)),
  ]);
}
