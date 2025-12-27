/* ============================================================
   SQL Server DDL - 整合
   ============================================================ */

/* ---------- 删除表（按依赖顺序） ---------- */
IF OBJECT_ID(N'dbo.pv_generation_forecast_rel', N'U') IS NOT NULL DROP TABLE dbo.pv_generation_forecast_rel;
IF OBJECT_ID(N'dbo.pv_generation', N'U') IS NOT NULL DROP TABLE dbo.pv_generation;
IF OBJECT_ID(N'dbo.pv_forecast', N'U') IS NOT NULL DROP TABLE dbo.pv_forecast;
IF OBJECT_ID(N'dbo.pv_device', N'U') IS NOT NULL DROP TABLE dbo.pv_device;

IF OBJECT_ID(N'dbo.energy_peakvalley', N'U') IS NOT NULL DROP TABLE dbo.energy_peakvalley;
IF OBJECT_ID(N'dbo.energy_monitoring', N'U') IS NOT NULL DROP TABLE dbo.energy_monitoring;
IF OBJECT_ID(N'dbo.energy_meter', N'U') IS NOT NULL DROP TABLE dbo.energy_meter;
IF OBJECT_ID(N'dbo.pricing_strategy', N'U') IS NOT NULL DROP TABLE dbo.pricing_strategy;
IF OBJECT_ID(N'dbo.energy_category', N'U') IS NOT NULL DROP TABLE dbo.energy_category;
IF OBJECT_ID(N'dbo.plant_area', N'U') IS NOT NULL DROP TABLE dbo.plant_area;

IF OBJECT_ID(N'dbo.circuit_monitoring_data', N'U') IS NOT NULL DROP TABLE dbo.circuit_monitoring_data;
IF OBJECT_ID(N'dbo.transformer_monitoring_data', N'U') IS NOT NULL DROP TABLE dbo.transformer_monitoring_data;
IF OBJECT_ID(N'dbo.transformer_info', N'U') IS NOT NULL DROP TABLE dbo.transformer_info;
IF OBJECT_ID(N'dbo.circuit_info', N'U') IS NOT NULL DROP TABLE dbo.circuit_info;
IF OBJECT_ID(N'dbo.power_distribution_room', N'U') IS NOT NULL DROP TABLE dbo.power_distribution_room;
IF OBJECT_ID(N'dbo.manager_info', N'U') IS NOT NULL DROP TABLE dbo.manager_info;

IF OBJECT_ID(N'dbo.order_participant', N'U') IS NOT NULL DROP TABLE dbo.order_participant;
IF OBJECT_ID(N'dbo.device_maintenance_assignment', N'U') IS NOT NULL DROP TABLE dbo.device_maintenance_assignment;
IF OBJECT_ID(N'dbo.device_calibration_record', N'U') IS NOT NULL DROP TABLE dbo.device_calibration_record;
IF OBJECT_ID(N'dbo.maintenance_order', N'U') IS NOT NULL DROP TABLE dbo.maintenance_order;
IF OBJECT_ID(N'dbo.alarm_audit_record', N'U') IS NOT NULL DROP TABLE dbo.alarm_audit_record;
IF OBJECT_ID(N'dbo.alarm_record', N'U') IS NOT NULL DROP TABLE dbo.alarm_record;
IF OBJECT_ID(N'dbo.alarm_rule', N'U') IS NOT NULL DROP TABLE dbo.alarm_rule;

IF OBJECT_ID(N'dbo.trend_analysis_report', N'U') IS NOT NULL DROP TABLE dbo.trend_analysis_report;
IF OBJECT_ID(N'dbo.dashboard_config_metric', N'U') IS NOT NULL DROP TABLE dbo.dashboard_config_metric;
IF OBJECT_ID(N'dbo.dashboard_display_config', N'U') IS NOT NULL DROP TABLE dbo.dashboard_display_config;
IF OBJECT_ID(N'dbo.history_trend_data', N'U') IS NOT NULL DROP TABLE dbo.history_trend_data;
IF OBJECT_ID(N'dbo.realtime_agg_snapshot', N'U') IS NOT NULL DROP TABLE dbo.realtime_agg_snapshot;
IF OBJECT_ID(N'dbo.stat_object', N'U') IS NOT NULL DROP TABLE dbo.stat_object;

