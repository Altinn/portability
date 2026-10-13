import importlib.util
import unittest
from pathlib import Path
spec = importlib.util.spec_from_file_location("config", Path(__file__).with_name("write-config.py"))
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)

class ConfigTests(unittest.TestCase):
    def test_state_region_is_independent(self):
        values, backend = config.build({"SCW_DEFAULT_PROJECT_ID": "dummy", "SCW_STATE_BUCKET": "state",
            "SCW_STATE_REGION": "fr-par", "SCW_TFVARS_JSON": '{"region":"nl-ams"}'})
        self.assertEqual(values["zone"], "nl-ams-1")
        self.assertEqual(backend["endpoints"]["s3"], "https://s3.fr-par.scw.cloud")
        self.assertTrue(backend["use_lockfile"])
    def test_secret_fields_rejected(self):
        with self.assertRaises(ValueError):
            config.build({"SCW_DEFAULT_PROJECT_ID": "dummy", "SCW_STATE_BUCKET": "state",
                          "SCW_TFVARS_JSON": '{"database_password":"secret"}'})
    def test_non_object_rejected(self):
        with self.assertRaises(ValueError):
            config.build({"SCW_TFVARS_JSON": "[]"})
if __name__ == "__main__": unittest.main()
