-- Exact search totals for the Ask chatbot (supabase/functions/grant-chat).
-- Run after supabase/sc_app_views.sql. Safe to re-run.
--
-- Statewide, one search can match tens of thousands of grants, so totals are
-- computed in the database rather than from a capped list of rows. Only the
-- Edge Function (service role) can call this.

create or replace function public.sc_grant_search(
    p_words text[] default null,
    p_funder text default null,
    p_recipient text default null,
    p_city text default null,
    p_county text default null,
    p_tax_year integer default null,
    p_min numeric default null,
    p_max numeric default null
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with m as (
        select g.*
        from public.sc_grants_public g
        where (p_words is null or cardinality(p_words) = 0 or exists (
                  select 1 from unnest(p_words) w
                  where g.funder ilike '%' || w || '%'
                     or g.recipient ilike '%' || w || '%'
                     or g.purpose ilike '%' || w || '%'))
          and (p_funder is null or g.funder ilike '%' || p_funder || '%')
          and (p_recipient is null or g.recipient ilike '%' || p_recipient || '%')
          and (p_city is null or g.city ilike p_city)
          and (p_county is null or g.county ilike p_county)
          and (p_tax_year is null or g.tax_year = p_tax_year)
          and (p_min is null or g.amount_usd >= p_min)
          and (p_max is null or g.amount_usd <= p_max)
    )
    select jsonb_build_object(
        'match_count', (select count(*) from m),
        'total_usd', (select coalesce(sum(amount_usd), 0) from m),
        'funders', (select count(distinct funder) from m),
        'recipients', (select count(distinct recipient) from m),
        'largest', coalesce((
            select jsonb_agg(to_jsonb(t) order by t.amount_usd desc)
            from (select id, funder, recipient, amount_usd, tax_year, city, state, zip, county,
                         filing_id, filing_url, source, match_evidence, purpose, grant_type, funder_type
                  from m order by amount_usd desc limit 10) t
        ), '[]'::jsonb)
    );
$$;

revoke all on function public.sc_grant_search(text[], text, text, text, text, integer, numeric, numeric)
    from public, anon, authenticated;
grant execute on function public.sc_grant_search(text[], text, text, text, text, integer, numeric, numeric)
    to service_role;