IF OBJECT_ID(N'dbo.device_ledger', N'U') IS NOT NULL DROP TABLE dbo.device_ledger;
IF OBJECT_ID(N'dbo.sys_user', N'U') IS NOT NULL DROP TABLE dbo.sys_user;
GO

/* ---------- 公用过程：设置列描述 ---------- */
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
    EXEC sys.sp_addextendedproperty
        @name = N'MS_Description',
        @value = @desc,
        @level0type = N'SCHEMA', @level0name = @schema_name,
        @level1type = N'TABLE',  @level1name = @table_name,
        @level2type = N'COLUMN', @level2name = @column_name;
END
GO

/* ---------- 基础表：用户 / 台账 ---------- */
CREATE TABLE dbo.sys_user (
    user_id NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_sys_user PRIMARY KEY (user_id)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'sys_user', N'user_id', N'用户编号（供各表外键引用）';
GO

CREATE TABLE dbo.device_ledger (
    device_id       NVARCHAR(20)  NOT NULL,
    device_type     NVARCHAR(20)  NOT NULL,
    device_name     NVARCHAR(50)  NOT NULL,
    model_spec      NVARCHAR(50)  NULL,
    install_time    datetime2(0)  NOT NULL, -- 原: DATETIME
    warranty_years  INT           NOT NULL,
    scrap_status    NVARCHAR(20)  NOT NULL,
    CONSTRAINT PK_device_ledger PRIMARY KEY (device_id),
    CONSTRAINT CK_device_ledger_warranty_years CHECK (warranty_years >= 0),
    CONSTRAINT CK_device_ledger_scrap_status CHECK (scrap_status IN (N'正常使用', N'已报废'))
);
GO

/* ---------- 能源/厂区主数据 ---------- */
CREATE TABLE plant_area (
    plant_area_id   NVARCHAR(20) NOT NULL,
    plant_area_name NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_plant_area PRIMARY KEY (plant_area_id),
    CONSTRAINT CK_plant_area_id_format_pa CHECK (
        LEN(plant_area_id) BETWEEN 2 AND 20
        AND PATINDEX('%[^0-9A-Za-z]%', plant_area_id) = 0
    )
);
GO

CREATE TABLE energy_category (
    energy_type NVARCHAR(20) NOT NULL,
    unit        NVARCHAR(10) NOT NULL,
    CONSTRAINT PK_energy_category PRIMARY KEY (energy_type),
    CONSTRAINT CK_energy_category_energy_type_enum CHECK (energy_type IN (N'水', N'蒸汽', N'天然气', N'电')),
    CONSTRAINT CK_energy_category_unit_enum CHECK (unit IN (N'm3', N't', N'kWh'))
);
GO

CREATE TABLE pricing_strategy (
    strategy_id  NVARCHAR(20) NOT NULL,     -- 原: VARCHAR(20)，统一为 NVARCHAR
    energy_type  NVARCHAR(20) NOT NULL,     -- 电/水/蒸汽/天然气
    peak_price   DECIMAL(4,2) NOT NULL,
    high_price   DECIMAL(4,2) NOT NULL,
    flat_price   DECIMAL(4,2) NOT NULL,
    valley_price DECIMAL(4,2) NOT NULL,
    CONSTRAINT PK_pricing_strategy PRIMARY KEY (strategy_id),
    CONSTRAINT FK_pricing_strategy_energy FOREIGN KEY (energy_type) REFERENCES energy_category (energy_type),
    -- strategy_id：以 ST 开头，后续仅字母数字
    CONSTRAINT CK_pricing_strategy_id_format CHECK (
        strategy_id LIKE 'ST%'
        AND PATINDEX('%[^0-9A-Za-z]%', strategy_id) = 0
    ),
    CONSTRAINT CK_pricing_strategy_price_range_peak   CHECK (peak_price   BETWEEN 0.00 AND 10.00),
    CONSTRAINT CK_pricing_strategy_price_range_high   CHECK (high_price   BETWEEN 0.00 AND 10.00),
    CONSTRAINT CK_pricing_strategy_price_range_flat   CHECK (flat_price   BETWEEN 0.00 AND 10.00),
    CONSTRAINT CK_pricing_strategy_price_range_valley CHECK (valley_price BETWEEN 0.00 AND 10.00)
);
GO

/* ---------- 能耗计量/监测 ---------- */
CREATE TABLE energy_meter (
    device_id               NVARCHAR(20)  NOT NULL,
    energy_type             NVARCHAR(20)  NOT NULL,
    install_location        NVARCHAR(100) NOT NULL,
    pipe_spec               NVARCHAR(10)  NOT NULL,
    communication_protocol  NVARCHAR(10)  NOT NULL,  -- 原 NVARCHAR(20) -> NVARCHAR(10)
    operation_status        NVARCHAR(5)   NOT NULL,
    calibration_cycle_month INT           NOT NULL,
    manufacturer            NVARCHAR(50)  NULL,
    plant_area_id           NVARCHAR(20)  NOT NULL,
    CONSTRAINT PK_energy_meter PRIMARY KEY (device_id),
    CONSTRAINT FK_energy_meter_area FOREIGN KEY (plant_area_id) REFERENCES plant_area(plant_area_id),
    CONSTRAINT FK_energy_meter_energy FOREIGN KEY (energy_type) REFERENCES energy_category(energy_type),
    CONSTRAINT FK_energy_meter_ledger FOREIGN KEY (device_id) REFERENCES dbo.device_ledger(device_id),
    CONSTRAINT CK_energy_meter_device_id_format CHECK (
        LEN(device_id) = 7
        AND LEFT(device_id, 2) IN (N'CS', N'LS', N'NG')
        AND SUBSTRING(device_id, 3, 5) LIKE '[0-9][0-9][0-9][0-9][0-9]'
    ),
    CONSTRAINT CK_energy_meter_pipe_spec_enum CHECK (pipe_spec IN (
        N'DN20', N'DN25', N'DN32', N'DN40', N'DN50', N'DN65',
        N'DN80', N'DN100', N'DN125', N'DN150'
    )),
    CONSTRAINT CK_energy_meter_comm_protocol_enum CHECK (communication_protocol IN (N'RS485', N'LoRa')),
    CONSTRAINT CK_energy_meter_operation_status_enum CHECK (operation_status IN (N'正常', N'故障')),
    CONSTRAINT CK_energy_meter_calibration_cycle_range CHECK (calibration_cycle_month BETWEEN 1 AND 24)
);
GO

CREATE TABLE energy_monitoring (
    id BIGINT IDENTITY(1,1) NOT NULL,       -- 主键
    monitoring_id  NVARCHAR(20) NOT NULL,  -- 业务编码 EMxxxxx
    device_id      NVARCHAR(20) NOT NULL,
    collected_at   datetime2(0) NOT NULL,
    energy_value   DECIMAL(8,2) NOT NULL,
    unit           NVARCHAR(10) NOT NULL,
    data_quality   NVARCHAR(2)  NOT NULL,
    plant_area_id  NVARCHAR(20) NOT NULL,
    -- data_integrity NVARCHAR(10) NOT NULL, -- 用视图实现
    CONSTRAINT PK_energy_monitoring PRIMARY KEY (id),
    CONSTRAINT FK_energy_monitoring_device FOREIGN KEY (device_id) REFERENCES energy_meter(device_id),
    CONSTRAINT FK_energy_monitoring_area FOREIGN KEY (plant_area_id) REFERENCES plant_area(plant_area_id),
    CONSTRAINT CK_energy_monitoring_id_format CHECK (
        LEN(monitoring_id) >= 7
        AND LEFT(monitoring_id, 2) = N'EM'
        AND SUBSTRING(monitoring_id, 3, 5) LIKE '[0-9][0-9][0-9][0-9][0-9]'
    ),
    CONSTRAINT CK_energy_monitoring_value_range CHECK (energy_value BETWEEN -999999.99 AND 999999.99),
    CONSTRAINT CK_energy_monitoring_unit_enum CHECK (unit IN (N'm3', N't', N'kWh')),
    CONSTRAINT CK_energy_monitoring_data_quality_enum CHECK (data_quality IN (N'优', N'良', N'中', N'差')),
    CONSTRAINT UQ_energy_monitoring_monitoring_id UNIQUE (monitoring_id)
);
GO

CREATE TABLE energy_peakvalley (
    id BIGINT IDENTITY(1,1) NOT NULL,       -- 主键
    peakvalley_id    NVARCHAR(20) NOT NULL,  -- 业务编码 PVxxxxx
    energy_type       NVARCHAR(20) NOT NULL,
    plant_area_id     NVARCHAR(20) NOT NULL,
    statistic_date    DATE         NOT NULL,
    peak_energy       DECIMAL(8,2) NOT NULL,
    high_energy       DECIMAL(8,2) NOT NULL,
    flat_energy       DECIMAL(8,2) NOT NULL,
    valley_energy     DECIMAL(8,2) NOT NULL,
    total_energy      DECIMAL(8,2) NOT NULL,
    peakvalley_price  DECIMAL(5,2) NOT NULL,
    energy_cost       DECIMAL(8,2) NOT NULL,
    strategy_id       NVARCHAR(20) NOT NULL, -- 原: VARCHAR(20)
    -- data_integrity    NVARCHAR(10) NOT NULL, -- 用视图实现
    CONSTRAINT PK_energy_peakvalley PRIMARY KEY (id),
    CONSTRAINT FK_peakvalley_energy FOREIGN KEY (energy_type) REFERENCES energy_category(energy_type),
    CONSTRAINT FK_peakvalley_area FOREIGN KEY (plant_area_id) REFERENCES plant_area(plant_area_id),
    CONSTRAINT FK_peakvalley_strategy FOREIGN KEY (strategy_id) REFERENCES pricing_strategy(strategy_id),
    CONSTRAINT CK_energy_peakvalley_id_format CHECK (
        LEN(peakvalley_id) >= 7
        AND LEFT(peakvalley_id, 2) = N'PV'
        AND SUBSTRING(peakvalley_id, 3, 5) LIKE '[0-9][0-9][0-9][0-9][0-9]'
    ),
    CONSTRAINT CK_energy_peakvalley_energy_type_enum CHECK (energy_type IN (N'水', N'蒸汽', N'天然气', N'电')),
    CONSTRAINT CK_energy_peakvalley_peak_energy_range    CHECK (peak_energy   BETWEEN -999999.99 AND 999999.99),
    CONSTRAINT CK_energy_peakvalley_high_energy_range    CHECK (high_energy   BETWEEN -999999.99 AND 999999.99),
    CONSTRAINT CK_energy_peakvalley_flat_energy_range    CHECK (flat_energy   BETWEEN -999999.99 AND 999999.99),
    CONSTRAINT CK_energy_peakvalley_valley_energy_range  CHECK (valley_energy BETWEEN -999999.99 AND 999999.99),
    CONSTRAINT CK_energy_peakvalley_total_energy_range   CHECK (total_energy  BETWEEN -999999.99 AND 999999.99),
    CONSTRAINT CK_energy_peakvalley_price_range CHECK (peakvalley_price BETWEEN 0.00 AND 10.00),
    CONSTRAINT CK_energy_peakvalley_energy_cost_range CHECK (energy_cost BETWEEN -999999.99 AND 999999.99),
    CONSTRAINT UQ_energy_peakvalley_peakvalley_id UNIQUE (peakvalley_id)
);
GO

/* ---------- 光伏设备与发电预测 ---------- */
CREATE TABLE dbo.pv_device (
    device_id NVARCHAR(20) NOT NULL,
    device_type NVARCHAR(10) NOT NULL,
    install_location NVARCHAR(50) NOT NULL,
    capacity_kwp DECIMAL(5,1) NOT NULL,
    commission_time datetime2(0) NOT NULL, -- 原: DATETIME
    calibration_cycle_month INT NOT NULL,
    operation_status NVARCHAR(5) NOT NULL, -- 原: NVARCHAR(10)
    communication_protocol NVARCHAR(10) NOT NULL,
    grid_point_id NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_pv_device PRIMARY KEY (device_id),
    CONSTRAINT FK_pv_device_ledger FOREIGN KEY (device_id) REFERENCES dbo.device_ledger(device_id),
    CONSTRAINT CK_pv_device_comm_protocol_enum CHECK (communication_protocol IN (N'RS485', N'LoRa'))
);
GO

CREATE TABLE dbo.pv_forecast (
    id BIGINT IDENTITY(1,1) NOT NULL, -- 主键
    forecast_id NVARCHAR(20) NOT NULL, -- 业务编码
    forecast_date DATE NOT NULL,
    forecast_period NVARCHAR(10) NOT NULL,
    predicted_generation_kwh DECIMAL(8,2) NOT NULL,
    actual_generation_kwh DECIMAL(8,2) NULL,
    model_version NVARCHAR(20) NOT NULL,
    device_id NVARCHAR(20) NOT NULL,
    grid_point_id NVARCHAR(20) NOT NULL,
    data_integrity NVARCHAR(10) NOT NULL,
    CONSTRAINT PK_pv_forecast PRIMARY KEY (id),
    CONSTRAINT UQ_pv_forecast_forecast_id UNIQUE (forecast_id),
    CONSTRAINT FK_pv_forecast_device FOREIGN KEY (device_id) REFERENCES dbo.pv_device(device_id)
);
GO

CREATE TABLE dbo.pv_generation (
    id BIGINT IDENTITY(1,1) NOT NULL, -- 主键
    record_id NVARCHAR(20) NOT NULL,  -- 业务编码
    collected_at datetime2(0) NOT NULL,
    generation_kwh DECIMAL(8,2) NOT NULL,
    feeding_kwh DECIMAL(8,2) NOT NULL,
    selfuse_kwh DECIMAL(8,2) NOT NULL,
    inverter_efficiency DECIMAL(5,2) NULL,
    combiner_voltage DECIMAL(4,1) NULL,
    combiner_current DECIMAL(4,1) NULL,
    device_id NVARCHAR(20) NOT NULL,
    grid_point_id NVARCHAR(20) NOT NULL,
    data_integrity NVARCHAR(10) NOT NULL,
    CONSTRAINT PK_pv_generation PRIMARY KEY (id),
    CONSTRAINT UQ_pv_generation_record_id UNIQUE (record_id),
    CONSTRAINT FK_pv_generation_device FOREIGN KEY (device_id) REFERENCES dbo.pv_device(device_id)
);
GO

CREATE TABLE dbo.pv_generation_forecast_rel (
    generation_id BIGINT NOT NULL,   -- 原: record_id NVARCHAR(20) 业务编码
    forecast_id   BIGINT NOT NULL,   -- 原: forecast_id NVARCHAR(20) 业务编码
    CONSTRAINT PK_pv_generation_forecast_rel PRIMARY KEY (generation_id),
    CONSTRAINT FK_pv_rel_generation FOREIGN KEY (generation_id) REFERENCES dbo.pv_generation(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_pv_rel_forecast FOREIGN KEY (forecast_id) REFERENCES dbo.pv_forecast(id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_pv_rel_forecast UNIQUE (forecast_id)
);
GO

/* ---------- 配电主数据与监测 ---------- */
CREATE TABLE manager_info (
    manager_id NVARCHAR(20) PRIMARY KEY,  -- 原: VARCHAR(8)
    manager_name NVARCHAR(50) NOT NULL,   -- 原: VARCHAR(50)
    manager_gender NVARCHAR(2),           -- 原: VARCHAR(2)
    manager_phone NVARCHAR(15)            -- 原: VARCHAR(15)
);
GO

CREATE TABLE power_distribution_room (
    room_id NVARCHAR(20) PRIMARY KEY,    -- 原: VARCHAR(10)
    room_name NVARCHAR(30) NOT NULL,
    location_desc NVARCHAR(50),
    voltage_level NVARCHAR(10) NOT NULL, -- 原: VARCHAR(10)
    commission_time datetime2(0) NOT NULL,      -- 原: DATE
    manager_id NVARCHAR(20),
    FOREIGN KEY (manager_id) REFERENCES manager_info(manager_id)
);
GO

CREATE TABLE circuit_info (
    circuit_id NVARCHAR(20) PRIMARY KEY, -- 原: VARCHAR(12)
    room_id NVARCHAR(20) NOT NULL,       -- 原: VARCHAR(10)
    circuit_name NVARCHAR(30) NOT NULL,  -- 原: VARCHAR(30)
    voltage_system NVARCHAR(10) NOT NULL,-- 原: VARCHAR(10)
    rated_voltage_kv DECIMAL(4,2) NOT NULL,
    rated_current_a DECIMAL(4,1) NOT NULL,
    voltage_upper_limit_kv DECIMAL(4,2) NOT NULL,
    voltage_lower_limit_kv DECIMAL(4,2) NOT NULL,
    current_upper_limit_a DECIMAL(4,1) NOT NULL,
    FOREIGN KEY (room_id) REFERENCES power_distribution_room(room_id)
);
GO

CREATE TABLE transformer_info (
    device_id NVARCHAR(20) PRIMARY KEY,      -- 变压器编号
    room_id NVARCHAR(20) NOT NULL,            -- 原: VARCHAR(10)
    FOREIGN KEY (room_id) REFERENCES power_distribution_room(room_id),
    CONSTRAINT FK_transformer_ledger FOREIGN KEY (device_id) REFERENCES dbo.device_ledger(device_id)
);
GO

CREATE TABLE circuit_monitoring_data (
    record_id BIGINT PRIMARY KEY IDENTITY(1,1),  -- 原: INT
    circuit_id NVARCHAR(20) NOT NULL,            -- 原: VARCHAR(12)
    collected_at DATETIME2(0) NOT NULL,
    voltage_kv DECIMAL(4,2) NOT NULL,
    current_a DECIMAL(4,1) NOT NULL,
    active_power_kw DECIMAL(4,1) NOT NULL,
    reactive_power_kvar DECIMAL(4,1) NOT NULL,
    power_factor DECIMAL(4,3) NOT NULL,
    forward_energy_kwh DECIMAL(8,2) NOT NULL,
    reverse_energy_kwh DECIMAL(8,2) NOT NULL,
    switch_status NVARCHAR(10) NOT NULL,
    cable_head_temp DECIMAL(4,1) NOT NULL,
    capacitor_temp DECIMAL(4,1) NOT NULL,
    operation_status NVARCHAR(5) NOT NULL,   -- 原: NVARCHAR(10)
    FOREIGN KEY (circuit_id) REFERENCES circuit_info(circuit_id)
);
GO

CREATE TABLE transformer_monitoring_data (
    record_id BIGINT PRIMARY KEY IDENTITY(1,1),    -- 原: INT
    device_id NVARCHAR(20) NOT NULL,
    collected_at DATETIME2(0) NOT NULL,
    load_rate DECIMAL(5,2) NOT NULL,
    winding_temp DECIMAL(4,1) NOT NULL,
    core_temp DECIMAL(4,1) NOT NULL,
    ambient_temp DECIMAL(4,1) NOT NULL,
    ambient_humidity DECIMAL(5,2) NOT NULL,
    operation_status NVARCHAR(5) NOT NULL,   -- 原: NVARCHAR(10)
    FOREIGN KEY (device_id) REFERENCES transformer_info(device_id)
);
GO

/* ---------- 告警运维 ---------- */
CREATE TABLE dbo.alarm_rule (
    rule_id           NVARCHAR(20)  NOT NULL,
    metric_field      NVARCHAR(50)  NOT NULL,
    compare_operator  NVARCHAR(5)   NOT NULL,
    threshold_value   DECIMAL(10,2) NOT NULL,
    unit              NVARCHAR(5)   NULL,
    alarm_type        NVARCHAR(20)  NOT NULL,
    alarm_level       NVARCHAR(10)  NOT NULL,
    description       NVARCHAR(255) NULL,
    enable_flag       BIT           NOT NULL CONSTRAINT DF_alarm_rule_enable_flag DEFAULT (1),
    CONSTRAINT PK_alarm_rule PRIMARY KEY (rule_id),
    CONSTRAINT CK_alarm_rule_compare_operator CHECK (compare_operator IN (N'>', N'>=', N'<', N'<=', N'=')),
    CONSTRAINT CK_alarm_rule_alarm_level CHECK (alarm_level IN (N'高', N'中', N'低')),
    CONSTRAINT CK_alarm_rule_alarm_type  CHECK (alarm_type IN (N'越限告警', N'通讯故障', N'设备故障')),
    CONSTRAINT CK_alarm_rule_threshold_range CHECK (threshold_value BETWEEN -99999999.99 AND 99999999.99)
);
GO

CREATE TABLE dbo.alarm_record (
    id BIGINT IDENTITY(1,1) NOT NULL,
    alarm_id      NVARCHAR(20) NOT NULL,
    occurred_at   datetime2(0)  NOT NULL,
    rule_id       NVARCHAR(20) NOT NULL,
    device_id     NVARCHAR(20) NOT NULL
    CONSTRAINT PK_alarm_record PRIMARY KEY (id),
    CONSTRAINT UQ_alarm_record_alarm_id UNIQUE (alarm_id),
    CONSTRAINT FK_alarm_record_rule  FOREIGN KEY (rule_id)  REFERENCES dbo.alarm_rule(rule_id),
    CONSTRAINT FK_alarm_record_device FOREIGN KEY (device_id) REFERENCES dbo.device_ledger(device_id)
);
GO

CREATE TABLE dbo.alarm_audit_record (
    id BIGINT IDENTITY(1,1) NOT NULL,
    audit_record_id   NVARCHAR(20) NOT NULL,
    alarm_id          NVARCHAR(20) NOT NULL,
    auditor_user_id   NVARCHAR(20) NOT NULL,
    audit_time        datetime2(0) NOT NULL,
    audit_result      NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_alarm_audit_record PRIMARY KEY (id),
    CONSTRAINT UQ_alarm_audit_record_audit_record_id UNIQUE (audit_record_id),
    CONSTRAINT FK_alarm_audit_record_alarm   FOREIGN KEY (alarm_id)        REFERENCES dbo.alarm_record(alarm_id),
    CONSTRAINT FK_alarm_audit_record_auditor FOREIGN KEY (auditor_user_id) REFERENCES dbo.sys_user(user_id)
);
GO

CREATE TABLE dbo.maintenance_order (
    id BIGINT IDENTITY(1,1) NOT NULL,
    order_id         NVARCHAR(20)  NOT NULL,
    alarm_id         NVARCHAR(20)  NOT NULL,
    dispatch_time    datetime2(0)  NOT NULL,
    response_time    datetime2(0)  NULL,
    finish_time      datetime2(0)  NULL,
    process_result   NVARCHAR(255) NULL,
    review_status    NVARCHAR(20)  NULL,
    attachment_path  NVARCHAR(255) NULL,
    CONSTRAINT PK_maintenance_order PRIMARY KEY (id),
    CONSTRAINT UQ_maintenance_order_order_id UNIQUE (order_id),
    CONSTRAINT FK_maintenance_order_alarm FOREIGN KEY (alarm_id) REFERENCES dbo.alarm_record(alarm_id),
    CONSTRAINT CK_maintenance_order_review_status CHECK (review_status IS NULL OR review_status IN (N'通过', N'退回', N'待复查'))
);
GO

CREATE TABLE dbo.order_participant (
    order_id             NVARCHAR(20) NOT NULL,
    participant_user_id  NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_order_participant PRIMARY KEY (order_id, participant_user_id),
    CONSTRAINT FK_order_participant_order FOREIGN KEY (order_id)            REFERENCES dbo.maintenance_order(order_id),
    CONSTRAINT FK_order_participant_user  FOREIGN KEY (participant_user_id) REFERENCES dbo.sys_user(user_id)
);
GO

CREATE TABLE dbo.device_maintenance_assignment (
    device_id            NVARCHAR(20) NOT NULL,
    participant_user_id  NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_device_maintenance_assignment PRIMARY KEY (device_id, participant_user_id),
    CONSTRAINT FK_device_maintenance_assignment_device FOREIGN KEY (device_id)           REFERENCES dbo.device_ledger(device_id),
    CONSTRAINT FK_device_maintenance_assignment_user   FOREIGN KEY (participant_user_id) REFERENCES dbo.sys_user(user_id)
);
GO

CREATE TABLE dbo.device_calibration_record (
    id BIGINT IDENTITY(1,1) NOT NULL,
    calibration_id     NVARCHAR(20)  NOT NULL,
    device_id          NVARCHAR(20)  NOT NULL,
    calibrator_id      NVARCHAR(20)  NOT NULL,
    calibration_time   datetime2(0)  NOT NULL,
    calibration_result NVARCHAR(20)  NOT NULL,
    calibration_note   NVARCHAR(255) NULL,
    CONSTRAINT PK_device_calibration_record PRIMARY KEY (id),
    CONSTRAINT UQ_device_calibration_record_calibration_id UNIQUE (calibration_id),
    CONSTRAINT FK_device_calibration_record_device FOREIGN KEY (device_id)     REFERENCES dbo.device_ledger(device_id),
    CONSTRAINT FK_device_calibration_record_user   FOREIGN KEY (calibrator_id) REFERENCES dbo.sys_user(user_id)
);
GO

/* ---------- 大屏/统计 ---------- */
CREATE TABLE dbo.stat_object (
    stat_object_id      bigint IDENTITY(1000000000, 1) NOT NULL,
    stat_object_name    nvarchar(100) NOT NULL,
    unit                nvarchar(20)  NOT NULL,
    description         nvarchar(500) NULL,
    CONSTRAINT pk_stat_object PRIMARY KEY (stat_object_id),
    CONSTRAINT uq_stat_object_name UNIQUE (stat_object_name),
    CONSTRAINT ck_stat_object_unit_nonempty CHECK (LEN(LTRIM(RTRIM(unit))) > 0)
);
GO

CREATE TABLE dbo.realtime_agg_snapshot (
    snapshot_id         bigint IDENTITY(1000000000, 1) NOT NULL,
    window_start_time   datetime2(0) NOT NULL,
    window_end_time     datetime2(0) NOT NULL,
    stat_object_id      bigint NOT NULL,
    stat_value          decimal(18, 2) NOT NULL,
    CONSTRAINT pk_realtime_agg_snapshot PRIMARY KEY (snapshot_id),
    CONSTRAINT fk_snapshot_stat_object FOREIGN KEY (stat_object_id) REFERENCES dbo.stat_object(stat_object_id),
    CONSTRAINT uq_snapshot_window_object UNIQUE (window_start_time, window_end_time, stat_object_id),
    CONSTRAINT ck_snapshot_window_order CHECK (window_end_time > window_start_time),
    CONSTRAINT ck_snapshot_stat_value_nonnegative CHECK (stat_value >= 0)
);
GO

CREATE TABLE dbo.history_trend_data (
    trend_id            bigint IDENTITY(1000000000, 1) NOT NULL,
    stat_cycle          nvarchar(10) NOT NULL,       -- day/week/month/year
    cycle_start_time    datetime2(0) NOT NULL,
    stat_object_id      bigint NOT NULL,
    trend_value         decimal(18, 2) NOT NULL,
    CONSTRAINT pk_history_trend_data PRIMARY KEY (trend_id),
    CONSTRAINT fk_trend_stat_object FOREIGN KEY (stat_object_id) REFERENCES dbo.stat_object(stat_object_id),
    CONSTRAINT uq_trend_cycle_start_object UNIQUE (stat_cycle, cycle_start_time, stat_object_id),
    CONSTRAINT ck_trend_cycle_enum CHECK (stat_cycle IN ('day', 'week', 'month', 'year')),
    CONSTRAINT ck_trend_value_nonnegative CHECK (trend_value >= 0)
);
GO

CREATE TABLE dbo.dashboard_display_config (
    config_id           bigint IDENTITY(1000000000, 1) NOT NULL,
    module_type         nvarchar(30) NOT NULL,
    refresh_frequency_s int NOT NULL,
    sort_rule           nvarchar(100) NOT NULL,
    permission_level    nvarchar(100) NOT NULL,
    CONSTRAINT pk_dashboard_display_config PRIMARY KEY (config_id),
    CONSTRAINT ck_config_refresh_positive CHECK (refresh_frequency_s > 0),
    CONSTRAINT ck_config_module_type_enum CHECK (module_type IN (N'能源总览', N'光伏总览', N'配电网运行状态', N'告警统计')),
    CONSTRAINT ck_config_sort_rule_enum CHECK (sort_rule IN (N'按时间降序', N'按时间升序', N'按值降序', N'按值升序')),
    CONSTRAINT ck_config_permission_level_enum CHECK (permission_level IN (N'管理员', N'能源管理员', N'运维人员'))
);
GO

CREATE TABLE dbo.dashboard_config_metric (
    config_id       bigint NOT NULL,
    stat_object_id  bigint NOT NULL,
    display_order   int NOT NULL,
    CONSTRAINT pk_dashboard_config_metric PRIMARY KEY (config_id, stat_object_id),
    CONSTRAINT fk_cfg_metric_config FOREIGN KEY (config_id) REFERENCES dbo.dashboard_display_config(config_id),
    CONSTRAINT fk_cfg_metric_stat_object FOREIGN KEY (stat_object_id) REFERENCES dbo.stat_object(stat_object_id),
    CONSTRAINT ck_cfg_metric_display_order_positive CHECK (display_order >= 1),
    CONSTRAINT uq_cfg_metric_order UNIQUE (config_id, display_order)
);
GO

CREATE TABLE dbo.trend_analysis_report (
    report_id       bigint IDENTITY(1000000000, 1) NOT NULL,
    report_title    nvarchar(200) NOT NULL,
    report_summary  nvarchar(1000) NULL,
    report_content  nvarchar(max) NOT NULL,
    creator_user_id nvarchar(20) NOT NULL, -- 原: bigint，现对齐 sys_user.user_id
    created_at      datetime2(0) NOT NULL CONSTRAINT df_report_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_trend_analysis_report PRIMARY KEY (report_id),
    CONSTRAINT fk_report_creator_user FOREIGN KEY (creator_user_id) REFERENCES dbo.sys_user(user_id)
);
GO

