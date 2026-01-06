-- 大屏：视图优化方案（4个）

-- 视图：模块-指标-权限汇总，适用权限配置审核
create view dbo.vw_opt_dashboard_permission as
select d.module_type, d.permission_level, c.stat_object_id, s.stat_object_name
from dbo.dashboard_display_config d
join dbo.dashboard_config_metric c on c.config_id = d.config_id
join dbo.stat_object s on s.stat_object_id = c.stat_object_id;

-- 视图：实时与历史对比，适用数据质量巡检
create view dbo.vw_opt_realtime_vs_history as
select r.*, h.trend_value as history_value
from dbo.realtime_agg_snapshot r
left join dbo.history_trend_data h on h.stat_object_id = r.stat_object_id and h.cycle_start_time = r.window_start_time;

-- 视图：指标趋势最近值，适用仪表盘快速取数
create view dbo.vw_opt_stat_latest as
select stat_object_id, trend_value, cycle_start_time
from (
    select stat_object_id, trend_value, cycle_start_time,
           row_number() over(partition by stat_object_id order by cycle_start_time desc) as rn
    from dbo.history_trend_data
) t where rn = 1;

-- 视图：模块配置数量汇总，适用运维容量规划
create view dbo.vw_opt_module_config_stats as
select module_type, count(*) as config_cnt, min(refresh_frequency_s) as min_refresh_s, max(refresh_frequency_s) as max_refresh_s
from dbo.dashboard_display_config
group by module_type;
