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

  static Future<Couple> couple(String coupleId) async {
    final row = await _db.from('couples').select().eq('id', coupleId).single();
    return Couple.fromMap(row);
  }

  /// Both people in the couple, oldest account first.
  static Future<List<Profile>> members(String coupleId) async {
    final rows = await _db
        .from('profiles')
        .select()
        .eq('couple_id', coupleId)
        .order('created_at');
    return rows.map(Profile.fromMap).toList();
  }

  /// Starts a new couple. The database makes the pairing code.
  static Future<void> createCouple({DateTime? anniversary}) async {
    await _db.rpc('create_couple', params: {
      'anniversary': anniversary == null ? null : _isoDate(anniversary),
    });
  }

  /// Joins the couple that owns [code]. The database checks the code and
  /// that the couple still has room.
  static Future<void> joinCouple(String code) async {
    await _db.rpc('join_couple', params: {'code': code.trim().toUpperCase()});
  }

  static Future<void> setAnniversary(String coupleId, DateTime date) async {
    await _db
        .from('couples')
        .update({'anniversary_date': _isoDate(date)})
        .eq('id', coupleId);
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
