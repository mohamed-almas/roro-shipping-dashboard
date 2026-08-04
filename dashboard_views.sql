-- Ro-Ro Shipping Executive Dashboard — analytical views
-- Built on: public.roro_trades (voyage legs), public.roro_ml_ports (port master, incl. Coastal Region / Clarksons Region),
--           public.roro_ml_operators, public.roro_ml_owners, public.roro_ml_vessels, public.roro_transits (canal transits)
--
-- Date columns in roro_trades are stored as TEXT in "DD/MM/YYYY H:MI" format — all views parse via
-- to_timestamp(col, 'DD/MM/YYYY HH24:MI') and derive year/quarter/month grains from destination_port_arrival
-- (voyage completion date) as the canonical event date for a trade leg.
--
-- Applied to Supabase project jeuqpnhajmatekbzlfne (Maritime Shipping). Validated: 354,102/354,102 rows enriched,
-- 100% port->coastal-region match (joined on Port ID / unlocode, not port name), 1032/1040 vessels matched to
-- roro_ml_vessels by IMO for the owner view.

-- ============================================================
-- 0. Base enriched view — one row per voyage leg, parsed dates + region joins
-- ============================================================
create or replace view v_roro_trades_enriched as
select
  t.*,
  to_timestamp(nullif(t.destination_port_arrival,''), 'DD/MM/YYYY HH24:MI') as arrival_ts,
  to_timestamp(nullif(t.origin_port_departure,''), 'DD/MM/YYYY HH24:MI')    as departure_ts,
  date_trunc('year',    to_timestamp(nullif(t.destination_port_arrival,''), 'DD/MM/YYYY HH24:MI'))::date as event_year,
  date_trunc('quarter', to_timestamp(nullif(t.destination_port_arrival,''), 'DD/MM/YYYY HH24:MI'))::date as event_quarter,
  date_trunc('month',   to_timestamp(nullif(t.destination_port_arrival,''), 'DD/MM/YYYY HH24:MI'))::date as event_month,
  origin_p."Coastal Region"   as origin_coastal_region,
  origin_p."Clarksons Region" as origin_clarksons_region,
  dest_p."Coastal Region"     as destination_coastal_region,
  dest_p."Clarksons Region"   as destination_clarksons_region
from roro_trades t
left join roro_ml_ports origin_p on origin_p."Port ID" = t.origin_port_unlocode
left join roro_ml_ports dest_p   on dest_p."Port ID"   = t.destination_port_unlocode;

-- ============================================================
-- 1. GLOBAL — annual/quarterly/monthly voyage & capacity summary
-- ============================================================
create or replace view v_global_summary as
select
  event_year, event_quarter, event_month,
  count(*)                                   as voyages,
  count(distinct imo)                        as active_vessels,
  count(distinct operator)                   as active_operators,
  sum(ceu)                                   as total_ceu_deployed,
  avg(ceu)                                   as avg_vessel_ceu,
  avg(days_steaming)                         as avg_days_steaming,
  avg(days_total_duration)                   as avg_voyage_duration_days,
  avg(distance_actual)                       as avg_distance_nm,
  avg(origin_port_days_total)                as avg_origin_port_days,
  avg(destination_port_days_total)           as avg_destination_port_days,
  sum(distance_actual)                       as total_distance_nm
from v_roro_trades_enriched
where arrival_ts is not null
group by 1,2,3;

-- ============================================================
-- 2. REGIONAL — by origin/destination region (trade lane level)
-- ============================================================
create or replace view v_regional_summary as
select
  event_year, event_quarter, event_month,
  origin_region, destination_region,
  count(*)                          as voyages,
  sum(ceu)                          as total_ceu_deployed,
  avg(days_total_duration)          as avg_voyage_duration_days,
  avg(distance_actual)              as avg_distance_nm,
  count(distinct operator)          as active_operators,
  count(distinct imo)               as active_vessels
from v_roro_trades_enriched
where arrival_ts is not null
group by 1,2,3,4,5;

