import unittest

import requests


class TargetOverrideTest(unittest.TestCase):
    def test_override(self):
        self.assertEqual("Hello", requests.vendored_greeting())


if __name__ == "__main__":
    unittest.main()
