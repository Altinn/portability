import importlib.util
import io
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

spec = importlib.util.spec_from_file_location('probe', Path(__file__).with_name('app.py'))
probe = importlib.util.module_from_spec(spec)
# Unit tests cover payload cleanup/error disclosure without installing network SDKs.
with patch.dict(sys.modules, {name: MagicMock() for name in
                             ('boto3', 'psycopg', 'redis', 'botocore', 'botocore.config')}):
    spec.loader.exec_module(probe)

class ProbeTests(unittest.TestCase):
    def exercise_s3(self, payload):
        client = MagicMock()
        client.put_object.return_value = {'VersionId': 'version-created-by-test'}
        client.get_object.return_value = {'Body': MagicMock()}
        client.get_object.return_value['Body'].read.return_value = payload
        values = {'S3_ENDPOINT': 'https://example.invalid', 'S3_REGION': 'fr-par',
                  'S3_ACCESS_KEY': 'dummy', 'S3_SECRET_KEY': 'dummy', 'S3_BUCKET': 'test'}
        with patch.dict(probe.os.environ, values), patch.object(probe.boto3, 'client', return_value=client):
            if payload == b'ok':
                probe.check_s3()
            else:
                with self.assertRaises(RuntimeError): probe.check_s3()
        deleted = client.delete_object.call_args.kwargs
        self.assertEqual(deleted['VersionId'], 'version-created-by-test')
        self.assertEqual(deleted['Bucket'], 'test')
        self.assertEqual(deleted['Key'], client.put_object.call_args.kwargs['Key'])
        client.get_object.return_value['Body'].close.assert_called_once()
        client.close.assert_called_once()

    def test_s3_removes_the_exact_version(self): self.exercise_s3(b'ok')
    def test_failed_s3_content_check_still_removes_version(self): self.exercise_s3(b'wrong')

    def test_http_failure_does_not_expose_exception_message(self):
        handler = object.__new__(probe.Handler)
        handler.path = '/checks'
        handler.wfile = io.BytesIO()
        handler.send_response = MagicMock()
        handler.send_header = MagicMock()
        handler.end_headers = MagicMock()
        with patch.object(probe, 'check_postgres', side_effect=ValueError('secret-connection-string')), \
             patch.object(probe, 'check_redis'), patch.object(probe, 'check_s3'):
            handler.do_GET()
        handler.send_response.assert_called_once_with(503)
        self.assertNotIn(b'secret-connection-string', handler.wfile.getvalue())
        self.assertIn(b'ValueError', handler.wfile.getvalue())

if __name__ == '__main__': unittest.main()
