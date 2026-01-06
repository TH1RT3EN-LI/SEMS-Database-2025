-- 大屏模块触发器（同步配置和趋势数据；适用范围：自动建默认配置、实时落历史、顺序调整）

-- 触发器：新增统计对象时自动生成默认大屏配置
create trigger trg_stat_object_insert on dbo.stat_object
after
insert
    as begin
insert into
    dbo.dashboard_config_metric(stat_object_id, display_order)
select
    i.stat_object_id,
    1000
from
    inserted i;

end;

-- 触发器：实时快照落库时同步写历史趋势

create trigger trg_realtime_snapshot_insert on dbo.realtime_agg_snapshot
after insert
as
begin
    set nocount on;

    select * into #ins from inserted;

    declare @targetCols nvarchar(max) = N'';
    declare @selectCols nvarchar(max) = N'';
    declare @sql nvarchar(max);

    select @targetCols = string_agg(quotename(h.name), ',')
           , @selectCols = string_agg(quotename(h.name), ',')
    from sys.columns h
    join tempdb.sys.columns i on lower(h.name) = lower(i.name)
    where h.object_id = object_id('dbo.history_trend_data')
      and i.object_id = object_id('tempdb..#ins');

    if @targetCols is null begin
        set @targetCols = N''; set @selectCols = N'';
    end


    if exists(select 1 from sys.columns where object_id = object_id('dbo.history_trend_data') and name = 'cycle_start_time')
       and exists(select 1 from tempdb.sys.columns where object_id = object_id('tempdb..#ins') and name = 'window_start_time')
       and charindex('[cycle_start_time]', @targetCols) = 0
    begin
        if len(@targetCols) > 0 begin set @targetCols += ','; set @selectCols += ','; end
        set @targetCols += quotename('cycle_start_time');
        set @selectCols += quotename('window_start_time');
    end

    if exists(select 1 from sys.columns where object_id = object_id('dbo.history_trend_data') and name = 'cycle_end_time')
       and exists(select 1 from tempdb.sys.columns where object_id = object_id('tempdb..#ins') and name = 'window_end_time')
       and charindex('[cycle_end_time]', @targetCols) = 0
    begin
        if len(@targetCols) > 0 begin set @targetCols += ','; set @selectCols += ','; end
        set @targetCols += quotename('cycle_end_time');
        set @selectCols += quotename('window_end_time');
    end


    if exists(select 1 from sys.columns where object_id = object_id('dbo.history_trend_data') and name = 'value')
       and exists(select 1 from tempdb.sys.columns where object_id = object_id('tempdb..#ins') and name = 'aggregated_value')
       and charindex('[value]', @targetCols) = 0
    begin
        if len(@targetCols) > 0 begin set @targetCols += ','; set @selectCols += ','; end
        set @targetCols += quotename('value');
        set @selectCols += quotename('aggregated_value');
    end

    if exists(select 1 from sys.columns where object_id = object_id('dbo.history_trend_data') and name = 'value')
       and exists(select 1 from tempdb.sys.columns where object_id = object_id('tempdb..#ins') and name = 'agg_value')
       and charindex('[value]', @targetCols) = 0
    begin
        if len(@targetCols) > 0 begin set @targetCols += ','; set @selectCols += ','; end
        set @targetCols += quotename('value');
        set @selectCols += quotename('agg_value');
    end

    if exists(select 1 from sys.columns where object_id = object_id('dbo.history_trend_data') and name = 'stat_cycle')
    begin
        if charindex('[stat_cycle]', @targetCols) = 0
        begin
            if len(@targetCols) > 0 begin set @targetCols += ','; set @selectCols += ','; end
            set @targetCols += quotename('stat_cycle');
            set @selectCols += N'''Realtime''';
        end
    end

    if len(@targetCols) = 0
    begin
        drop table #ins;
        return;
    end

    set @sql = N'insert into dbo.history_trend_data(' + @targetCols + N') select ' + @selectCols + N' from #ins;';

    exec sp_executesql @sql;

    drop table #ins;
end;





-- 触发器：更新展示顺序时自动推动指标排序
create trigger trg_dashboard_config_update on dbo.dashboard_display_config
after
update
    as begin
update
    dbo.dashboard_config_metric
set
    display_order = display_order + 1
where
    config_id in (
        select
            config_id
        from
            inserted
    );

end;
