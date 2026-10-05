import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/scrap_decoration.dart';
import '../models/scrapbook.dart';

/// The Timeline scrapbook's layout and connections (migration 018). Both
/// partners share one scrapbook. Writes are batched by the caller: nothing
/// here is ever called while a finger is still moving.
class ScrapbookService {
  ScrapbookService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Every placed memory and every connection of the couple.
  static Future<({Map<String, LayoutItem> items, List<ScrapConnection> links})>
  load(String coupleId) async {
    final results = await Future.wait([
      _db.from('timeline_layout_items').select().eq('couple_id', coupleId),
      _db
          .from('timeline_connections')
          .select()
          .eq('couple_id', coupleId)
          .order('created_at'),
    ]);
    return (
      items: {
        for (final r in results[0])
          r['memory_id'] as String: LayoutItem.fromRow(r),
      },
      links: [for (final r in results[1]) ScrapConnection.fromRow(r)],
    );
  }

  /// Saves several items in one request.
  static Future<void> saveItems(
    String coupleId,
    Iterable<LayoutItem> items,
  ) async {
    final rows = [for (final i in items) i.toRow(coupleId)];
    if (rows.isEmpty) return;
    await _db.from('timeline_layout_items').upsert(rows);
  }

  /// Forgets the placement of these memories (they go back to automatic).
  static Future<void> removeItems(String coupleId, Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await _db
        .from('timeline_layout_items')
        .delete()
        .eq('couple_id', coupleId)
        .inFilter('memory_id', list);
  }

  /// Back to the fully automatic scrapbook. Memories and connections stay.
  static Future<void> removeAllItems(String coupleId) async {
    await _db.from('timeline_layout_items').delete().eq('couple_id', coupleId);
  }

  static Future<ScrapConnection> connect(
    String coupleId,
    String sourceId,
    String targetId,
    ConnectionStyle style,
  ) async {
    final row = await _db
        .from('timeline_connections')
        .insert({
          'couple_id': coupleId,
          'source_id': sourceId,
          'target_id': targetId,
          'style': style.dbValue,
        })
        .select()
        .single();
    return ScrapConnection.fromRow(row);
  }

  static Future<void> restyle(String id, ConnectionStyle style) async {
    await _db
        .from('timeline_connections')
        .update({'style': style.dbValue})
        .eq('id', id);
  }

  static Future<void> disconnect(String id) async {
    await _db.from('timeline_connections').delete().eq('id', id);
  }

  /// The couple's decorations. Throws when the database has no decorations
  /// yet (before migration 019): the scrapbook then works without them.
  static Future<List<ScrapDecoration>> decorations(String coupleId) async {
    final rows = await _db
        .from('timeline_decorations')
        .select()
        .eq('couple_id', coupleId);
    return [for (final r in rows) ?ScrapDecoration.fromRow(r)];
  }

  /// Saves several decorations (new or changed) in one request.
  static Future<void> saveDecorations(
    String coupleId,
    Iterable<ScrapDecoration> decorations,
  ) async {
    final rows = [for (final d in decorations) d.toRow(coupleId)];
    if (rows.isEmpty) return;
    await _db.from('timeline_decorations').upsert(rows);
  }

  static Future<void> removeDecorations(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await _db.from('timeline_decorations').delete().inFilter('id', list);
  }

  /// Calls [onChange] when either partner saves layout or connections.
  /// (Inserts and updates only: removals are picked up on the next load,
  /// since delete events cannot be filtered to one couple safely.)
  static RealtimeChannel listen(String coupleId, void Function() onChange) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'couple_id',
      value: coupleId,
    );
    var channel = _db.channel('scrapbook-$coupleId');
    for (final table in [
      'timeline_layout_items',
      'timeline_connections',
      'timeline_decorations',
    ]) {
      for (final event in [
        PostgresChangeEvent.insert,
        PostgresChangeEvent.update,
      ]) {
        channel = channel.onPostgresChanges(
          event: event,
          schema: 'public',
          table: table,
          filter: filter,
          callback: (_) => onChange(),
        );
      }
    }
    return channel.subscribe();
  }

  static Future<void> stopListening(RealtimeChannel channel) async {
    await _db.removeChannel(channel);
  }
}
