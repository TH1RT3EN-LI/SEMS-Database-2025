/* ============================================================
   SQL Server DDL - 告警运维管理业务线（按数据字典字段命名）
   ============================================================ */
IF OBJECT_ID(N'dbo.device_calibration_record', N'U') IS NOT NULL DROP TABLE dbo.device_calibration_record;
IF OBJECT_ID(N'dbo.device_maintenance_assignment', N'U') IS NOT NULL DROP TABLE dbo.device_maintenance_assignment;
IF OBJECT_ID(N'dbo.order_participant', N'U') IS NOT NULL DROP TABLE dbo.order_participant;
IF OBJECT_ID(N'dbo.maintenance_order', N'U') IS NOT NULL DROP TABLE dbo.maintenance_order;
IF OBJECT_ID(N'dbo.alarm_audit_record', N'U') IS NOT NULL DROP TABLE dbo.alarm_audit_record;
IF OBJECT_ID(N'dbo.alarm_record', N'U') IS NOT NULL DROP TABLE dbo.alarm_record;
IF OBJECT_ID(N'dbo.alarm_rule', N'U') IS NOT NULL DROP TABLE dbo.alarm_rule;
IF OBJECT_ID(N'dbo.device_ledger', N'U') IS NOT NULL DROP TABLE dbo.device_ledger;
IF OBJECT_ID(N'dbo.sys_user', N'U') IS NOT NULL DROP TABLE dbo.sys_user;
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
   1) 用户表（最小实现，用于承接外键）
   ============================================================ */
