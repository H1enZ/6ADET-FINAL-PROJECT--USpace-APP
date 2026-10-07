import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/couple.dart';
import '../models/profile.dart';

/// Profiles and pairing. Every query here is also limited by the row-level
/// security policies in supabase/schema.sql, so even a bug in this file
/// cannot show one couple another couple's data.
class CoupleService {
  CoupleService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// The signed-in person's profile, or null if it doesn't exist.
  static Future<Profile?> myProfile() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _db
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  // The couple and its two members are read by almost every screen, and
  // the tabs all load at once. Calls share one request and its answer for
  // [_fresh]; [forget] drops it when a profile or the couple changes (here,
  // in ProfileService, or by a realtime update) and on sign-out.
  static const _fresh = Duration(seconds: 30);
  static final Map<String, ({DateTime at, Future<Couple> value})> _couples =
      {};
  static final Map<String, ({DateTime at, Future<List<Profile>> value})>
  _members = {};

  static Future<T> _shared<T>(
    Map<String, ({DateTime at, Future<T> value})> cache,
    String key,
    Future<T> Function() load,
  ) {
    final hit = cache[key];
    if (hit != null && DateTime.now().difference(hit.at) < _fresh) {
      return hit.value;
    }
    final value = load();
    cache[key] = (at: DateTime.now(), value: value);
    // A failed request is not kept: the next call tries again.
    value.then(
      (_) {},
      onError: (Object _) {
        if (identical(cache[key]?.value, value)) cache.remove(key);
      },
    );
    return value;
  }

  static Future<Couple> couple(String coupleId) => _shared(
    _couples,
    coupleId,
    () async => Couple.fromMap(
      await _db.from('couples').select().eq('id', coupleId).single(),
    ),
  );

  /// Both people in the couple, oldest account first. Each caller gets its
  /// own list.
  static Future<List<Profile>> members(String coupleId) => _shared(
    _members,
    coupleId,
    () async {
      final rows = await _db
          .from('profiles')
          .select()
          .eq('couple_id', coupleId)
          .order('created_at');
      return rows.map(Profile.fromMap).toList();
    },
  ).then(List.of);

  /// Drops the shared couple and members, so the next read is fresh.
  static void forget() {
    _couples.clear();
    _members.clear();
  }

  /// Starts a new couple. The database makes the pairing code.
  static Future<void> createCouple({DateTime? anniversary}) async {
    await _db.rpc('create_couple', params: {
      'anniversary': anniversary == null ? null : _isoDate(anniversary),
    });
    forget();
  }

  /// Joins the couple that owns [code]. The database checks the code and
  /// that the couple still has room.
  static Future<void> joinCouple(String code) async {
    await _db.rpc('join_couple', params: {'code': code.trim().toUpperCase()});
    forget();
  }

  /// Leaves the couple. Your partner keeps everything and gets a new invite
  /// code; if nobody is left, the space is deleted. See migration 008.
  static Future<void> leaveCouple() async {
    await _db.rpc('leave_couple');
    forget();
  }

  static Future<void> setAnniversary(String coupleId, DateTime date) async {
    await _db
        .from('couples')
        .update({'anniversary_date': _isoDate(date)})
        .eq('id', coupleId);
    forget();
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
