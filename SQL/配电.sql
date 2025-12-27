/* ============================================================
   SQL Server DDL - 配电管理业务线（按数据字典字段命名）
   ============================================================ */
IF OBJECT_ID(N'dbo.transformer_monitoring_data', N'U') IS NOT NULL DROP TABLE dbo.transformer_monitoring_data;
IF OBJECT_ID(N'dbo.circuit_monitoring_data', N'U') IS NOT NULL DROP TABLE dbo.circuit_monitoring_data;
IF OBJECT_ID(N'dbo.transformer_info', N'U') IS NOT NULL DROP TABLE dbo.transformer_info;
IF OBJECT_ID(N'dbo.circuit_info', N'U') IS NOT NULL DROP TABLE dbo.circuit_info;
IF OBJECT_ID(N'dbo.power_distribution_room', N'U') IS NOT NULL DROP TABLE dbo.power_distribution_room;
IF OBJECT_ID(N'dbo.manager_info', N'U') IS NOT NULL DROP TABLE dbo.manager_info;
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



-- 1. 负责人信息表（R2：manager_info）
CREATE TABLE manager_info (
    manager_id NVARCHAR(20) PRIMARY KEY,  -- 原: VARCHAR(8)，统一编码长度 NVARCHAR(20)；负责人ID（主码）
    manager_name NVARCHAR(50) NOT NULL,   -- 原: VARCHAR(50)，支持中文姓名
    manager_gender NVARCHAR(2),           -- 原: VARCHAR(2)，支持中文性别标记
    manager_phone NVARCHAR(15)            -- 原: VARCHAR(15)，统一字符类型
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'manager_info', N'manager_id',     N'负责人ID';
EXEC dbo.usp_set_msdesc N'dbo', N'manager_info', N'manager_name',   N'负责人姓名';
EXEC dbo.usp_set_msdesc N'dbo', N'manager_info', N'manager_gender', N'负责人性别';
EXEC dbo.usp_set_msdesc N'dbo', N'manager_info', N'manager_phone',  N'负责人手机号';
GO

-- 2. 配电房基础信息表（R1：power_distribution_room）
CREATE TABLE power_distribution_room (
    room_id NVARCHAR(20) PRIMARY KEY,    -- 原: VARCHAR(10)，统一编码长度 NVARCHAR(20)；配电房编号（主码）
    room_name NVARCHAR(30) NOT NULL,    -- 配电房名称
    location_desc NVARCHAR(50),         -- 位置描述
    voltage_level NVARCHAR(10) NOT NULL, -- 原: VARCHAR(10)，统一字符类型；电压等级（枚举值：35KV、10KV、0.4KV）
    commission_time datetime2(0) NOT NULL,      -- 投运时间（原: DATE）
    manager_id NVARCHAR(20),              -- 原: VARCHAR(8)，负责人ID（外码，统一 NVARCHAR(20)）
    FOREIGN KEY (manager_id) REFERENCES manager_info(manager_id)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'power_distribution_room', N'room_id',         N'配电房编号';
EXEC dbo.usp_set_msdesc N'dbo', N'power_distribution_room', N'room_name',       N'配电房名称';
EXEC dbo.usp_set_msdesc N'dbo', N'power_distribution_room', N'location_desc',   N'位置描述';
EXEC dbo.usp_set_msdesc N'dbo', N'power_distribution_room', N'voltage_level',   N'电压等级';
EXEC dbo.usp_set_msdesc N'dbo', N'power_distribution_room', N'commission_time', N'投运时间';
EXEC dbo.usp_set_msdesc N'dbo', N'power_distribution_room', N'manager_id',      N'负责人ID';
GO

-- 3. 回路信息表（R3：circuit_info）
CREATE TABLE circuit_info (
    circuit_id NVARCHAR(20) PRIMARY KEY, -- 原: VARCHAR(12)，统一编码长度 NVARCHAR(20)；回路编号（主码）
    room_id NVARCHAR(20) NOT NULL,       -- 原: VARCHAR(10)，统一编码长度 NVARCHAR(20)；配电房编号（外码）
    circuit_name NVARCHAR(30) NOT NULL,  -- 原: VARCHAR(30)，支持中文回路名称
    voltage_system NVARCHAR(10) NOT NULL,-- 原: VARCHAR(10)，统一字符类型；所属系统（电压等级系统）
    rated_voltage_kv DECIMAL(4,2) NOT NULL, -- 额定电压
    rated_current_a DECIMAL(4,1) NOT NULL,  -- 额定电流
    voltage_upper_limit_kv DECIMAL(4,2) NOT NULL, -- 电压上限阈值
    voltage_lower_limit_kv DECIMAL(4,2) NOT NULL, -- 电压下限阈值
    current_upper_limit_a DECIMAL(4,1) NOT NULL,  -- 电流上限阈值
    FOREIGN KEY (room_id) REFERENCES power_distribution_room(room_id)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_info', N'circuit_id',             N'回路编号';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_info', N'room_id',                N'配电房编号';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_info', N'circuit_name',           N'回路名称';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_info', N'voltage_system',         N'所属系统';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_info', N'rated_voltage_kv',       N'额定电压';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_info', N'rated_current_a',        N'额定电流';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_info', N'voltage_upper_limit_kv', N'电压上限阈值';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_info', N'voltage_lower_limit_kv', N'电压下限阈值';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_info', N'current_upper_limit_a',  N'电流上限阈值';
GO

-- 4. 变压器信息表（R5：transformer_info）
CREATE TABLE transformer_info (
    device_id NVARCHAR(20) PRIMARY KEY,      -- 变压器编号（主码）
    room_id NVARCHAR(20) NOT NULL,            -- 原: VARCHAR(10)，统一编码长度 NVARCHAR(20)；配电房编号（外码）
    FOREIGN KEY (room_id) REFERENCES power_distribution_room(room_id),
    CONSTRAINT FK_transformer_ledger FOREIGN KEY (device_id) REFERENCES dbo.device_ledger(device_id) -- 新增，关联设备台账表，和数据那块原有的外键不冲突，级联了
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'transformer_info', N'device_id', N'变压器编号';
EXEC dbo.usp_set_msdesc N'dbo', N'transformer_info', N'room_id',   N'配电房编号';
GO

-- 5. 回路监测数据表（R4：circuit_monitoring_data）
CREATE TABLE circuit_monitoring_data (
    record_id BIGINT PRIMARY KEY IDENTITY(1,1),  -- 数据编号（主键，原: INT IDENTITY）
    circuit_id NVARCHAR(20) NOT NULL,          -- 原: VARCHAR(12)，统一编码长度 NVARCHAR(20)；回路编号（外码）
    collected_at DATETIME2(0) NOT NULL,       -- 采集时间
    voltage_kv DECIMAL(4,2) NOT NULL,         -- 电压
    current_a DECIMAL(4,1) NOT NULL,          -- 电流
    active_power_kw DECIMAL(4,1) NOT NULL,    -- 有功功率
    reactive_power_kvar DECIMAL(4,1) NOT NULL, -- 无功功率
    power_factor DECIMAL(4,3) NOT NULL,       -- 功率因数
    forward_energy_kwh DECIMAL(8,2) NOT NULL, -- 正向有功电量
    reverse_energy_kwh DECIMAL(8,2) NOT NULL, -- 反向有功电量
    switch_status NVARCHAR(10) NOT NULL,      -- 开关状态（合闸/分闸）
    cable_head_temp DECIMAL(4,1) NOT NULL,    -- 电缆头温度
    capacitor_temp DECIMAL(4,1) NOT NULL,     -- 电容器温度
    operation_status NVARCHAR(5) NOT NULL,   -- 运行状态（正常/异常，原: NVARCHAR(10))
    FOREIGN KEY (circuit_id) REFERENCES circuit_info(circuit_id)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'record_id',          N'数据编号';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'circuit_id',         N'回路编号';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'collected_at',       N'采集时间';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'voltage_kv',         N'电压';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'current_a',          N'电流';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'active_power_kw',    N'有功功率';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'reactive_power_kvar',N'无功功率';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'power_factor',       N'功率因数';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'forward_energy_kwh', N'正向有功电量';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'reverse_energy_kwh', N'反向有功电量';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'switch_status',      N'开关状态';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'cable_head_temp',    N'电缆头温度';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'capacitor_temp',     N'电容器温度';
EXEC dbo.usp_set_msdesc N'dbo', N'circuit_monitoring_data', N'operation_status',   N'运行状态';
GO

-- 6. 变压器监测数据表（R6：transformer_monitoring_data）
CREATE TABLE transformer_monitoring_data (
    record_id BIGINT PRIMARY KEY IDENTITY(1,1),    -- 数据编号（主键，原: INT IDENTITY）
    device_id NVARCHAR(20) NOT NULL,     -- 变压器编号（外码）
    collected_at DATETIME2(0) NOT NULL,       -- 采集时间（ISO 8601格式）
    load_rate DECIMAL(5,2) NOT NULL,          -- 负载率
    winding_temp DECIMAL(4,1) NOT NULL,       -- 绕组温度
    core_temp DECIMAL(4,1) NOT NULL,          -- 铁芯温度
    ambient_temp DECIMAL(4,1) NOT NULL,       -- 环境温度
    ambient_humidity DECIMAL(5,2) NOT NULL,   -- 环境湿度
    operation_status NVARCHAR(5) NOT NULL,   -- 运行状态（正常/异常，原: NVARCHAR(10))
    FOREIGN KEY (device_id) REFERENCES transformer_info(device_id)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'transformer_monitoring_data', N'record_id',        N'数据编号';
EXEC dbo.usp_set_msdesc N'dbo', N'transformer_monitoring_data', N'device_id',        N'变压器编号';
EXEC dbo.usp_set_msdesc N'dbo', N'transformer_monitoring_data', N'collected_at',     N'采集时间';
EXEC dbo.usp_set_msdesc N'dbo', N'transformer_monitoring_data', N'load_rate',        N'负载率';
EXEC dbo.usp_set_msdesc N'dbo', N'transformer_monitoring_data', N'winding_temp',     N'绕组温度';
EXEC dbo.usp_set_msdesc N'dbo', N'transformer_monitoring_data', N'core_temp',        N'铁芯温度';
EXEC dbo.usp_set_msdesc N'dbo', N'transformer_monitoring_data', N'ambient_temp',     N'环境温度';
EXEC dbo.usp_set_msdesc N'dbo', N'transformer_monitoring_data', N'ambient_humidity', N'环境湿度';
EXEC dbo.usp_set_msdesc N'dbo', N'transformer_monitoring_data', N'operation_status', N'运行状态';
GO
