-- get_roro_dashboard_data(): aggregates all Ro-Ro dashboard views into one JSON payload
create or replace function get_roro_dashboard_data()
returns jsonb
language sql
security definer
set search_path = public
as $$
select jsonb_build_object(
  'meta', jsonb_build_object(
    'generated_at', now(),
    'total_voyages', (select count(*) from v_roro_trades_enriched where arrival_ts is not null),
    'data_through', (select max(event_year) from v_global_summary),
    'data_from', (select min(event_year) from v_global_summary)
  ),

  'global', jsonb_build_object(
    'annual', (select coalesce(jsonb_agg(row_to_json(x) order by x.event_year), '[]'::jsonb) from (
      select event_year, sum(voyages) voyages, max(active_vessels) active_vessels, max(active_operators) active_operators,
        sum(total_ceu_deployed) total_ceu_deployed, avg(avg_vessel_ceu) avg_vessel_ceu, avg(avg_days_steaming) avg_days_steaming,
        avg(avg_voyage_duration_days) avg_voyage_duration_days, avg(avg_distance_nm) avg_distance_nm,
        avg(avg_origin_port_days) avg_origin_port_days, avg(avg_destination_port_days) avg_destination_port_days,
        sum(total_distance_nm) total_distance_nm
      from v_global_summary group by event_year
    ) x),
    'quarterly', (select coalesce(jsonb_agg(row_to_json(x) order by x.event_quarter), '[]'::jsonb) from (
      select event_quarter, sum(voyages) voyages, max(active_vessels) active_vessels, max(active_operators) active_operators,
        sum(total_ceu_deployed) total_ceu_deployed, avg(avg_vessel_ceu) avg_vessel_ceu, avg(avg_days_steaming) avg_days_steaming,
        avg(avg_voyage_duration_days) avg_voyage_duration_days, avg(avg_distance_nm) avg_distance_nm,
        avg(avg_origin_port_days) avg_origin_port_days, avg(avg_destination_port_days) avg_destination_port_days,
        sum(total_distance_nm) total_distance_nm
      from v_global_summary group by event_quarter
    ) x),
    'monthly', (select coalesce(jsonb_agg(row_to_json(x) order by x.event_month), '[]'::jsonb) from (
      select event_month, sum(voyages) voyages, max(active_vessels) active_vessels, max(active_operators) active_operators,
        sum(total_ceu_deployed) total_ceu_deployed, avg(avg_vessel_ceu) avg_vessel_ceu, avg(avg_days_steaming) avg_days_steaming,
        avg(avg_voyage_duration_days) avg_voyage_duration_days, avg(avg_distance_nm) avg_distance_nm,
        avg(avg_origin_port_days) avg_origin_port_days, avg(avg_destination_port_days) avg_destination_port_days,
        sum(total_distance_nm) total_distance_nm
      from v_global_summary
      where event_month >= (select max(event_month) from v_global_summary) - interval '5 years'
      group by event_month
    ) x)
  ),

  'regional', jsonb_build_object(
    'top_lane_names', (select coalesce(jsonb_agg(lane), '[]'::jsonb) from (
      select origin_region || ' -> ' || destination_region as lane
      from v_regional_summary where origin_region is not null and destination_region is not null
      group by origin_region, destination_region order by sum(total_ceu_deployed) desc limit 15
    ) l),
    'annual', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select event_year, origin_region, destination_region, sum(voyages) voyages, sum(total_ceu_deployed) total_ceu_deployed,
        avg(avg_voyage_duration_days) avg_voyage_duration_days, avg(avg_distance_nm) avg_distance_nm
      from v_regional_summary
      where origin_region is not null and destination_region is not null
        and (origin_region || ' -> ' || destination_region) in (
          select origin_region || ' -> ' || destination_region
          from v_regional_summary where origin_region is not null and destination_region is not null
          group by origin_region, destination_region order by sum(total_ceu_deployed) desc limit 15
        )
      group by 1,2,3
    ) x),
    'top_lanes', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select origin_region, destination_region, sum(voyages) voyages, sum(total_ceu_deployed) total_ceu_deployed
      from v_regional_summary where origin_region is not null and destination_region is not null
      group by 1,2 order by sum(total_ceu_deployed) desc limit 25
    ) x)
  ),

  'coastal', jsonb_build_object(
    'top_lanes', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select origin_coastal_region, destination_coastal_region, sum(voyages) voyages, sum(total_ceu_deployed) total_ceu_deployed
      from v_coastal_region_summary where origin_coastal_region is not null and destination_coastal_region is not null
      group by 1,2 order by sum(total_ceu_deployed) desc limit 30
    ) x),
    'annual', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select event_year, origin_coastal_region, destination_coastal_region, sum(voyages) voyages, sum(total_ceu_deployed) total_ceu_deployed,
        avg(avg_voyage_duration_days) avg_voyage_duration_days
      from v_coastal_region_summary
      where origin_coastal_region is not null and destination_coastal_region is not null
        and (origin_coastal_region || ' -> ' || destination_coastal_region) in (
          select origin_coastal_region || ' -> ' || destination_coastal_region
          from v_coastal_region_summary where origin_coastal_region is not null and destination_coastal_region is not null
          group by origin_coastal_region, destination_coastal_region order by sum(total_ceu_deployed) desc limit 15
        )
      group by 1,2,3
    ) x)
  ),

  'ports', jsonb_build_object(
    'annual_top', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select event_year, port_name, country, region, sum(port_calls) port_calls,
        avg(avg_port_days_total) avg_port_days_total, avg(avg_port_days_berthed) avg_port_days_berthed, sum(ceu_handled) ceu_handled
      from v_port_performance
      where port_name is not null
        and port_name in (
          select port_name from v_port_performance where port_name is not null
          group by port_name order by sum(port_calls) desc limit 25
        )
      group by 1,2,3,4
    ) x),
    'leaderboard', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select port_name, country, region, sum(port_calls) port_calls,
        avg(avg_port_days_total) avg_port_days_total, avg(avg_port_days_berthed) avg_port_days_berthed, sum(ceu_handled) ceu_handled
      from v_port_performance where port_name is not null
      group by 1,2,3 order by sum(port_calls) desc limit 100
    ) x)
  ),

  'voyages_recent', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
    select imo, vessel_name, operator, segment, sub_segment, ceu,
      origin_port_name, origin_country, destination_port_name, destination_country,
      departure_ts, arrival_ts, days_steaming, days_total_duration, distance_actual
    from v_voyage_detail
    order by arrival_ts desc nulls last limit 300
  ) x),

  'operators', jsonb_build_object(
    'annual_leaderboard', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select event_year, operator, operator_type, sum(voyages) voyages, max(vessels_deployed) vessels_deployed,
        sum(total_ceu_deployed) total_ceu_deployed, avg(avg_voyage_duration_days) avg_voyage_duration_days,
        avg(avg_port_days) avg_port_days, max(ports_served) ports_served
      from v_operator_summary group by 1,2,3
    ) x),
    'monthly_frequency', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select event_month, operator, sum(voyages) voyages
      from v_operator_summary
      where event_month >= (select max(event_month) from v_operator_summary) - interval '18 months'
        and operator in (
          select operator from v_operator_summary group by operator order by sum(total_ceu_deployed) desc limit 15
        )
      group by 1,2
    ) x),
    'leaderboard', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select operator, operator_type, sum(voyages) voyages, max(vessels_deployed) vessels_deployed,
        sum(total_ceu_deployed) total_ceu_deployed, avg(avg_voyage_duration_days) avg_voyage_duration_days,
        avg(avg_port_days) avg_port_days, max(ports_served) ports_served
      from v_operator_summary group by 1,2 order by sum(total_ceu_deployed) desc limit 50
    ) x)
  ),

  'owners', jsonb_build_object(
    'leaderboard', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select owner, sum(voyages) voyages, max(vessels_deployed) vessels_deployed,
        sum(total_ceu_deployed) total_ceu_deployed, avg(avg_voyage_duration_days) avg_voyage_duration_days
      from v_owner_summary group by 1 order by sum(total_ceu_deployed) desc limit 50
    ) x)
  ),

  'vessels', jsonb_build_object(
    'leaderboard', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select imo, vessel_name, sub_segment, operator, sum(voyages) voyages,
        avg(vessel_ceu_capacity) vessel_ceu_capacity, avg(avg_voyage_duration_days) avg_voyage_duration_days,
        sum(total_distance_nm) total_distance_nm, avg(avg_port_days) avg_port_days
      from v_vessel_summary group by 1,2,3,4 order by sum(voyages) desc limit 150
    ) x),
    'segment_breakdown', (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
      select sub_segment, count(distinct imo) vessel_count, sum(voyages) voyages, sum(ceu_capacity_sum) ceu_capacity_sum
      from v_vessel_summary where sub_segment is not null group by 1
    ) x)
  )
);
$$;

grant execute on function get_roro_dashboard_data() to anon, authenticated;
