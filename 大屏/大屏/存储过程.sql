-- 大屏模块存储过程
create procedure dbo.sp_dashboard_metrics(@module_type nvarchar(50)) as
select
    c.*,
    s.stat_object_name
from
    dbo.dashboard_config_metric c
    join dbo.stat_object s on s.stat_object_id = c.stat_object_id
    join dbo.dashboard_display_config d on d.config_id = c.config_id
where
    d.module_type = @module_type;






create procedure dbo.sp_stat_object_detail(@stat_id bigint) as
select
    *
from
    dbo.stat_object
where
    stat_object_id = @stat_id;








create procedure dbo.sp_trend_report(@stat_id bigint) as
select
    *
from
    dbo.history_trend_data
where
    stat_object_id = @stat_id
order by
    cycle_start_time desc;
