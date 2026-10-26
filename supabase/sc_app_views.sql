-- Read-only access for the app to the statewide SC grant data (sc_ tables,
-- loaded by scripts/upload_to_supabase.py). Run after supabase/sc_grants.sql.
-- Safe to re-run.
--
-- The sc_ tables stay private (RLS, no policies). The app reads only through:
--   sc_grants_public          one row per grant, with the recipient's county
--   sc_aggregate(group, county)  grouped totals; county null = statewide
--                             (read from the precomputed sc_aggregates)
--
-- Grants whose ZIP crosses county lines, or whose ZIP isn't a Census ZCTA
-- (e.g. PO boxes), have no county: they count statewide but not in any county.

begin;

create or replace view public.sc_grants_public
with (security_invoker = false)
as
select
    g.id::text as id,
    coalesce(f.funder_name, 'Unknown funder') as funder,
    g.funder_ein,
    coalesce(g.recipient_name, 'Unknown recipient') as recipient,
    g.recipient_ein,
    g.grant_amount as amount_usd,
    g.tax_year,
    g.tax_year_status,
    initcap(lower(trim(g.recipient_city))) as city,
    g.recipient_state as state,
    g.recipient_zip as zip,
    g.recipient_county as county,
    g.county_status,
    g.filing_id,
    g.source_url as filing_url,
    case g.source_type
        when 'schedule_i' then 'Form 990 Schedule I'
        else 'Form 990-PF Part XV'
    end as source,
    -- Shown in the app and website, which avoid "verified" wording.
    case
        when g.irs_filing_verified and g.recipient_identity_verified and g.sc_address_verified
            then 'IRS filing, IRS master file and SC address all match'
        when g.recipient_identity_verified
            then 'Recipient matches the IRS master file'
        when g.irs_filing_verified
            then 'Matches the original IRS filing'
        when g.sc_address_verified
            then 'Recipient EIN has an SC address in the IRS master file'
        else 'From the NCCS IRS e-file table'
    end as match_evidence,
    g.verification_status,
    g.grant_purpose as purpose,
    g.grant_type,
    g.funder_type
from public.sc_grants g
left join public.sc_funders f on f.id = g.funder_id;

grant select on public.sc_grants_public to anon, authenticated;

-- Every grouped total, statewide (scope '') and per county, computed once.
-- Grouping 146k rows on each request took 2-3 seconds; reading this takes
-- milliseconds. Refreshed by sc_refresh_aggregates() after each upload.
drop function if exists public.sc_aggregate(text, text);
drop materialized view if exists public.sc_aggregates;

create materialized view public.sc_aggregates as
with base as (
    select
        gp.*,
        coalesce(gp.recipient_ein, 'name:' || upper(trim(gp.recipient))) as recipient_key
    from public.sc_grants_public gp
),
keyed as (
    select
        grp.name as grp,
        case grp.name
            when 'funder' then coalesce(b.funder_ein, b.funder)
            when 'recipient' then b.recipient_key
            when 'city' then b.city
            when 'zip' then b.zip
            when 'county' then coalesce(b.county, 'Unknown or multiple counties')
            when 'tax_year' then b.tax_year::text
            else 'All years'
        end as k,
        b.*
    from base b
    cross join (values ('funder'), ('recipient'), ('city'), ('zip'), ('county'), ('tax_year'), ('overview')) as grp(name)
)
select
    grp,
    case when grouping(county) = 1 then '' else county end as scope,
    -- Grants are often reported under a parent's EIN (a university or
    -- hospital foundation), so one EIN can carry several names; show the
    -- most common one.
    case grp
        when 'funder' then mode() within group (order by funder)
        when 'recipient' then mode() within group (order by recipient)
        else k
    end as label,
    case grp
        when 'funder' then max(funder_ein)
        when 'recipient' then max(recipient_ein)
        when 'city' then 'SC'
        when 'zip' then mode() within group (order by city)
        else null
    end as secondary_label,
    count(*) as grant_count,
    sum(amount_usd) as total_amount_usd,
    round(avg(amount_usd), 2) as average_amount_usd,
    (percentile_cont(0.5) within group (order by amount_usd))::numeric as median_amount_usd,
    count(distinct funder_ein) as funder_count,
    count(distinct recipient_key) as recipient_count
from keyed
where k is not null
group by grouping sets ((grp, k), (grp, county, k))
-- Drop per-county rows for grants with no county (they stay in statewide).
having grouping(county) = 1 or county is not null;

create index sc_aggregates_lookup on public.sc_aggregates (grp, scope, total_amount_usd desc);
revoke all on public.sc_aggregates from anon, authenticated;

-- Grouped totals for the app. p_group: funder, recipient, city, zip, county,
-- tax_year, overview. p_county: a county name such as 'York County', or null
-- for all of South Carolina.
create or replace function public.sc_aggregate(p_group text, p_county text default null)
returns table (
    label text,
    secondary_label text,
    grant_count bigint,
    total_amount_usd numeric,
    average_amount_usd numeric,
    median_amount_usd numeric,
    funder_count bigint,
    recipient_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
    select label, secondary_label, grant_count, total_amount_usd, average_amount_usd,
           median_amount_usd, funder_count, recipient_count
    from public.sc_aggregates
    where grp = p_group and scope = coalesce(p_county, '');
$$;

revoke all on function public.sc_aggregate(text, text) from public;
grant execute on function public.sc_aggregate(text, text) to anon, authenticated;

-- Rebuilds sc_aggregates after new data is uploaded (service role only).
create or replace function public.sc_refresh_aggregates()
returns void
language sql
security definer
set search_path = public
as $$ refresh materialized view public.sc_aggregates; $$;

revoke all on function public.sc_refresh_aggregates() from public, anon, authenticated;
grant execute on function public.sc_refresh_aggregates() to service_role;

commit;

-- Check:
-- select * from sc_aggregate('overview');
-- select * from sc_aggregate('tax_year', 'York County');
-- select label, grant_count from sc_aggregate('county') order by label;
