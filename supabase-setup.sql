-- Hub Rush leaderboard: paste this whole file into Supabase > SQL Editor and click Run.
-- Players never touch the table directly; the browser can only call the three functions at the bottom.

create table if not exists public.hub_scores (
  player_hash text primary key,                -- sha256 of the secret id kept in the player's browser
  pid text not null unique default substr(md5(random()::text || clock_timestamp()::text), 1, 12),  -- public id
  name text not null,
  score integer not null default 0 check (score between 0 and 500000),
  sorted integer not null default 0,
  combo integer not null default 0,
  trucks integer not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.hub_scores enable row level security;
-- No policies on purpose: the table can't be read or written from the browser except through the functions below.
revoke all on table public.hub_scores from anon, authenticated;

create or replace function public.hub_clean_name(n text) returns text
language sql immutable as $$
  select left(btrim(regexp_replace(regexp_replace(coalesce(n, ''), '[[:cntrl:]<>]', '', 'g'), '\s+', ' ', 'g')), 16)
$$;

create or replace function public.hub_rank(p_pid text) returns bigint
language sql stable security definer set search_path = public as $$
  select count(*) + 1
  from hub_scores a, hub_scores me
  where me.pid = p_pid and a.score > 0
    and (a.score > me.score or (a.score = me.score and a.updated_at < me.updated_at))
$$;

-- Top 100, highest first; ties go to whoever set the score first.
create or replace function public.get_board(p_limit int default 100)
returns table(rank bigint, pid text, name text, score int, sorted int, combo int, trucks int, total bigint)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by s.score desc, s.updated_at asc),
         s.pid, s.name, s.score, s.sorted, s.combo, s.trucks, count(*) over ()
  from hub_scores s
  where s.score > 0
  order by s.score desc, s.updated_at asc
  limit least(greatest(coalesce(p_limit, 100), 1), 100)
$$;

create or replace function public.get_me(p_player text) returns json
language plpgsql stable security definer set search_path = public as $$
declare r hub_scores;
begin
  if p_player is null or p_player !~ '^[A-Za-z0-9_-]{16,64}$' then
    return json_build_object('pid', null, 'best', 0, 'rank', 0);
  end if;
  select * into r from hub_scores where player_hash = encode(sha256(convert_to(p_player, 'UTF8')), 'hex');
  if not found then return json_build_object('pid', null, 'best', 0, 'rank', 0); end if;
  return json_build_object('pid', r.pid, 'name', r.name, 'best', r.score,
                           'rank', case when r.score > 0 then hub_rank(r.pid) else 0 end);
end $$;

-- Keeps each player's best score; a lower score only updates their name.
create or replace function public.submit_score(p_player text, p_name text, p_score int,
                                               p_sorted int default 0, p_combo int default 0, p_trucks int default 0)
returns json language plpgsql volatile security definer set search_path = public as $$
declare h text; n text; r hub_scores; improved boolean := false;
begin
  if p_player is null or p_player !~ '^[A-Za-z0-9_-]{16,64}$' then raise exception 'Bad player id.'; end if;
  n := hub_clean_name(p_name);
  if n = '' then raise exception 'Enter a name first.'; end if;
  p_score := least(greatest(coalesce(p_score, 0), 0), 500000);
  h := encode(sha256(convert_to(p_player, 'UTF8')), 'hex');
  if not exists (select 1 from hub_scores where player_hash = h) then
    if (select count(*) from hub_scores) >= 5000 then raise exception 'The leaderboard is full.'; end if;
    insert into hub_scores(player_hash, name) values (h, n) on conflict (player_hash) do nothing;
  end if;
  select * into r from hub_scores where player_hash = h for update;
  if p_score > r.score then
    improved := true;
    update hub_scores
       set name = n, score = p_score,
           sorted = least(greatest(coalesce(p_sorted, 0), 0), 100000),
           combo  = least(greatest(coalesce(p_combo, 0), 0), 100000),
           trucks = least(greatest(coalesce(p_trucks, 0), 0), 1000),
           updated_at = now()
     where player_hash = h returning * into r;
  elsif n <> r.name then
    update hub_scores set name = n where player_hash = h returning * into r;
  end if;
  return json_build_object('pid', r.pid, 'best', r.score, 'improved', improved,
                           'rank', case when r.score > 0 then hub_rank(r.pid) else 0 end,
                           'total', (select count(*) from hub_scores where score > 0));
end $$;

revoke execute on function public.hub_clean_name(text), public.hub_rank(text) from public, anon, authenticated;
revoke execute on function public.get_board(int), public.get_me(text), public.submit_score(text, text, int, int, int, int) from public;
grant execute on function public.get_board(int), public.get_me(text), public.submit_score(text, text, int, int, int, int) to anon, authenticated;