-- ============================================================
-- 3. COASTAL REGION — Esgian "Coastal Region" granularity (finer than macro region)
-- ============================================================
create or replace view v_coastal_region_summary as
select
  event_year, event_quarter, event_month,
  origin_coastal_region, destination_coastal_region,
  count(*)                 as voyages,
  sum(ceu)                 as total_ceu_deployed,
  avg(days_total_duration) as avg_voyage_duration_days,
  avg(distance_actual)     as avg_distance_nm
from v_roro_trades_enriched
where arrival_ts is not null
group by 1,2,3,4,5;

-- ============================================================
-- 4. PORT PERFORMANCE — origin & destination port call metrics unioned into one port axis
-- ============================================================
create or replace view v_port_performance as
select
  event_year, event_quarter, event_month,
  origin_port_name as port_name, origin_port_unlocode as port_unlocode, origin_country as country, origin_region as region,
  'origin'::text as call_role,
  count(*) as port_calls,
  avg(origin_port_days_total)   as avg_port_days_total,
  avg(origin_port_days_berthed) as avg_port_days_berthed,
  sum(ceu) as ceu_handled
from v_roro_trades_enriched
where arrival_ts is not null
group by 1,2,3,4,5,6,7,8
union all
select
  event_year, event_quarter, event_month,
  destination_port_name, destination_port_unlocode, destination_country, destination_region,
  'destination'::text,
  count(*),
  avg(destination_port_days_total),
  avg(destination_port_days_berthed),
  sum(ceu)
from v_roro_trades_enriched
where arrival_ts is not null
group by 1,2,3,4,5,6,7,8;

-- ============================================================
-- 5. VOYAGE — leg-level detail view for drill-through / voyage explorer
-- ============================================================
create or replace view v_voyage_detail as
select
  imo, vessel_name, operator, operator_type, segment, sub_segment, ceu,
  origin_port_name, origin_country, origin_region,
  destination_port_name, destination_country, destination_region,
  departure_ts, arrival_ts,
  days_steaming, days_total_duration, distance_actual, event,
  event_year, event_quarter, event_month
from v_roro_trades_enriched
where arrival_ts is not null;

-- ============================================================
-- 6. OPERATOR / OWNER — performance & fleet deployment
-- ============================================================
create or replace view v_operator_summary as
select
  event_year, event_quarter, event_month,
  operator, operator_type,
  count(*)                    as voyages,
  count(distinct imo)         as vessels_deployed,
  sum(ceu)                    as total_ceu_deployed,
  avg(days_total_duration)    as avg_voyage_duration_days,
  avg(destination_port_days_total) as avg_port_days,
  count(distinct destination_port_name) as ports_served
from v_roro_trades_enriched
where arrival_ts is not null and operator is not null and operator <> ''
group by 1,2,3,4,5;

create or replace view v_owner_summary as
select
  e.event_year, e.event_quarter, e.event_month,
  v."Owner" as owner,
  count(*)                    as voyages,
  count(distinct e.imo)       as vessels_deployed,
  sum(e.ceu)                  as total_ceu_deployed,
  avg(e.days_total_duration)  as avg_voyage_duration_days
from v_roro_trades_enriched e
join roro_ml_vessels v on v."IMO Number" = e.imo
where e.arrival_ts is not null and v."Owner" is not null and v."Owner" <> ''
group by 1,2,3,4;

-- ============================================================
-- 7. VESSELS — utilization & activity by vessel
-- ============================================================
create or replace view v_vessel_summary as
select
  event_year, event_quarter, event_month,
  imo, vessel_name, sub_segment, operator,
  count(*)                 as voyages,
  sum(ceu)                 as ceu_capacity_sum, -- ceu is constant per vessel; sum here is voyages*ceu, use avg for capacity
  avg(ceu)                 as vessel_ceu_capacity,
  avg(days_total_duration) as avg_voyage_duration_days,
  sum(distance_actual)     as total_distance_nm,
  avg(destination_port_days_total) as avg_port_days
from v_roro_trades_enriched
where arrival_ts is not null
group by 1,2,3,4,5,6,7;
