import 'package:supabase_flutter/supabase_flutter.dart';

/// Signed links for files in the private Storage buckets, kept for reuse.
///
/// Every file path is unique (it carries a timestamp), so a link stays
/// valid for as long as it hasn't expired. Reusing it means the browser
/// shows the photo from its cache instead of downloading it again, and
/// photos don't flash when a screen reloads. Links are renewed once they
/// have less than [_renewBefore] left, and [clear] forgets them all when
/// someone signs out.
class StorageLinks {
  StorageLinks._();

  static const _life = Duration(hours: 1);
  static const _renewBefore = Duration(minutes: 10);

  /// bucket/path -> link and when it expires.
  static final Map<String, ({String url, DateTime expires})> _links = {};

  static String _key(String bucket, String path) => '$bucket/$path';

  /// Links for [paths] in [bucket]. Paths that don't exist (or fail) are
  /// left out of the result, so callers fall back to their placeholder.
  static Future<Map<String, String>> signed(
    String bucket,
    Iterable<String> paths,
  ) async {
    final wanted = paths.toSet();
    if (wanted.isEmpty) return const {};
    final now = DateTime.now();
    final stale = [
      for (final p in wanted)
        if ((_links[_key(bucket, p)]?.expires.difference(now) ??
                Duration.zero) <
            _renewBefore)
          p,
    ];
    Object? failure;
    if (stale.isNotEmpty) {
      try {
        final results = await Supabase.instance.client.storage
            .from(bucket)
            .createSignedUrlsResult(stale, _life.inSeconds);
        final expires = now.add(_life);
        for (final r in results) {
          if (r is SignedUrlSuccess && r.signedUrl.isNotEmpty) {
            _links[_key(bucket, r.path)] = (url: r.signedUrl, expires: expires);
          }
        }
      } catch (e) {
        // Renewing failed (offline, say): keep using links that still work.
        failure = e;
      }
    }
    final links = {
      for (final p in wanted)
        if (_links[_key(bucket, p)] case final link?)
          if (link.expires.isAfter(now)) p: link.url,
    };
    if (links.isEmpty && failure != null) throw failure;
    return links;
  }

  /// Forgets every link (on sign-out, so nothing carries over to the next
  /// account on this device).
  static void clear() => _links.clear();
}
