/* ============================================================
   SQL Server DDL - 综合能耗管理业务线（按数据字典字段命名）
   ============================================================ */

IF OBJECT_ID(N'dbo.energy_peakvalley', N'U') IS NOT NULL DROP TABLE dbo.energy_peakvalley;
IF OBJECT_ID(N'dbo.energy_monitoring', N'U') IS NOT NULL DROP TABLE dbo.energy_monitoring;
IF OBJECT_ID(N'dbo.energy_meter', N'U') IS NOT NULL DROP TABLE dbo.energy_meter;
IF OBJECT_ID(N'dbo.pricing_strategy', N'U') IS NOT NULL DROP TABLE dbo.pricing_strategy;
IF OBJECT_ID(N'dbo.energy_category', N'U') IS NOT NULL DROP TABLE dbo.energy_category;
IF OBJECT_ID(N'dbo.plant_area', N'U') IS NOT NULL DROP TABLE dbo.plant_area;
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




/* ============================================================
   R1 厂区基础信息表 plant_area
   - plant_area_id: 格式 XY（字母数字结合），示例 A3、B2、C2
   ============================================================ */
CREATE TABLE plant_area (
    plant_area_id   NVARCHAR(20) NOT NULL,
    plant_area_name NVARCHAR(50) NOT NULL,

    CONSTRAINT PK_plant_area PRIMARY KEY (plant_area_id),

    -- 取值约束：字母数字结合；并尽量贴近示例（至少2位，且只含字母数字）
    CONSTRAINT CK_plant_area_id_format_pa -- 重命名加表名前缀，避免跨表约束重名
        CHECK (
            LEN(plant_area_id) BETWEEN 2 AND 20
            AND PATINDEX('%[^0-9A-Za-z]%', plant_area_id) = 0
        )
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'plant_area', N'plant_area_id',   N'厂区编号';
EXEC dbo.usp_set_msdesc N'dbo', N'plant_area', N'plant_area_name', N'厂区名称';
GO


/* ============================================================
   R5 能源分类表 energy_category
   - energy_type: 枚举 水/蒸汽/天然气/电
   - unit: 枚举 m³ / t / kWh
   ============================================================ */
CREATE TABLE energy_category (
    energy_type NVARCHAR(20) NOT NULL,
    unit        NVARCHAR(10) NOT NULL,

    CONSTRAINT PK_energy_category PRIMARY KEY (energy_type),

    CONSTRAINT CK_energy_category_energy_type_enum -- 重命名加表前缀，避免跨表约束重名
        CHECK (energy_type IN (N'水', N'蒸汽', N'天然气', N'电')),

    CONSTRAINT CK_energy_category_unit_enum -- 重命名加表前缀，避免跨表约束重名
        CHECK (unit IN (N'm³', N't', N'kWh'))
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'energy_category', N'energy_type', N'能源类型';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_category', N'unit',        N'单位';
GO

/* ============================================================
   R6 能源计价策略表 pricing_strategy
   - strategy_id: VARCHAR(20)（唯一编码）
   - peak/high/flat/valley_price: 0.00–10.00
   ============================================================ */
CREATE TABLE pricing_strategy (
    strategy_id  NVARCHAR(20) NOT NULL,     -- 原: VARCHAR(20)，统一字符类型为 NVARCHAR；例：ST_ELEC_2025 / ST_WATER_2025 / ST_STEAM_2025 / ST_GAS_2025
    energy_type  NVARCHAR(20) NOT NULL,     -- 电/水/蒸汽/天然气

    peak_price   DECIMAL(4,2) NOT NULL,     -- 0.00–10.00
    high_price   DECIMAL(4,2) NOT NULL,     -- 0.00–10.00
    flat_price   DECIMAL(4,2) NOT NULL,     -- 0.00–10.00
    valley_price DECIMAL(4,2) NOT NULL,     -- 0.00–10.00

    CONSTRAINT PK_pricing_strategy
        PRIMARY KEY (strategy_id),

    CONSTRAINT FK_pricing_strategy_energy
        FOREIGN KEY (energy_type)
        REFERENCES energy_category (energy_type),
    -- 下面这里有修改！！！！！！！！！！！！！！！！！！去掉了ST后面的下划线，和其他的统一
    -- strategy_id：改为必须以 ST 开头，后面仅字母数字（不再允许下划线，便于统一编码和比对）
    CONSTRAINT CK_pricing_strategy_id_format -- 重命名加表前缀，避免跨表约束重名；限制 ST + 字母数字
        CHECK (
            strategy_id LIKE 'ST%'
            AND PATINDEX('%[^0-9A-Za-z]%', strategy_id) = 0
        ),

    CONSTRAINT CK_pricing_strategy_price_range_peak   CHECK (peak_price   BETWEEN 0.00 AND 10.00), -- 重命名加表前缀
    CONSTRAINT CK_pricing_strategy_price_range_high   CHECK (high_price   BETWEEN 0.00 AND 10.00), -- 重命名加表前缀
    CONSTRAINT CK_pricing_strategy_price_range_flat   CHECK (flat_price   BETWEEN 0.00 AND 10.00), -- 重命名加表前缀
    CONSTRAINT CK_pricing_strategy_price_range_valley CHECK (valley_price BETWEEN 0.00 AND 10.00)  -- 重命名加表前缀
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'pricing_strategy', N'strategy_id',  N'策略编号';
EXEC dbo.usp_set_msdesc N'dbo', N'pricing_strategy', N'energy_type',  N'能源类型';
EXEC dbo.usp_set_msdesc N'dbo', N'pricing_strategy', N'peak_price',   N'尖峰单价';
EXEC dbo.usp_set_msdesc N'dbo', N'pricing_strategy', N'high_price',   N'高峰单价';
EXEC dbo.usp_set_msdesc N'dbo', N'pricing_strategy', N'flat_price',   N'平段单价';
EXEC dbo.usp_set_msdesc N'dbo', N'pricing_strategy', N'valley_price', N'低谷单价';
GO

/* ============================================================
   R2 能耗计量设备表 energy_meter
   - device_id: 格式 TTXXXXX；TT: CS=水 LS=蒸汽 NG=天然气；示例 CS10004
   - pipe_spec: DN20/DN25/.../DN150
   - communication_protocol: RS485/LoRa
   - operation_status: 正常/故障
   - calibration_cycle_month: 1–24
   ============================================================ */
CREATE TABLE energy_meter (
    device_id               NVARCHAR(20)  NOT NULL,
    energy_type             NVARCHAR(20)  NOT NULL,
    install_location        NVARCHAR(100) NOT NULL,
    pipe_spec               NVARCHAR(10)  NOT NULL,
    communication_protocol  NVARCHAR(10)  NOT NULL,  -- 原来是 NVARCHAR(20)，改成 NVARCHAR(10)，因为暂时只有两个值没有其他的，本身10个也足够长，和gyx那块的统一一下
    operation_status        NVARCHAR(5)   NOT NULL,
    calibration_cycle_month INT           NOT NULL,
    manufacturer            NVARCHAR(50)  NULL,
    plant_area_id           NVARCHAR(20)  NOT NULL,

    CONSTRAINT PK_energy_meter PRIMARY KEY (device_id),

    CONSTRAINT FK_energy_meter_area
        FOREIGN KEY (plant_area_id) REFERENCES plant_area(plant_area_id),

    CONSTRAINT FK_energy_meter_energy
        FOREIGN KEY (energy_type) REFERENCES energy_category(energy_type),

    CONSTRAINT FK_energy_meter_ledger
        FOREIGN KEY (device_id) REFERENCES dbo.device_ledger(device_id), -- 新增，关联设备台账表，和下一个表原有的外键不冲突，级联了

    -- device_id 格式：CS/LS/NG + 5位数字
    CONSTRAINT CK_energy_meter_device_id_format -- 重命名加表前缀，避免跨表约束重名
        CHECK (
            LEN(device_id) = 7
            AND LEFT(device_id, 2) IN (N'CS', N'LS', N'NG')
            AND SUBSTRING(device_id, 3, 5) LIKE '[0-9][0-9][0-9][0-9][0-9]'
        ),

    CONSTRAINT CK_energy_meter_pipe_spec_enum -- 重命名加表前缀，避免跨表约束重名
        CHECK (pipe_spec IN (
            N'DN20', N'DN25', N'DN32', N'DN40', N'DN50', N'DN65',
            N'DN80', N'DN100', N'DN125', N'DN150'
        )),

    CONSTRAINT CK_energy_meter_comm_protocol_enum -- 保留表前缀，避免跨表约束重名
        CHECK (communication_protocol IN (N'RS485', N'LoRa')), -- 已有表前缀，保持统一命名避免跨表重名

    CONSTRAINT CK_energy_meter_operation_status_enum -- 重命名加表前缀，避免跨表约束重名
        CHECK (operation_status IN (N'正常', N'故障')),

    CONSTRAINT CK_energy_meter_calibration_cycle_range -- 重命名加表前缀，避免跨表约束重名
        CHECK (calibration_cycle_month BETWEEN 1 AND 24)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'energy_meter', N'device_id',              N'设备编号';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_meter', N'energy_type',            N'能源类型';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_meter', N'install_location',       N'安装位置';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_meter', N'pipe_spec',              N'管径规格';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_meter', N'communication_protocol', N'通讯协议';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_meter', N'operation_status',       N'运行状态';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_meter', N'calibration_cycle_month',N'校准周期';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_meter', N'manufacturer',           N'生产厂家';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_meter', N'plant_area_id',          N'厂区编号';
GO


/* ============================================================
   R3 能耗监测数据表 energy_monitoring
   - 主键改名：monitoring_id（避免与R4重名）
   - monitoring_id 格式：EMXXXXX
   - collected_at 格式：datetime2(0)（原 DATETIME）
   - energy_value 范围：-999999.99–999999.99（负值视为异常，但字典允许入库）
   - unit 枚举：m³ / t / kWh
   - data_quality 枚举：优/良/中/差
   - data_integrity：完整/不完整
   ============================================================ */
CREATE TABLE energy_monitoring (
    id BIGINT IDENTITY(1,1) NOT NULL,       -- 新增自增主键
    monitoring_id  NVARCHAR(20) NOT NULL,  -- 原: NVARCHAR(30) / record_id (EMXXXXX)，统一编码长度 NVARCHAR(20)
    device_id      NVARCHAR(20) NOT NULL,
    collected_at   datetime2(0) NOT NULL, -- 原: DATETIME
    energy_value   DECIMAL(8,2) NOT NULL,
    unit           NVARCHAR(10) NOT NULL,
    data_quality   NVARCHAR(2)  NOT NULL,
    plant_area_id  NVARCHAR(20) NOT NULL,
    -- data_integrity NVARCHAR(10) NOT NULL, -- 用视图实现，不再存储物理字段

    CONSTRAINT PK_energy_monitoring PRIMARY KEY (id),

    CONSTRAINT FK_energy_monitoring_device
        FOREIGN KEY (device_id) REFERENCES energy_meter(device_id),

    CONSTRAINT FK_energy_monitoring_area
        FOREIGN KEY (plant_area_id) REFERENCES plant_area(plant_area_id),

    -- EM + 5位数字（字典：EM00001–EM99999）
    CONSTRAINT CK_energy_monitoring_id_format -- 重命名加表前缀，避免跨表约束重名
        CHECK (
            LEN(monitoring_id) >= 7
            AND LEFT(monitoring_id, 2) = N'EM'
            AND SUBSTRING(monitoring_id, 3, 5) LIKE '[0-9][0-9][0-9][0-9][0-9]'
        ),

    CONSTRAINT CK_energy_monitoring_value_range -- 重命名加表前缀，避免跨表约束重名
        CHECK (energy_value BETWEEN -999999.99 AND 999999.99),

    CONSTRAINT CK_energy_monitoring_unit_enum -- 重命名加表前缀，避免跨表约束重名
        CHECK (unit IN (N'm³', N't', N'kWh')),

    CONSTRAINT CK_energy_monitoring_data_quality_enum -- 重命名加表前缀，避免跨表约束重名
        CHECK (data_quality IN (N'优', N'良', N'中', N'差')),

    CONSTRAINT UQ_energy_monitoring_monitoring_id UNIQUE (monitoring_id) -- 原主键改为唯一约束，保留业务编码
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'energy_monitoring', N'monitoring_id',  N'数据编号';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_monitoring', N'device_id',      N'设备编号';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_monitoring', N'collected_at',   N'采集时间';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_monitoring', N'energy_value',   N'能耗值';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_monitoring', N'unit',           N'单位';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_monitoring', N'data_quality',   N'数据质量';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_monitoring', N'plant_area_id',  N'厂区编号';
-- EXEC dbo.usp_set_msdesc N'dbo', N'energy_monitoring', N'data_integrity', N'数据完整性';
GO


/* ============================================================
   R4 峰谷能耗数据表 energy_peakvalley
   - 主键改名：peakvalley_id（避免与R3重名）
   - peakvalley_id 格式：PVXXXXX
   - energy_type 枚举：水/蒸汽/天然气/电（且FK到energy_category）
   - 能耗值范围：-999999.99–999999.99（负值视为异常，但字典允许范围）
   - peakvalley_price：0–10.00（元/kWh）
   - energy_cost 范围：-999999.99–999999.99（字典给了范围；一般不为负但不强行禁止）
   - data_integrity：完整/不完整
   - 外键：plant_area_id -> R1；energy_type -> R5；strategy_id -> R6
   ============================================================ */
CREATE TABLE energy_peakvalley (
    id BIGINT IDENTITY(1,1) NOT NULL,       -- 新增自增主键
    peakvalley_id    NVARCHAR(20) NOT NULL,  -- 原: NVARCHAR(30) / record_id (PVXXXXX)，统一编码长度 NVARCHAR(20)

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

    strategy_id       NVARCHAR(20) NOT NULL, -- 原: VARCHAR(20)，统一字符类型为 NVARCHAR
    -- data_integrity    NVARCHAR(10) NOT NULL, -- 用视图实现，不再存储物理字段

    CONSTRAINT PK_energy_peakvalley PRIMARY KEY (id),

    CONSTRAINT FK_peakvalley_energy
        FOREIGN KEY (energy_type) REFERENCES energy_category(energy_type),

    CONSTRAINT FK_peakvalley_area
        FOREIGN KEY (plant_area_id) REFERENCES plant_area(plant_area_id),

    CONSTRAINT FK_peakvalley_strategy
        FOREIGN KEY (strategy_id) REFERENCES pricing_strategy(strategy_id),

    -- PV + 5位数字
    CONSTRAINT CK_energy_peakvalley_id_format -- 重命名加表前缀，避免跨表约束重名
        CHECK (
            LEN(peakvalley_id) >= 7
            AND LEFT(peakvalley_id, 2) = N'PV'
            AND SUBSTRING(peakvalley_id, 3, 5) LIKE '[0-9][0-9][0-9][0-9][0-9]'
        ),

    CONSTRAINT CK_energy_peakvalley_energy_type_enum -- 重命名加表前缀，避免跨表约束重名
        CHECK (energy_type IN (N'水', N'蒸汽', N'天然气', N'电')),

    CONSTRAINT CK_energy_peakvalley_peak_energy_range    CHECK (peak_energy   BETWEEN -999999.99 AND 999999.99),   -- 重命名加表前缀，避免跨表约束重名
    CONSTRAINT CK_energy_peakvalley_high_energy_range    CHECK (high_energy   BETWEEN -999999.99 AND 999999.99),   -- 重命名加表前缀，避免跨表约束重名
    CONSTRAINT CK_energy_peakvalley_flat_energy_range    CHECK (flat_energy   BETWEEN -999999.99 AND 999999.99),   -- 重命名加表前缀，避免跨表约束重名
    CONSTRAINT CK_energy_peakvalley_valley_energy_range  CHECK (valley_energy BETWEEN -999999.99 AND 999999.99),   -- 重命名加表前缀，避免跨表约束重名
    CONSTRAINT CK_energy_peakvalley_total_energy_range   CHECK (total_energy  BETWEEN -999999.99 AND 999999.99),   -- 重命名加表前缀，避免跨表约束重名

    CONSTRAINT CK_energy_peakvalley_price_range
        CHECK (peakvalley_price BETWEEN 0.00 AND 10.00), -- 重命名加表前缀，避免跨表约束重名

    CONSTRAINT CK_energy_peakvalley_energy_cost_range
        CHECK (energy_cost BETWEEN -999999.99 AND 999999.99), -- 重命名加表前缀，避免跨表约束重名

    CONSTRAINT UQ_energy_peakvalley_peakvalley_id UNIQUE (peakvalley_id) -- 原主键改为唯一约束，保留业务编码
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'peakvalley_id',   N'记录编号';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'energy_type',     N'能源类型';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'plant_area_id',   N'厂区编号';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'statistic_date',  N'统计日期';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'peak_energy',     N'尖峰时段能耗';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'high_energy',     N'高峰时段能耗';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'flat_energy',     N'平段能耗';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'valley_energy',   N'低谷时段能耗';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'total_energy',    N'总能耗';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'peakvalley_price',N'峰谷单价';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'energy_cost',     N'能耗成本';
EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'strategy_id',     N'策略编号';
-- EXEC dbo.usp_set_msdesc N'dbo', N'energy_peakvalley', N'data_integrity',  N'数据完整性';
GO