IF OBJECT_ID(N'dbo.sys_user', N'U') IS NOT NULL DROP TABLE dbo.sys_user;
GO
CREATE TABLE dbo.sys_user (
    user_id NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_sys_user PRIMARY KEY (user_id)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'sys_user', N'user_id', N'用户编号（字典未给出通用字段名，此处用 user_id 补齐；供 auditor_user_id / participant_user_id / calibrator_id 外键引用）';
GO

/* ============================================================
   2) 设备台账表（R2）
   device_id, device_type, device_name, model_spec, install_time,
   warranty_years, scrap_status
   ============================================================ */
IF OBJECT_ID(N'dbo.device_ledger', N'U') IS NOT NULL DROP TABLE dbo.device_ledger;
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
    CONSTRAINT CK_device_ledger_warranty_years CHECK (warranty_years >= 0), -- 保持表前缀，避免跨表约束重名
    CONSTRAINT CK_device_ledger_scrap_status CHECK (scrap_status IN (N'正常使用', N'已报废')) -- 保持表前缀，避免跨表约束重名
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'device_ledger', N'device_id',      N'设备编号（device_id，格式示例 IN1234567890）';
EXEC dbo.usp_set_msdesc N'dbo', N'device_ledger', N'device_type',    N'设备类型（如 变压器/回路/逆变器/汇流箱 等）';
EXEC dbo.usp_set_msdesc N'dbo', N'device_ledger', N'device_name',    N'设备名称';
EXEC dbo.usp_set_msdesc N'dbo', N'device_ledger', N'model_spec',     N'型号规格';
EXEC dbo.usp_set_msdesc N'dbo', N'device_ledger', N'install_time',   N'安装时间';
EXEC dbo.usp_set_msdesc N'dbo', N'device_ledger', N'warranty_years', N'质保期（年，>=0）';
EXEC dbo.usp_set_msdesc N'dbo', N'device_ledger', N'scrap_status',   N'报废状态（正常使用/已报废）';
GO

/* ============================================================
   3) 告警规则表（R3）
   rule_id, metric_field, compare_operator, threshold_value, unit,
   alarm_type, alarm_level, description, enable_flag
   ============================================================ */
IF OBJECT_ID(N'dbo.alarm_rule', N'U') IS NOT NULL DROP TABLE dbo.alarm_rule;
GO
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
    CONSTRAINT CK_alarm_rule_compare_operator CHECK (compare_operator IN (N'>', N'>=', N'<', N'<=', N'=')), -- 保持表前缀，避免跨表约束重名
    CONSTRAINT CK_alarm_rule_alarm_level CHECK (alarm_level IN (N'高', N'中', N'低')), -- 保持表前缀，避免跨表约束重名
    CONSTRAINT CK_alarm_rule_alarm_type  CHECK (alarm_type IN (N'越限告警', N'通讯故障', N'设备故障')), -- 保持表前缀，避免跨表约束重名
    CONSTRAINT CK_alarm_rule_threshold_range CHECK (threshold_value BETWEEN -99999999.99 AND 99999999.99) -- 保持表前缀，避免跨表约束重名
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_rule', N'rule_id',          N'规则编号';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_rule', N'metric_field',     N'监测字段（如 voltage/current 等，需为监测业务表真实字段名）';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_rule', N'compare_operator', N'比较符号（>, >=, <, <=, =）';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_rule', N'threshold_value',  N'阈值（DECIMAL(10,2)）';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_rule', N'unit',             N'单位（可空，如 ℃/kW/A/V/%/m³ 等）';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_rule', N'alarm_type',       N'告警类型（越限告警/通讯故障/设备故障）';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_rule', N'alarm_level',      N'告警等级（高/中/低）';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_rule', N'description',      N'告警内容/规则说明（可空）';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_rule', N'enable_flag',      N'启用状态（0禁用/1启用，默认1）';
GO

/* ============================================================
   4) 告警记录表（R4）
   alarm_id, occurred_at, rule_id, device_id
   （可选：process_status 若你后续要做“未处理/处理中/已结案”流转）
   ============================================================ */
IF OBJECT_ID(N'dbo.alarm_record', N'U') IS NOT NULL DROP TABLE dbo.alarm_record;
GO
CREATE TABLE dbo.alarm_record (
    id BIGINT IDENTITY(1,1) NOT NULL,      -- 新增自增主键
    alarm_id      NVARCHAR(20) NOT NULL,
    occurred_at   datetime2(0)  NOT NULL, -- 原: DATETIME
    rule_id       NVARCHAR(20) NOT NULL,
    device_id     NVARCHAR(20) NOT NULL

    CONSTRAINT PK_alarm_record PRIMARY KEY (id),
    CONSTRAINT UQ_alarm_record_alarm_id UNIQUE (alarm_id), -- 原主键改为唯一约束，保留业务编码
    CONSTRAINT FK_alarm_record_rule  FOREIGN KEY (rule_id)  REFERENCES dbo.alarm_rule(rule_id), -- 保持表前缀，避免跨表约束重名
    CONSTRAINT FK_alarm_record_device FOREIGN KEY (device_id) REFERENCES dbo.device_ledger(device_id) -- 保持表前缀，避免跨表约束重名
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_record', N'alarm_id',    N'告警编号';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_record', N'occurred_at', N'发生时间';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_record', N'rule_id',     N'规则编号（外键 -> alarm_rule.rule_id）';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_record', N'device_id',   N'设备编号（外键 -> device_ledger.device_id）';
GO

/* ============================================================
   5) 告警审核记录表（R5）
   audit_record_id, alarm_id, auditor_user_id, audit_time, audit_result
   ============================================================ */
IF OBJECT_ID(N'dbo.alarm_audit_record', N'U') IS NOT NULL DROP TABLE dbo.alarm_audit_record;
GO
CREATE TABLE dbo.alarm_audit_record (
    id BIGINT IDENTITY(1,1) NOT NULL, -- 新增自增主键
    audit_record_id   NVARCHAR(20) NOT NULL,
    alarm_id          NVARCHAR(20) NOT NULL,
    auditor_user_id   NVARCHAR(20) NOT NULL,
    audit_time        datetime2(0) NOT NULL, -- 原: DATETIME
    audit_result      NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_alarm_audit_record PRIMARY KEY (id),
    CONSTRAINT UQ_alarm_audit_record_audit_record_id UNIQUE (audit_record_id), -- 原主键改为唯一约束，保留业务编码
    CONSTRAINT FK_alarm_audit_record_alarm   FOREIGN KEY (alarm_id)        REFERENCES dbo.alarm_record(alarm_id), -- 保持表前缀，避免跨表约束重名
    CONSTRAINT FK_alarm_audit_record_auditor FOREIGN KEY (auditor_user_id) REFERENCES dbo.sys_user(user_id) -- 保持表前缀，避免跨表约束重名
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_audit_record', N'audit_record_id', N'审核记录编号';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_audit_record', N'alarm_id',        N'告警编号（外键 -> alarm_record.alarm_id）';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_audit_record', N'auditor_user_id', N'审核人编号（外键 -> 用户表.用户编号）';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_audit_record', N'audit_time',      N'审核时间';
EXEC dbo.usp_set_msdesc N'dbo', N'alarm_audit_record', N'audit_result',    N'审核结果（说明是否生成工单等）';
GO

/* ============================================================
   6) 运维工单表（R6）
   order_id, alarm_id, dispatch_time, response_time, finish_time,
   process_result, review_status, attachment_path
   ============================================================ */
IF OBJECT_ID(N'dbo.maintenance_order', N'U') IS NOT NULL DROP TABLE dbo.maintenance_order;
GO
CREATE TABLE dbo.maintenance_order (
    id BIGINT IDENTITY(1,1) NOT NULL, -- 新增自增主键
    order_id         NVARCHAR(20)  NOT NULL,
    alarm_id         NVARCHAR(20)  NOT NULL,
    dispatch_time    datetime2(0)  NOT NULL, -- 原: DATETIME
    response_time    datetime2(0)  NULL,     -- 原: DATETIME
    finish_time      datetime2(0)  NULL,     -- 原: DATETIME
    process_result   NVARCHAR(255) NULL,
    review_status    NVARCHAR(20)  NULL,
    attachment_path  NVARCHAR(255) NULL,
    CONSTRAINT PK_maintenance_order PRIMARY KEY (id),
    CONSTRAINT UQ_maintenance_order_order_id UNIQUE (order_id), -- 原主键改为唯一约束，保留业务编码
    CONSTRAINT FK_maintenance_order_alarm FOREIGN KEY (alarm_id) REFERENCES dbo.alarm_record(alarm_id), -- 保持表前缀，避免跨表约束重名
    CONSTRAINT CK_maintenance_order_review_status CHECK (review_status IS NULL OR review_status IN (N'通过', N'退回', N'待复查')) -- 保持表前缀，避免跨表约束重名
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'maintenance_order', N'order_id',        N'工单编号';
EXEC dbo.usp_set_msdesc N'dbo', N'maintenance_order', N'alarm_id',        N'告警编号（外键 -> alarm_record.alarm_id）';
EXEC dbo.usp_set_msdesc N'dbo', N'maintenance_order', N'dispatch_time',   N'派单时间';
EXEC dbo.usp_set_msdesc N'dbo', N'maintenance_order', N'response_time',   N'响应时间（可空：未响应）';
EXEC dbo.usp_set_msdesc N'dbo', N'maintenance_order', N'finish_time',     N'处理完成时间（可空：未完成）';
EXEC dbo.usp_set_msdesc N'dbo', N'maintenance_order', N'process_result',  N'处理结果（可空）';
EXEC dbo.usp_set_msdesc N'dbo', N'maintenance_order', N'review_status',   N'复查状态（通过/退回/待复查，可空）';
EXEC dbo.usp_set_msdesc N'dbo', N'maintenance_order', N'attachment_path', N'附件路径（文件路径或URL，可空）';
GO

/* ============================================================
   7) 工单参与表（R7）
   order_id, participant_user_id
   ============================================================ */
IF OBJECT_ID(N'dbo.order_participant', N'U') IS NOT NULL DROP TABLE dbo.order_participant;
GO
CREATE TABLE dbo.order_participant (
    order_id             NVARCHAR(20) NOT NULL,
    participant_user_id  NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_order_participant PRIMARY KEY (order_id, participant_user_id),
    CONSTRAINT FK_order_participant_order FOREIGN KEY (order_id)            REFERENCES dbo.maintenance_order(order_id),
    CONSTRAINT FK_order_participant_user  FOREIGN KEY (participant_user_id) REFERENCES dbo.sys_user(user_id)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'order_participant', N'order_id',            N'工单编号（外键 -> maintenance_order.order_id）';
EXEC dbo.usp_set_msdesc N'dbo', N'order_participant', N'participant_user_id', N'参与用户编号（外键 -> 用户表.用户编号；运维人员/复查管理员）';
GO

/* ============================================================
   8) 设备维护分配表（R8）
   device_id, participant_user_id
   ============================================================ */
IF OBJECT_ID(N'dbo.device_maintenance_assignment', N'U') IS NOT NULL DROP TABLE dbo.device_maintenance_assignment;
GO
CREATE TABLE dbo.device_maintenance_assignment (
    device_id            NVARCHAR(20) NOT NULL,
    participant_user_id  NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_device_maintenance_assignment PRIMARY KEY (device_id, participant_user_id),
    CONSTRAINT FK_device_maintenance_assignment_device FOREIGN KEY (device_id)           REFERENCES dbo.device_ledger(device_id),
    CONSTRAINT FK_device_maintenance_assignment_user   FOREIGN KEY (participant_user_id) REFERENCES dbo.sys_user(user_id)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'device_maintenance_assignment', N'device_id',           N'设备编号（外键 -> device_ledger.device_id）';
EXEC dbo.usp_set_msdesc N'dbo', N'device_maintenance_assignment', N'participant_user_id', N'维护人员用户编号（外键 -> 用户表.用户编号）';
GO

/* ============================================================
   9) 设备校准记录表（R9）
   calibration_id, device_id, calibrator_id, calibration_time,
   calibration_result, calibration_note
   ============================================================ */
IF OBJECT_ID(N'dbo.device_calibration_record', N'U') IS NOT NULL DROP TABLE dbo.device_calibration_record;
GO
CREATE TABLE dbo.device_calibration_record (
    id BIGINT IDENTITY(1,1) NOT NULL, -- 新增自增主键
    calibration_id     NVARCHAR(20)  NOT NULL,
    device_id          NVARCHAR(20)  NOT NULL,
    calibrator_id      NVARCHAR(20)  NOT NULL,
    calibration_time   datetime2(0)  NOT NULL, -- 原: DATETIME
    calibration_result NVARCHAR(20)  NOT NULL,
    calibration_note   NVARCHAR(255) NULL,
    CONSTRAINT PK_device_calibration_record PRIMARY KEY (id),
    CONSTRAINT UQ_device_calibration_record_calibration_id UNIQUE (calibration_id), -- 原主键改为唯一约束，保留业务编码
    CONSTRAINT FK_device_calibration_record_device FOREIGN KEY (device_id)     REFERENCES dbo.device_ledger(device_id),
    CONSTRAINT FK_device_calibration_record_user   FOREIGN KEY (calibrator_id) REFERENCES dbo.sys_user(user_id)
);
GO
EXEC dbo.usp_set_msdesc N'dbo', N'device_calibration_record', N'calibration_id',     N'校准记录编号';
EXEC dbo.usp_set_msdesc N'dbo', N'device_calibration_record', N'device_id',          N'设备编号（外键 -> device_ledger.device_id）';
EXEC dbo.usp_set_msdesc N'dbo', N'device_calibration_record', N'calibrator_id',      N'校准人员编号（外键 -> 用户表.用户编号）';
EXEC dbo.usp_set_msdesc N'dbo', N'device_calibration_record', N'calibration_time',   N'校准时间';
EXEC dbo.usp_set_msdesc N'dbo', N'device_calibration_record', N'calibration_result', N'校准结果（如 合格/不合格/需复检 等）';
EXEC dbo.usp_set_msdesc N'dbo', N'device_calibration_record', N'calibration_note',   N'校准备注（可空）';
GO

/* ============================================================
   10) 推荐索引（按常用查询路径）
   ============================================================ */
CREATE INDEX IX_alarm_record_rule_id   ON dbo.alarm_record(rule_id);
CREATE INDEX IX_alarm_record_device_id ON dbo.alarm_record(device_id);
CREATE INDEX IX_order_alarm_id         ON dbo.maintenance_order(alarm_id);
CREATE INDEX IX_audit_alarm_id         ON dbo.alarm_audit_record(alarm_id);
CREATE INDEX IX_calib_device_id        ON dbo.device_calibration_record(device_id);
GO
