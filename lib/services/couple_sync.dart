import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'couple_service.dart';

/// Live updates between the two partners, in one place.
///
/// Every screen that shows shared data calls [CoupleSync.listen] with the
/// tables it shows and a callback that reloads them. All of a couple's
/// screens share the same realtime connection, which this class opens on
/// the first listener and closes a few seconds after the last one leaves.
///
/// How a change reaches the partner:
/// * Inserts and updates arrive as Postgres changes, filtered to this
///   couple. Realtime still applies each table's row-level security, so a
///   partner only ever receives rows they could read anyway.
/// * Deletes don't arrive that way (Realtime can't filter them to one
///   couple, and an unfiltered listener would see other couples' ids), so
///   whoever deletes something calls [announce]: an empty "changed" message
///   naming only the table. The partner then re-reads it through RLS.
/// * After a dropped connection comes back, every listener reloads once, so
///   nothing missed while offline stays stale.
///
/// Listeners reload from the server rather than patching rows in, so an
/// item added optimistically on this phone and then echoed back by
/// Realtime still shows once: the server's list replaces the local one.
class CoupleSync {
  CoupleSync._();

  /// Tables published since the start (migrations up to 019).
  static const coreTables = {
    'messages',
    'message_reactions',
    'activities',
    'affections',
    'notes',
    'time_capsules',
    'timeline_layout_items',
    'timeline_connections',
    'timeline_decorations',
  };

  /// Tables published by migration 020. They get their own channel, so a
  /// database without 020 yet only loses these, never chat and the rest.
  static const sharedTables = {
    'memories',
    'memory_photos',
    'bucket_items',
    'bucket_contributions',
    'important_dates',
    'question_answers',
    'moods',
    'profiles',
    'couples',
  };

  static final Map<String, _Hub> _hubs = {};

  /// Calls [onChange] when any of [tables] changes for this couple, or once
  /// after a lost connection is back. Bursts (one action can write several
  /// rows) are settled into one call after [settle]. Cancel the returned
  /// handle in dispose.
  static CoupleSyncHandle listen(
    String coupleId,
    Set<String> tables,
    VoidCallback onChange, {
    Duration settle = const Duration(milliseconds: 250),
  }) {
    assert(
      tables.every((t) => coreTables.contains(t) || sharedTables.contains(t)),
      'Unknown realtime table in $tables',
    );
    final hub = _hubs.putIfAbsent(coupleId, () => _Hub(coupleId));
    final listener = _Listener(tables, onChange, settle);
    hub.add(listener);
    return CoupleSyncHandle._(() {
      listener.cancel();
      hub.remove(listener);
    });
  }

  /// Tells the partner's open screens that [table] changed in a way they
  /// can't hear by themselves (a delete). Carries no data. Sent on this
  /// device's open connection (only ever your own couple's). Never throws:
  /// live updates are a bonus, the change itself is already saved.
  static Future<void> announce(String table) async {
    for (final hub in _hubs.values.toList()) {
      try {
        await hub.announce(table);
      } catch (_) {}
    }
  }

  /// Closes every connection (on sign-out).
  static void reset() {
    // Take them out first: closing a hub removes it from [_hubs], which
    // must not happen while looping over the map itself (that threw, and
    // stopped sign-out before it could leave the screen).
    final hubs = _hubs.values.toList();
    _hubs.clear();
    for (final hub in hubs) {
      try {
        hub.close();
      } catch (_) {
        // Sign-out goes on regardless; the connection is dropped anyway.
      }
    }
  }

  static void _closed(_Hub hub) {
    if (identical(_hubs[hub.coupleId], hub)) _hubs.remove(hub.coupleId);
  }
}

/// Stops one [CoupleSync.listen].
class CoupleSyncHandle {
  CoupleSyncHandle._(this._cancel);

  final VoidCallback _cancel;
  bool _done = false;

  void cancel() {
    if (_done) return;
    _done = true;
    _cancel();
  }
}

class _Listener {
  _Listener(this.tables, this.onChange, this.settle);

  final Set<String> tables;
  final VoidCallback onChange;
  final Duration settle;
  Timer? _timer;
  bool _cancelled = false;

  void notify() {
    if (_cancelled) return;
    if (settle == Duration.zero) {
      onChange();
      return;
    }
    _timer?.cancel();
    _timer = Timer(settle, () {
      if (!_cancelled) onChange();
    });
  }

  void cancel() {
    _cancelled = true;
    _timer?.cancel();
  }
}

/// One couple's connection: two channels and the listeners sharing them.
class _Hub {
  _Hub(this.coupleId) {
    _core = _subscribe(
      'couple-$coupleId',
      CoupleSync.coreTables,
      withBroadcast: true,
    );
    _shared = _subscribe('couple-shared-$coupleId', CoupleSync.sharedTables);
  }

  static const _changed = 'changed';
  static const _linger = Duration(seconds: 5);

  final String coupleId;
  final _listeners = <_Listener>{};
  late final RealtimeChannel _core;
  late final RealtimeChannel _shared;
  Timer? _closeTimer;
  bool _closed = false;

  static SupabaseClient get _db => Supabase.instance.client;

  RealtimeChannel _subscribe(
    String topic,
    Set<String> tables, {
    bool withBroadcast = false,
  }) {
    var channel = _db.channel(topic);
    for (final table in tables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        // The couples table is the couple itself: match its own id.
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: table == 'couples' ? 'id' : 'couple_id',
          value: coupleId,
        ),
        callback: (_) => _changedTable(table),
      );
    }
    if (withBroadcast) {
      channel = channel.onBroadcast(
        event: _changed,
        callback: (message) {
          final inner = message['payload'];
          final table = inner is Map ? inner['table'] : message['table'];
          if (table is String) _changedTable(table);
        },
      );
    }
    // Realtime rejoins by itself after a dropped connection. Once it is
    // back, reload everything once: changes made meanwhile were missed.
    var lost = false;
    return channel.subscribe((status, _) {
      if (_closed) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (lost) {
          lost = false;
          _resync(tables);
        }
      } else {
        lost = true;
      }
    });
  }

  void _changedTable(String table) {
    if (_closed) return;
    // Names, photos, birthdays and the anniversary are shared by every
    // screen through CoupleService: drop its copy first.
    if (table == 'profiles' || table == 'couples') CoupleService.forget();
    for (final l in _listeners.toList()) {
      if (l.tables.contains(table)) l.notify();
    }
  }

  void _resync(Set<String> tables) {
    if (tables.contains('profiles')) CoupleService.forget();
    for (final l in _listeners.toList()) {
      if (l.tables.any(tables.contains)) l.notify();
    }
  }

  void add(_Listener listener) {
    _closeTimer?.cancel();
    _closeTimer = null;
    _listeners.add(listener);
  }

  void remove(_Listener listener) {
    _listeners.remove(listener);
    if (_listeners.isNotEmpty) return;
    // Opening another screen often removes one listener and adds the next:
    // wait a moment before closing, so the connection isn't torn down and
    // rebuilt in between.
    _closeTimer?.cancel();
    _closeTimer = Timer(_linger, () {
      if (_listeners.isEmpty) close();
    });
  }

  Future<void> announce(String table) async {
    if (_closed) return;
    await _core.sendBroadcastMessage(
      event: _changed,
      payload: {'table': table},
    );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _closeTimer?.cancel();
    for (final l in _listeners) {
      l.cancel();
    }
    _listeners.clear();
    unawaited(_db.removeChannel(_core).catchError((_) => 'error'));
    unawaited(_db.removeChannel(_shared).catchError((_) => 'error'));
    CoupleSync._closed(this);
  }
}
