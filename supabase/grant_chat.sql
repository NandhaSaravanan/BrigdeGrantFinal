-- Daily usage limits for the grant-chat Edge Function. Run once in the
-- Supabase SQL Editor before deploying the function. Safe to re-run.
--
-- The app has no sign-in, so limits are counted per device and per IP
-- address, plus one overall cap that bounds the daily OpenAI bill.
-- Only the Edge Function (service role) can read or change these counts.

begin;

create table if not exists public.chat_usage (
    key text not null,
    day date not null default (now() at time zone 'utc')::date,
    count integer not null default 0,
    primary key (key, day)
);

alter table public.chat_usage enable row level security;
revoke all on public.chat_usage from anon, authenticated;

-- Atomically counts one question against each key and returns true when
-- every key is still within its limit (keys and limits are paired arrays).
-- A refused question is not counted.
create or replace function public.consume_chat_quota(p_keys text[], p_limits integer[])
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    today date := (now() at time zone 'utc')::date;
    i integer;
    used integer;
begin
    if array_length(p_keys, 1) is distinct from array_length(p_limits, 1) then
        raise exception 'keys and limits must have the same length';
    end if;

    -- Counts are only needed for today's limit; drop anything over a week old
    -- (the privacy policy promises this).
    delete from public.chat_usage where day < today - 7;

    for i in 1 .. coalesce(array_length(p_keys, 1), 0) loop
        insert into public.chat_usage as u (key, day, count)
        values (p_keys[i], today, 0)
        on conflict (key, day) do nothing;

        select u.count into used
        from public.chat_usage u
        where u.key = p_keys[i] and u.day = today
        for update;

        if used >= p_limits[i] then
            return false;
        end if;
    end loop;

    update public.chat_usage
    set count = count + 1
    where day = today and key = any (p_keys);
    return true;
end;
$$;

revoke all on function public.consume_chat_quota(text[], integer[])
    from public, anon, authenticated;

-- Old counts are not needed after a day; keep a week for checking usage.
delete from public.chat_usage where day < (now() at time zone 'utc')::date - 7;

commit;

-- Check today's usage:
-- select key, count from public.chat_usage
-- where day = (now() at time zone 'utc')::date order by count desc;
