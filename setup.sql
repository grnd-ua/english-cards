create table if not exists public.progress(
  sync_code text primary key check (char_length(sync_code) >= 16),
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.progress enable row level security;
-- no policies: direct table access denied for anon/authenticated
revoke all on public.progress from anon, authenticated;

create or replace function public.get_progress(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if p_code is null or char_length(p_code) < 16 then raise exception 'invalid code'; end if;
  return (select data from public.progress where sync_code = p_code);
end $$;

create or replace function public.save_progress(p_code text, p_data jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_code is null or char_length(p_code) < 16 or char_length(p_code) > 128 then raise exception 'invalid code'; end if;
  if pg_column_size(p_data) > 512000 then raise exception 'data too large'; end if;
  insert into public.progress(sync_code, data, updated_at) values (p_code, p_data, now())
  on conflict (sync_code) do update set data = excluded.data, updated_at = now();
end $$;

revoke all on function public.get_progress(text) from public;
revoke all on function public.save_progress(text, jsonb) from public;
grant execute on function public.get_progress(text) to anon;
grant execute on function public.save_progress(text, jsonb) to anon;
