import importlib.util
import io
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


spec = importlib.util.spec_from_file_location("bootstrap", Path(__file__).with_name("app.py"))
bootstrap = importlib.util.module_from_spec(spec)
with patch.dict(sys.modules, {"psycopg": MagicMock()}):
    spec.loader.exec_module(bootstrap)


class BootstrapTests(unittest.TestCase):
    def handler(self, path, headers=None):
        handler = object.__new__(bootstrap.Handler)
        handler.path = path
        handler.headers = headers or {}
        handler.wfile = io.BytesIO()
        handler.send_response = MagicMock()
        handler.send_header = MagicMock()
        handler.end_headers = MagicMock()
        return handler

    def test_health_does_not_install_extensions(self):
        handler = self.handler("/health")
        with patch.object(bootstrap, "install_extensions") as install:
            handler.do_GET()
        install.assert_not_called()
        handler.send_response.assert_called_once_with(200)

    def test_http_body_cannot_supply_sql(self):
        handler = self.handler("/extensions", {"Content-Length": "12"})
        with patch.object(bootstrap, "install_extensions") as install:
            handler.do_POST()
        install.assert_not_called()
        handler.send_response.assert_called_once_with(400)

    def test_error_does_not_disclose_credentials(self):
        handler = self.handler("/extensions")
        with patch.object(bootstrap, "install_extensions", side_effect=ValueError("password=secret")):
            handler.do_POST()
        handler.send_response.assert_called_once_with(503)
        self.assertNotIn(b"secret", handler.wfile.getvalue())
        self.assertEqual(json.loads(handler.wfile.getvalue())["error"], "database_operation_failed")

    def test_prerequisite_failure_is_explained_without_raw_error(self):
        handler = self.handler("/extensions")
        with patch.object(bootstrap, "install_extensions", side_effect=bootstrap.PrerequisiteError("pgaudit_not_preloaded")):
            handler.do_POST()
        self.assertEqual(json.loads(handler.wfile.getvalue())["error"], "pgaudit_not_preloaded")

    def test_arbitrary_extensions_are_rejected_before_sql(self):
        connection = MagicMock()
        with self.assertRaises(bootstrap.PrerequisiteError):
            bootstrap.ensure_extensions(connection, ["unapproved_extension"])
        connection.cursor.assert_not_called()

    def test_installation_uses_idempotent_quoted_commands_and_verifies_results(self):
        connection = MagicMock()
        cursor = connection.cursor.return_value.__enter__.return_value
        cursor.fetchall.side_effect = [
            [(name,) for name in bootstrap.APPLICATION_EXTENSIONS],
            [(name, "test-version") for name in bootstrap.APPLICATION_EXTENSIONS],
        ]
        cursor.fetchone.return_value = ("pg_stat_statements,pgaudit,pg_cron",)
        result = bootstrap.ensure_extensions(connection, bootstrap.APPLICATION_EXTENSIONS)
        self.assertEqual(set(result), set(bootstrap.APPLICATION_EXTENSIONS))
        self.assertIn("SELECT extname, extversion FROM pg_extension", [c.args[0] for c in cursor.execute.call_args_list])
        templates = [c.args[0] for c in bootstrap.sql.SQL.call_args_list]
        self.assertIn("CREATE EXTENSION IF NOT EXISTS {}", templates)


if __name__ == "__main__":
    unittest.main()
