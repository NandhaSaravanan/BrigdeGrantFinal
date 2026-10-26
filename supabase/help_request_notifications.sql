-- Emails every new help request (app or website) via the
-- notify-help-request Edge Function. Run once in the Supabase SQL Editor,
-- after deploying the function. Safe to re-run.
--
-- The trigger only sends the new row's id; the function loads the row with
-- the service role and marks it notified so each request is emailed once.

begin;

create extension if not exists pg_net with schema extensions;

alter table public.help_requests
    add column if not exists notified_at timestamptz,
    add column if not exists notify_error text;

create or replace function public.notify_help_request()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
    perform net.http_post(
        url := 'https://fpfjpcspoeewytctdipn.supabase.co/functions/v1/notify-help-request',
        body := jsonb_build_object('id', new.id),
        headers := '{"Content-Type": "application/json"}'::jsonb,
        timeout_milliseconds := 5000
    );
    return new;
end;
$$;

revoke all on function public.notify_help_request() from public, anon, authenticated;

drop trigger if exists help_requests_notify on public.help_requests;
create trigger help_requests_notify
    after insert on public.help_requests
    for each row execute function public.notify_help_request();

commit;

-- Check delivery (after a test request):
-- select created_at, full_name, notified_at, notify_error
-- from public.help_requests order by created_at desc limit 5;
