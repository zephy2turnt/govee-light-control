import json
import unittest
from unittest.mock import patch

import govee_control


class GoveeControlTests(unittest.TestCase):
    def test_study_mode_uses_warm_white_and_68_percent(self):
        with patch("govee_control.send_command") as send_command:
            govee_control.study_mode("10.0.0.86")

        self.assertEqual(send_command.call_count, 3)
        self.assertEqual(send_command.call_args_list[0].args[1:], ("turn", {"value": 1}))
        self.assertEqual(
            send_command.call_args_list[1].args[1:],
            (
                "colorwc",
                {
                    "color": {"r": 0, "g": 0, "b": 0},
                    "colorTemInKelvin": 2700,
                },
            ),
        )
        self.assertEqual(
            send_command.call_args_list[2].args[1:],
            ("brightness", {"value": 68}),
        )

    def test_sleep_mode_uses_3_percent_brightness(self):
        with patch("govee_control.send_command") as send_command:
            govee_control.sleep_mode("10.0.0.86")

        self.assertEqual(
            send_command.call_args_list[2].args[1:],
            ("brightness", {"value": 3}),
        )

    def test_packet_matches_govee_lan_shape(self):
        packet = govee_control.make_packet("brightness", {"value": 68})
        self.assertEqual(
            json.loads(packet),
            {"msg": {"cmd": "brightness", "data": {"value": 68}}},
        )


if __name__ == "__main__":
    unittest.main()
