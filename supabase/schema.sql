-- ============================================================
--  ניגון בזמן · Supabase Schema
--  הרצו את הקובץ הזה פעם אחת ב-SQL Editor של Supabase
-- ============================================================

-- ----------------------------------------------------------------
-- טבלת שירים
-- ----------------------------------------------------------------
create table if not exists songs (
  id                   uuid primary key default gen_random_uuid(),
  title                text not null,
  artist               text not null,
  album                text,
  year                 int not null,
  youtube_id           text,
  audio_url            text,
  audio_source         text default 'youtube',
  start_seconds        int  default 0,
  duration_seconds     int  default 27,
  intro_start_seconds  int  default 0,
  difficulty           int  default 2,   -- 1=קל  2=בינוני  3=מומחה
  category             text,
  is_active            boolean default true,
  verified             boolean default false,
  plays                int default 0,
  correct              int default 0,
  created_at           timestamptz default now()
);

-- ----------------------------------------------------------------
-- טבלת סשנים
-- ----------------------------------------------------------------
create table if not exists game_sessions (
  id                   uuid primary key default gen_random_uuid(),
  created_at           timestamptz default now(),
  players_count        int,
  mode                 text,
  target               int,
  winner_name          text,
  total_placements     int,
  correct_placements   int
);

-- ----------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------
alter table songs         enable row level security;
alter table game_sessions enable row level security;

-- קריאת קטלוג — פתוח לכולם (גם אנונימי)
create policy songs_read on songs
  for select using (true);

-- כתיבת קטלוג — רק אדמין מחובר
create policy songs_write on songs
  for all to authenticated
  using (true) with check (true);

-- רישום משחק — כל שחקן (גם אנונימי) רשאי להוסיף
create policy gs_insert on game_sessions
  for insert with check (true);

-- צפייה בסטטיסטיקות — רק אדמין מחובר
create policy gs_read on game_sessions
  for select to authenticated using (true);

-- ----------------------------------------------------------------
-- RPC: עדכון סטטיסטיקות שיר (נקרא ע"י שחקנים אנונימיים)
-- security definer מאפשר עדכון מעבר ל-RLS
-- ----------------------------------------------------------------
create or replace function increment_song_stats(
  song_id    uuid,
  is_correct boolean
)
returns void
language plpgsql
security definer
as $$
begin
  update songs
  set
    plays   = plays + 1,
    correct = correct + (case when is_correct then 1 else 0 end)
  where id = song_id;
end;
$$;

grant execute on function increment_song_stats(uuid, boolean) to anon;

-- ----------------------------------------------------------------
-- טבלת חדרים למולטיפלייר
-- ----------------------------------------------------------------
create table if not exists game_rooms (
  code        text primary key,
  host_id     text not null,
  is_public   boolean default false,
  status      text default 'lobby',     -- lobby | playing | finished
  state       jsonb default '{}',
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

alter table game_rooms enable row level security;

create policy rooms_read   on game_rooms for select using (true);
create policy rooms_insert on game_rooms for insert with check (true);
create policy rooms_update on game_rooms for update using (true);
create policy rooms_delete on game_rooms for delete using (true);

-- ----------------------------------------------------------------
-- אדמין: Authentication › Users › Add user  (אימייל + סיסמה)
-- ----------------------------------------------------------------
