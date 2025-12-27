/* ============================================================
   SQL Server DDL - 光伏管理业务线（按数据字典字段命名）
   ============================================================ */

IF OBJECT_ID(N'dbo.pv_generation_forecast_rel', N'U') IS NOT NULL DROP TABLE dbo.pv_generation_forecast_rel;
IF OBJECT_ID(N'dbo.pv_generation', N'U') IS NOT NULL DROP TABLE dbo.pv_generation;
IF OBJECT_ID(N'dbo.pv_forecast', N'U') IS NOT NULL DROP TABLE dbo.pv_forecast;
IF OBJECT_ID(N'dbo.pv_device', N'U') IS NOT NULL DROP TABLE dbo.pv_device;

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







-- 正式创建数据表



--- 1. 光伏设备信息表

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
    CONSTRAINT FK_pv_device_ledger FOREIGN KEY (device_id) REFERENCES dbo.device_ledger(device_id), -- 新增，关联设备台账表，和下一个表原有的外键不冲突，级联了
    CONSTRAINT CK_pv_device_comm_protocol_enum CHECK (communication_protocol IN (N'RS485', N'LoRa')) -- 与能耗统一通信协议枚举
);
GO

EXEC dbo.usp_set_msdesc N'dbo', N'pv_device', N'device_id',              N'设备编号';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_device', N'device_type',            N'设备类型';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_device', N'install_location',       N'安装位置';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_device', N'capacity_kwp',           N'装机容量';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_device', N'commission_time',        N'投运时间';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_device', N'calibration_cycle_month',N'校准周期';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_device', N'operation_status',       N'运行状态';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_device', N'communication_protocol', N'通信协议';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_device', N'grid_point_id',          N'并网点编号';
GO

CREATE TABLE dbo.pv_forecast (
    id BIGINT IDENTITY(1,1) NOT NULL, -- 新增自增主键
    forecast_id NVARCHAR(20) NOT NULL, -- 原: NVARCHAR(30)，统一编码长度 NVARCHAR(20)
    forecast_date DATE NOT NULL,
    forecast_period NVARCHAR(10) NOT NULL,
    predicted_generation_kwh DECIMAL(8,2) NOT NULL,
    actual_generation_kwh DECIMAL(8,2) NULL,
    model_version NVARCHAR(20) NOT NULL,
    device_id NVARCHAR(20) NOT NULL,
    grid_point_id NVARCHAR(20) NOT NULL,
    data_integrity NVARCHAR(10) NOT NULL,
    CONSTRAINT PK_pv_forecast PRIMARY KEY (id),
    CONSTRAINT UQ_pv_forecast_forecast_id UNIQUE (forecast_id), -- 原主键改为唯一约束，保留业务编码
    CONSTRAINT FK_pv_forecast_device FOREIGN KEY (device_id) REFERENCES dbo.pv_device(device_id) ON UPDATE CASCADE
);
GO

EXEC dbo.usp_set_msdesc N'dbo', N'pv_forecast', N'forecast_id',              N'预测编号';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_forecast', N'forecast_date',            N'预测日期';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_forecast', N'forecast_period',          N'预测时段';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_forecast', N'predicted_generation_kwh', N'预测发电量';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_forecast', N'actual_generation_kwh',    N'实际发电量';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_forecast', N'model_version',            N'预测模型版本';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_forecast', N'device_id',                N'设备编号';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_forecast', N'grid_point_id',            N'并网点编号';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_forecast', N'data_integrity',           N'数据完整性';
GO

CREATE TABLE dbo.pv_generation (
    id BIGINT IDENTITY(1,1) NOT NULL, -- 新增自增主键
    record_id NVARCHAR(20) NOT NULL, -- 原: NVARCHAR(30)，统一编码长度 NVARCHAR(20)
    collected_at datetime2(0) NOT NULL, -- 原: DATETIME
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
    CONSTRAINT UQ_pv_generation_record_id UNIQUE (record_id), -- 原主键改为唯一约束，保留业务编码
    CONSTRAINT FK_pv_generation_device FOREIGN KEY (device_id) REFERENCES dbo.pv_device(device_id) ON UPDATE CASCADE
);
GO

EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation', N'record_id',           N'数据编号';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation', N'collected_at',        N'采集时间';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation', N'generation_kwh',      N'发电量';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation', N'feeding_kwh',         N'上网电量';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation', N'selfuse_kwh',         N'自用电量';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation', N'inverter_efficiency', N'逆变器效率';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation', N'combiner_voltage',    N'汇流箱组串电压';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation', N'combiner_current',    N'汇流箱组串电流';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation', N'device_id',           N'设备编号';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation', N'grid_point_id',       N'并网点编号';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation', N'data_integrity',      N'数据完整性';
GO

CREATE TABLE dbo.pv_generation_forecast_rel (
    generation_id BIGINT NOT NULL,   -- 原: record_id NVARCHAR(20) 业务编码，改名为 generation_id 和表 pv_generation 加强对应，如果牵扯到很多前面的工作要改动可以不改
    forecast_id   BIGINT NOT NULL,   -- 原: forecast_id NVARCHAR(20) 业务编码
    CONSTRAINT PK_pv_generation_forecast_rel PRIMARY KEY (generation_id),
    CONSTRAINT FK_pv_rel_generation FOREIGN KEY (generation_id) REFERENCES dbo.pv_generation(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_pv_rel_forecast FOREIGN KEY (forecast_id) REFERENCES dbo.pv_forecast(id) ON UPDATE CASCADE,
    CONSTRAINT UQ_pv_rel_forecast UNIQUE (forecast_id)
);
GO

EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation_forecast_rel', N'generation_id',   N'发电数据主键（原 record_id 业务编码）';
EXEC dbo.usp_set_msdesc N'dbo', N'pv_generation_forecast_rel', N'forecast_id', N'预测数据主键（原 forecast_id 业务编码）';
GO

CREATE INDEX idx_pv_device_type_status ON dbo.pv_device(device_type, operation_status);
CREATE INDEX idx_pv_device_grid_point ON dbo.pv_device(grid_point_id);
CREATE INDEX idx_pv_device_commission_cycle ON dbo.pv_device(commission_time, calibration_cycle_month);
GO

CREATE INDEX idx_pv_generation_time_device ON dbo.pv_generation(collected_at DESC, device_id);
CREATE INDEX idx_pv_generation_device_efficiency ON dbo.pv_generation(device_id, inverter_efficiency) WHERE inverter_efficiency IS NOT NULL;
CREATE INDEX idx_pv_generation_grid_time ON dbo.pv_generation(grid_point_id, collected_at);
CREATE INDEX idx_pv_generation_integrity ON dbo.pv_generation(data_integrity);
GO

CREATE INDEX idx_pv_forecast_date_grid ON dbo.pv_forecast(forecast_date, grid_point_id);
CREATE INDEX idx_pv_forecast_id_actual ON dbo.pv_forecast(forecast_id, actual_generation_kwh);
CREATE INDEX idx_pv_forecast_model_date ON dbo.pv_forecast(model_version, forecast_date);
GO

CREATE INDEX idx_pv_rel_forecast_id ON dbo.pv_generation_forecast_rel(forecast_id);
GO
