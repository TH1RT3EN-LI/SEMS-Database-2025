from typing import Any, Dict, List, Optional

from sqlalchemy import text
from sqlalchemy.orm import Session


class BaseDAO:
    def __init__(self, session: Session):
        self.session = session

    def fetch_all(self, sql: str, params: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        rows = (
            self.session.execute(text(sql), params or {})
            .mappings()
            .all()
        )
        return [dict(r) for r in rows]

    def fetch_one(self, sql: str, params: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, Any]]:
        row = (
            self.session.execute(text(sql), params or {})
            .mappings()
            .first()
        )
        return dict(row) if row else None

    def execute(self, sql: str, params: Optional[Dict[str, Any]] = None) -> int:
        result = self.session.execute(text(sql), params or {})
        return result.rowcount or 0


class StatObjectDAO(BaseDAO):
    """dashboard_stat_object 统计对象。"""

    def list(self, q: Optional[str]) -> List[Dict[str, Any]]:
        return self.fetch_all(
            """
            SELECT stat_object_id, stat_object_name, stat_object_type, unit, data_source
            FROM dbo.dashboard_stat_object
            WHERE (:q IS NULL OR stat_object_name LIKE '%' + :q + '%' OR stat_object_id LIKE '%' + :q + '%')
            ORDER BY stat_object_id
            """,
            {"q": q},
        )

    def get(self, stat_object_id: str) -> Optional[Dict[str, Any]]:
        return self.fetch_one(
            """
            SELECT stat_object_id, stat_object_name, stat_object_type, unit, data_source
            FROM dbo.dashboard_stat_object
            WHERE stat_object_id = :id
            """,
            {"id": stat_object_id},
        )

    def insert(self, payload: Dict[str, Any]) -> None:
        self.execute(
            """
            INSERT INTO dbo.dashboard_stat_object (stat_object_id, stat_object_name, stat_object_type, unit, data_source)
            VALUES (:stat_object_id, :stat_object_name, :stat_object_type, :unit, :data_source)
            """,
            payload,
        )

    def update(self, stat_object_id: str, fields: Dict[str, Any]) -> int:
        if not fields:
            return 0
        set_clause = ", ".join([f"{k} = :{k}" for k in fields])
        params = {"stat_object_id": stat_object_id, **fields}
        return self.execute(
            f"UPDATE dbo.dashboard_stat_object SET {set_clause} WHERE stat_object_id = :stat_object_id",
            params,
        )

    def delete(self, stat_object_id: str) -> int:
        return self.execute(
            "DELETE FROM dbo.dashboard_stat_object WHERE stat_object_id = :id",
            {"id": stat_object_id},
        )


class DisplayConfigDAO(BaseDAO):
    """dashboard_display_config 展示配置。"""

    def list(self, q: Optional[str]) -> List[Dict[str, Any]]:
        return self.fetch_all(
            """
            SELECT config_id, config_name, module_type, description
            FROM dbo.dashboard_display_config
            WHERE (:q IS NULL OR config_name LIKE '%' + :q + '%' OR config_id LIKE '%' + :q + '%')
            ORDER BY config_id
            """,
            {"q": q},
        )

    def get(self, config_id: str) -> Optional[Dict[str, Any]]:
        return self.fetch_one(
            """
            SELECT config_id, config_name, module_type, description
            FROM dbo.dashboard_display_config
            WHERE config_id = :id
            """,
            {"id": config_id},
        )

    def insert(self, payload: Dict[str, Any]) -> None:
        self.execute(
            """
            INSERT INTO dbo.dashboard_display_config (config_id, config_name, module_type, description)
            VALUES (:config_id, :config_name, :module_type, :description)
            """,
            payload,
        )

    def update(self, config_id: str, fields: Dict[str, Any]) -> int:
        if not fields:
            return 0
        set_clause = ", ".join([f"{k} = :{k}" for k in fields])
        params = {"config_id": config_id, **fields}
        return self.execute(
            f"UPDATE dbo.dashboard_display_config SET {set_clause} WHERE config_id = :config_id",
            params,
        )

    def delete(self, config_id: str) -> int:
        return self.execute(
            "DELETE FROM dbo.dashboard_display_config WHERE config_id = :id",
            {"id": config_id},
        )


class ConfigMetricDAO(BaseDAO):
    """dashboard_config_metric 配置指标关联。"""

    def list_by_config(self, config_id: str) -> List[Dict[str, Any]]:
        return self.fetch_all(
            """
            SELECT config_id, stat_object_id, position_index, display_options
            FROM dbo.dashboard_config_metric
            WHERE config_id = :cid
            ORDER BY position_index, stat_object_id
            """,
            {"cid": config_id},
        )

    def insert(self, payload: Dict[str, Any]) -> None:
        self.execute(
            """
            INSERT INTO dbo.dashboard_config_metric (config_id, stat_object_id, position_index, display_options)
            VALUES (:config_id, :stat_object_id, :position_index, :display_options)
            """,
            payload,
        )

    def update(self, config_id: str, stat_object_id: str, fields: Dict[str, Any]) -> int:
        if not fields:
            return 0
        set_clause = ", ".join([f"{k} = :{k}" for k in fields])
        params = {"config_id": config_id, "stat_object_id": stat_object_id, **fields}
        return self.execute(
            f"""
            UPDATE dbo.dashboard_config_metric
            SET {set_clause}
            WHERE config_id = :config_id AND stat_object_id = :stat_object_id
            """,
            params,
        )

    def delete(self, config_id: str, stat_object_id: str) -> int:
        return self.execute(
            """
            DELETE FROM dbo.dashboard_config_metric
            WHERE config_id = :cid AND stat_object_id = :sid
            """,
            {"cid": config_id, "sid": stat_object_id},
        )


class ScreenDAO(BaseDAO):
    """大屏数据接口：dashboard_screen 视图/表。"""
    def fetch_screen(self, include_modules: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        where = ""
        params: Dict[str, Any] = {}
        if include_modules:
            placeholders = ", ".join([f":m{i}" for i in range(len(include_modules))])
            where = f"WHERE module_type IN ({placeholders})"
            params.update({f"m{i}": v for i, v in enumerate(include_modules)})
        return self.fetch_all(
            f"""
            SELECT
                module_type,
                module_title,
                payload_json,
                updated_at
            FROM dbo.dashboard_screen
            {where}
            ORDER BY module_type
            """,
            params,
        )
