-- Check that migration 006 worked. All three should be true.
select
  (select count(*) from pg_tables
    where schemaname = 'public'
      and tablename in ('memory_photos', 'messages', 'message_reactions', 'moods',
                        'question_answers', 'important_dates', 'affections',
                        'resolution_notes', 'activities')) = 9      as new_tables_ok,
  (select bool_and(rowsecurity) from pg_tables
    where schemaname = 'public')                                     as rls_on_every_table,
  (select count(*) from pg_publication_tables
    where pubname = 'supabase_realtime'
      and tablename in ('messages', 'message_reactions',
                        'affections', 'activities')) = 4             as realtime_ok;
