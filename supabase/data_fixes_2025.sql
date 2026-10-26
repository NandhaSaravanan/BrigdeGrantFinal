-- Data fixes after loading the 2025 grants (grants_2025_insert.sql).
-- Run once in the Supabase SQL Editor. Safe to re-run.
--
-- 1. Excludes two "Newport, SC" rows whose ZIP codes are outside South
--    Carolina. Rows stay in the table (with the reason) but no view shows
--    them. Re-running grants_2025_insert.sql does not undo this.
-- 2. Shows one verification label in the app: both "NOT FULLY VERIFIED"
--    (2024 file) and "Source dataset match only; ..." (2025 file) become
--    "Not fully verified". The original text is kept as verification_note.
-- 3. Counts recipients without an EIN by name, so 990-PF recipients are no
--    longer left out of recipient counts.
-- 4. Adds grants_overview: one all-years summary row for the home screen.

begin;

alter table public.source_matched_grants
    add column if not exists excluded_reason text;

update public.source_matched_grants
set excluded_reason = case source_row_number
        when 53 then 'ZIP 28570 is Newport, North Carolina, not South Carolina'
        when 54 then 'ZIP 02840 is Newport, Rhode Island, not South Carolina'
    end
where source_file = 'Congressional App Challenge 2025 grants.xlsx'
  and source_sheet = '2025 Grant Candidates'
  and source_row_number in (53, 54)
  and zip in ('28570', '02840');

-- Same columns as before (verification_status is now the short label);
-- verification_note is appended.
create or replace view public.grants_public
with (security_invoker = false)
as
select
    id,
    funder,
    recipient,
    amount_usd,
    tax_year,
    initcap(lower(trim(city))) as city,
    state,
    zip,
    filing_id,
    filing_url,
    source,
    match_evidence,
    county_confirmation,
    case
        when verification_status ilike '%not fully verified%'
          or verification_status ilike 'source dataset match only%'
            then 'Not fully verified'
        else verification_status
    end as verification_status,
    purpose,
    verification_status as verification_note
from public.source_matched_grants
where excluded_reason is null;

create or replace view public.grants_by_city
with (security_invoker = false)
as
select
    initcap(lower(trim(city))) as city,
    state,
    count(*) as grant_count,
    sum(amount_usd) as total_amount_usd,
    round(avg(amount_usd), 2) as average_amount_usd,
    percentile_cont(0.5) within group (order by amount_usd) as median_amount_usd,
    count(distinct funder_ein) as funder_count,
    count(distinct coalesce(recipient_ein, 'name:' || upper(trim(recipient))))
        as recipient_count
from public.source_matched_grants
where excluded_reason is null
group by initcap(lower(trim(city))), state;

create or replace view public.grants_by_funder
with (security_invoker = false)
as
select
    funder,
    funder_ein,
    count(*) as grant_count,
    sum(amount_usd) as total_amount_usd,
    round(avg(amount_usd), 2) as average_amount_usd,
    count(distinct coalesce(recipient_ein, 'name:' || upper(trim(recipient))))
        as recipient_count
from public.source_matched_grants
where excluded_reason is null
group by funder, funder_ein;

create or replace view public.grants_by_recipient
with (security_invoker = false)
as
select
    recipient,
    recipient_ein,
    count(*) as grant_count,
    sum(amount_usd) as total_amount_usd,
    round(avg(amount_usd), 2) as average_amount_usd,
    count(distinct funder_ein) as funder_count
from public.source_matched_grants
where excluded_reason is null
group by recipient, recipient_ein;

create or replace view public.grants_by_zip
with (security_invoker = false)
as
select
    zip,
    initcap(lower(trim(city))) as city,
    state,
    count(*) as grant_count,
    sum(amount_usd) as total_amount_usd,
    count(distinct funder_ein) as funder_count,
    count(distinct coalesce(recipient_ein, 'name:' || upper(trim(recipient))))
        as recipient_count
from public.source_matched_grants
where excluded_reason is null
group by zip, initcap(lower(trim(city))), state;

create or replace view public.grants_by_tax_year
with (security_invoker = false)
as
select
    tax_year,
    count(*) as grant_count,
    sum(amount_usd) as total_amount_usd,
    round(avg(amount_usd), 2) as average_amount_usd,
    percentile_cont(0.5) within group (order by amount_usd) as median_amount_usd,
    count(distinct funder_ein) as funder_count,
    count(distinct coalesce(recipient_ein, 'name:' || upper(trim(recipient))))
        as recipient_count
from public.source_matched_grants
where excluded_reason is null
group by tax_year;

-- All tax years combined, for the home screen's "All years" option.
create or replace view public.grants_overview
with (security_invoker = false)
as
select
    count(*) as grant_count,
    sum(amount_usd) as total_amount_usd,
    round(avg(amount_usd), 2) as average_amount_usd,
    percentile_cont(0.5) within group (order by amount_usd) as median_amount_usd,
    count(distinct funder_ein) as funder_count,
    count(distinct coalesce(recipient_ein, 'name:' || upper(trim(recipient))))
        as recipient_count
from public.source_matched_grants
where excluded_reason is null;

grant select on public.grants_overview to anon, authenticated;

commit;

-- Verify (expected: 2024 = 400 / 21669698, 2025 = 171 / 12729447,
-- no "Newport" city, one verification label):
-- select tax_year, grant_count, total_amount_usd from grants_by_tax_year;
-- select city, grant_count from grants_by_city order by grant_count desc;
-- select distinct verification_status from grants_public;
-- select * from grants_overview;
