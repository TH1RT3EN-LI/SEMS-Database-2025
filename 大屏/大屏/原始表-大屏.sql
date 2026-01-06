/* ============================================================
   SQL Server DDL - 大屏管理业务线（按数据字典字段命名）
   ============================================================ */

IF OBJECT_ID(N'dbo.trend_analysis_report', N'U') IS NOT NULL DROP TABLE dbo.trend_analysis_report;
IF OBJECT_ID(N'dbo.dashboard_config_metric', N'U') IS NOT NULL DROP TABLE dbo.dashboard_config_metric;
IF OBJECT_ID(N'dbo.dashboard_display_config', N'U') IS NOT NULL DROP TABLE dbo.dashboard_display_config;
IF OBJECT_ID(N'dbo.history_trend_data', N'U') IS NOT NULL DROP TABLE dbo.history_trend_data;
IF OBJECT_ID(N'dbo.realtime_agg_snapshot', N'U') IS NOT NULL DROP TABLE dbo.realtime_agg_snapshot;
IF OBJECT_ID(N'dbo.stat_object', N'U') IS NOT NULL DROP TABLE dbo.stat_object;
GO


-- 存储过程：设置列描述（MS_Description扩展属性），这个可以不用管，只是为了给表和列添加注释用的，方便看，最后可能删掉
IF OBJECT_ID(N'dbo.usp_set_msdesc', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_set_msdesc;
GO
CREATE PROCEDURE dbo.usp_set_msdesc
    @schema_name SYSNAME,
    @table_name  SYSNAME,
    @column_name SYSNAME,
    @desc        NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;

    -- 若存在则先删除
    IF EXISTS (
        SELECT 1
        FROM sys.extended_properties ep
        JOIN sys.tables t ON ep.major_id = t.object_id
        JOIN sys.schemas s ON t.schema_id = s.schema_id
        JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = ep.minor_id
        WHERE ep.name = N'MS_Description'
          AND s.name = @schema_name
          AND t.name = @table_name
          AND c.name = @column_name
    )
    BEGIN
        EXEC sys.sp_dropextendedproperty
            @name = N'MS_Description',
            @level0type = N'SCHEMA', @level0name = @schema_name,
            @level1type = N'TABLE',  @level1name = @table_name,
            @level2type = N'COLUMN', @level2name = @column_name;
    END

    -- 再新增
    EXEC sys.sp_addextendedproperty
        @name = N'MS_Description',
        @value = @desc,
        @level0type = N'SCHEMA', @level0name = @schema_name,
        @level1type = N'TABLE',  @level1name = @table_name,
        @level2type = N'COLUMN', @level2name = @column_name;
END
GO



-- 统计对象
CREATE TABLE dbo.stat_object (
    stat_object_id      bigint IDENTITY(1000000000, 1) NOT NULL,
    stat_object_name    nvarchar(100) NOT NULL,
    unit                nvarchar(20)  NOT NULL,
    description         nvarchar(500) NULL,

    CONSTRAINT pk_stat_object
        PRIMARY KEY (stat_object_id),

    CONSTRAINT uq_stat_object_name
        UNIQUE (stat_object_name),

    CONSTRAINT ck_stat_object_unit_nonempty
        CHECK (LEN(LTRIM(RTRIM(unit))) > 0) -- 非空且非空白 -- 不枚举了保留扩展能力

);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'stat_object', N'stat_object_id',   N'统计对象编号';
EXEC dbo.usp_set_msdesc N'dbo', N'stat_object', N'stat_object_name', N'统计对象名称';
EXEC dbo.usp_set_msdesc N'dbo', N'stat_object', N'unit',             N'单位';
EXEC dbo.usp_set_msdesc N'dbo', N'stat_object', N'description',      N'说明';
GO

CREATE INDEX ix_stat_object_name
ON dbo.stat_object(stat_object_name);


-- 实时汇总快照
CREATE TABLE dbo.realtime_agg_snapshot (
    snapshot_id         bigint IDENTITY(1000000000, 1) NOT NULL,
    window_start_time   datetime2(0) NOT NULL,
    window_end_time     datetime2(0) NOT NULL,
    stat_object_id      bigint NOT NULL,
    stat_value          decimal(18, 2) NOT NULL,

    CONSTRAINT pk_realtime_agg_snapshot
        PRIMARY KEY (snapshot_id),

    CONSTRAINT fk_snapshot_stat_object
        FOREIGN KEY (stat_object_id)
        REFERENCES dbo.stat_object(stat_object_id),

    CONSTRAINT uq_snapshot_window_object
        UNIQUE (window_start_time, window_end_time, stat_object_id),

    CONSTRAINT ck_snapshot_window_order
        CHECK (window_end_time > window_start_time)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'realtime_agg_snapshot', N'snapshot_id',       N'汇总编号';
EXEC dbo.usp_set_msdesc N'dbo', N'realtime_agg_snapshot', N'window_start_time', N'窗口开始时间';
EXEC dbo.usp_set_msdesc N'dbo', N'realtime_agg_snapshot', N'window_end_time',   N'窗口结束时间';
EXEC dbo.usp_set_msdesc N'dbo', N'realtime_agg_snapshot', N'stat_object_id',    N'统计对象编号';
EXEC dbo.usp_set_msdesc N'dbo', N'realtime_agg_snapshot', N'stat_value',        N'统计值';
GO

CREATE INDEX ix_snapshot_object_time
ON dbo.realtime_agg_snapshot(stat_object_id, window_start_time, window_end_time);

CREATE INDEX ix_snapshot_window
ON dbo.realtime_agg_snapshot(window_start_time, window_end_time);




-- 历史趋势
CREATE TABLE dbo.history_trend_data (
    trend_id            bigint IDENTITY(1000000000, 1) NOT NULL,
    stat_cycle          nvarchar(10) NOT NULL,       -- day/week/month/year
    cycle_start_time    datetime2(0) NOT NULL,
    stat_object_id      bigint NOT NULL,
    trend_value         decimal(18, 2) NOT NULL,

    CONSTRAINT pk_history_trend_data
        PRIMARY KEY (trend_id),

    CONSTRAINT fk_trend_stat_object
        FOREIGN KEY (stat_object_id)
        REFERENCES dbo.stat_object(stat_object_id),

    CONSTRAINT uq_trend_cycle_start_object
        UNIQUE (stat_cycle, cycle_start_time, stat_object_id),

    CONSTRAINT ck_trend_cycle_enum
        CHECK (stat_cycle IN ('day', 'week', 'month', 'year'))
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'history_trend_data', N'trend_id',         N'趋势编号';
EXEC dbo.usp_set_msdesc N'dbo', N'history_trend_data', N'stat_cycle',       N'统计周期';
EXEC dbo.usp_set_msdesc N'dbo', N'history_trend_data', N'cycle_start_time', N'周期开始时间';
EXEC dbo.usp_set_msdesc N'dbo', N'history_trend_data', N'stat_object_id',   N'统计对象编号';
EXEC dbo.usp_set_msdesc N'dbo', N'history_trend_data', N'trend_value',      N'趋势值';
GO

CREATE INDEX ix_trend_object_cycle_time
ON dbo.history_trend_data(stat_object_id, stat_cycle, cycle_start_time);



-- 大屏配置
CREATE TABLE dbo.dashboard_display_config (
    config_id           bigint IDENTITY(1000000000, 1) NOT NULL,
    module_type         nvarchar(30) NOT NULL,    -- 枚举
    refresh_frequency_s int NOT NULL,            -- 刷新频率（秒)，不像任务书一样还分为分钟和秒
    sort_rule           nvarchar(100) NOT NULL,      -- 枚举，
    permission_level    nvarchar(100) NOT NULL,        -- 枚举

    CONSTRAINT pk_dashboard_display_config
        PRIMARY KEY (config_id),

    CONSTRAINT ck_config_refresh_positive
        CHECK (refresh_frequency_s > 0),

    CONSTRAINT ck_config_module_type_enum
        CHECK (module_type IN (N'能源总览', N'光伏总览', N'配电网运行状态', N'告警统计')),

    CONSTRAINT ck_config_sort_rule_enum
        CHECK (sort_rule IN (N'按时间降序', N'按时间升序', N'按值降序', N'按值升序')),

    -- 暂定，后面补充角色权限表之后再改
    CONSTRAINT ck_config_permission_level_enum
        CHECK (permission_level IN (N'管理员', N'能源管理员', N'运维人员'))
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'dashboard_display_config', N'config_id',         N'配置编号';
EXEC dbo.usp_set_msdesc N'dbo', N'dashboard_display_config', N'module_type',       N'展示模块类型';
EXEC dbo.usp_set_msdesc N'dbo', N'dashboard_display_config', N'refresh_frequency_s', N'数据刷新频率';
EXEC dbo.usp_set_msdesc N'dbo', N'dashboard_display_config', N'sort_rule',         N'排序规则';
EXEC dbo.usp_set_msdesc N'dbo', N'dashboard_display_config', N'permission_level',  N'权限等级';
GO

CREATE INDEX ix_config_module_permission
ON dbo.dashboard_display_config(module_type, permission_level);



--大屏配置指标
CREATE TABLE dbo.dashboard_config_metric (
    config_id       bigint NOT NULL,
    stat_object_id  bigint NOT NULL,
    display_order   int NOT NULL,

    CONSTRAINT pk_dashboard_config_metric
        PRIMARY KEY (config_id, stat_object_id),

    CONSTRAINT fk_cfg_metric_config
        FOREIGN KEY (config_id)
        REFERENCES dbo.dashboard_display_config(config_id),

    CONSTRAINT fk_cfg_metric_stat_object
        FOREIGN KEY (stat_object_id)
        REFERENCES dbo.stat_object(stat_object_id),

    CONSTRAINT ck_cfg_metric_display_order_positive
        CHECK (display_order >= 1),

    -- 同一配置内展示顺序不重复
    CONSTRAINT uq_cfg_metric_order
        UNIQUE (config_id, display_order)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'dashboard_config_metric', N'config_id',      N'配置编号';
EXEC dbo.usp_set_msdesc N'dbo', N'dashboard_config_metric', N'stat_object_id', N'统计指标编号';
EXEC dbo.usp_set_msdesc N'dbo', N'dashboard_config_metric', N'display_order',  N'展示顺序';
GO

CREATE INDEX ix_cfg_metric_object
ON dbo.dashboard_config_metric(stat_object_id);



-- 历史趋势分析报告
CREATE TABLE dbo.trend_analysis_report (
    report_id       bigint IDENTITY(1000000000, 1) NOT NULL,
    report_title    nvarchar(200) NOT NULL,
    report_summary  nvarchar(1000) NULL,
    report_content  nvarchar(max) NOT NULL,
    creator_user_id nvarchar(20) NOT NULL, -- 原: bigint，现对齐 sys_user.user_id
    created_at      datetime2(0) NOT NULL
        CONSTRAINT df_report_created_at DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT pk_trend_analysis_report
        PRIMARY KEY (report_id),

    CONSTRAINT fk_report_creator_user
        FOREIGN KEY (creator_user_id)
        REFERENCES dbo.sys_user(user_id)  -- 改动，原来是引用 bigint 类型的用户表，现在对齐 sys_user.user_id nvarchar(20)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'trend_analysis_report', N'report_id',       N'报告编号';
EXEC dbo.usp_set_msdesc N'dbo', N'trend_analysis_report', N'report_title',    N'报告标题';
EXEC dbo.usp_set_msdesc N'dbo', N'trend_analysis_report', N'report_summary',  N'报告摘要';
EXEC dbo.usp_set_msdesc N'dbo', N'trend_analysis_report', N'report_content',  N'报告内容';
EXEC dbo.usp_set_msdesc N'dbo', N'trend_analysis_report', N'creator_user_id', N'生成人ID';
EXEC dbo.usp_set_msdesc N'dbo', N'trend_analysis_report', N'created_at',      N'生成时间';
GO

CREATE INDEX ix_report_creator_time
ON dbo.trend_analysis_report(creator_user_id, created_at);
