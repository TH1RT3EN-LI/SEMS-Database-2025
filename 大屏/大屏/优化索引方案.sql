-- 大屏：索引设计方案（4个），含适用范围

-- 索引：配置表按模块+权限过滤
create index ix_opt_dashboard_config_module_perm on dbo.dashboard_display_config(module_type, permission_level);

-- 索引：配置指标按统计对象，适用指标回溯
create index ix_opt_config_metric_stat on dbo.dashboard_config_metric(stat_object_id, config_id);

-- 索引：趋势数据按对象+时间，适用曲线查询
create index ix_opt_history_trend_stat_time on dbo.history_trend_data(stat_object_id, cycle_start_time desc);

-- 索引：实时快照按窗口时间，适用最近窗口查询
create index ix_opt_realtime_window on dbo.realtime_agg_snapshot(window_start_time, window_end_time);
