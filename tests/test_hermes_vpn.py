import base64
import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest import mock


spec = importlib.util.spec_from_file_location(
    "hermes_vpn", Path(__file__).resolve().parents[1] / "scripts/import-hermes-vpn.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

policy_spec = importlib.util.spec_from_file_location(
    "hermes_vpn_policy", Path(__file__).resolve().parents[1] / "scripts/hermes-vpn-policy.py"
)
policy = importlib.util.module_from_spec(policy_spec)
policy_spec.loader.exec_module(policy)

# Synthetic, non-operational test data only.
PRIVATE = base64.b64encode(bytes(range(32))).decode()
PUBLIC = base64.b64encode(bytes(reversed(range(32)))).decode()
EXPORT = f"""[Interface]
PrivateKey = {PRIVATE}
Address = 10.10.40.3/32
DNS = 10.10.10.1
[Peer]
PublicKey = {PUBLIC}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = vpn.example.com:51820
"""


class HermesVPNTests(unittest.TestCase):
    def test_full_tunnel_export_becomes_manual_split_tunnel(self):
        result = module.profile(EXPORT)
        self.assertEqual(result["connection"]["autoconnect"], "false")
        self.assertEqual(result["ipv4"]["never-default"], "true")
        self.assertEqual(result["ipv6"]["method"], "disabled")
        self.assertEqual(result["ipv6"]["never-default"], "true")
        self.assertEqual(result["ipv4"]["dns-search"], "~home.arpa;")
        self.assertEqual(result["ipv4"]["dns"], "10.10.10.1;")
        peer = result["wireguard-peer." + PUBLIC]
        self.assertEqual(peer["allowed-ips"], "10.10.10.0/24;10.10.40.0/24;")
        self.assertEqual(peer["persistent-keepalive"], "25")

    def test_existing_keepalive_and_preshared_key_survive(self):
        result = module.profile(EXPORT + f"PersistentKeepalive = 45\nPresharedKey = {PRIVATE}\n")
        peer = result["wireguard-peer." + PUBLIC]
        self.assertEqual(peer["persistent-keepalive"], "45")
        self.assertEqual(peer["preshared-key"], PRIVATE)
        self.assertEqual(peer["preshared-key-flags"], "0")

    def test_hooks_extra_peers_and_keyfile_injection_are_rejected(self):
        for source in (
            EXPORT.replace("Address =", "PostUp = touch /tmp/unwanted\nAddress ="),
            EXPORT + "[Peer]\nPublicKey = bad\n",
            EXPORT.replace("vpn.example.com:51820", "vpn.example.com:51820;injected"),
            EXPORT.replace(PRIVATE, "invalid"),
        ):
            with self.subTest(), self.assertRaises((ValueError, module.configparser.Error)):
                module.profile(source)

    def test_parser_failure_never_echoes_sensitive_input(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.conf"
            path.write_text(EXPORT + "\n" + PRIVATE)
            output, errors = io.StringIO(), io.StringIO()
            with mock.patch("sys.argv", ["hermes-vpn-import", "--check", str(path)]), contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                self.assertEqual(module.main(), 1)
            self.assertNotIn(PRIVATE, output.getvalue() + errors.getvalue())


class HermesVPNPolicyTests(unittest.TestCase):
    def test_home_wins_even_with_another_uplink(self):
        active = [("home", "802-11-wireless"), ("away", "802-3-ethernet")]
        self.assertFalse(policy.desired_state(active, "home"))

    def test_away_uplinks_enable_without_counting_overlays(self):
        for kind in policy.UPLINK_TYPES:
            self.assertTrue(policy.desired_state([("away", kind)], "home"))
        self.assertFalse(policy.desired_state([], "home"))
        self.assertFalse(policy.desired_state([("tail", "tun"), ("android", "bridge"), ("vpn", "wireguard")], "home"))

    def apply(self, active, paused=False, missing=False):
        def response(*arguments):
            if arguments[:2] == ("-g", "connection.uuid"):
                return mock.Mock(returncode=int(missing), stdout="vpn\n")
            if "--active" in arguments:
                return mock.Mock(returncode=0, stdout=active)
            return mock.Mock(returncode=0, stdout="")
        with mock.patch.object(policy, "nmcli", side_effect=response) as calls:
            self.assertEqual(policy.reconcile("home", paused=paused), 0)
        return calls.call_args_list

    def test_network_transitions_change_only_the_vpn_asynchronously(self):
        calls = self.apply("away:802-11-wireless\ntail:tun\n")
        self.assertEqual(calls[-1], mock.call("--wait", "0", "connection", "up", "uuid", "vpn"))
        calls = self.apply("home:802-11-wireless\nvpn:wireguard\n")
        self.assertEqual(calls[-1], mock.call("--wait", "0", "connection", "down", "uuid", "vpn"))
        calls = self.apply("vpn:wireguard\n")
        self.assertEqual(calls[-1], mock.call("--wait", "0", "connection", "down", "uuid", "vpn"))

    def test_stable_states_pause_and_missing_credentials(self):
        self.assertEqual(len(self.apply("home:802-11-wireless\n")), 2)
        self.assertEqual(len(self.apply("away:802-11-wireless\nvpn:wireguard\n")), 2)
        self.assertEqual(len(self.apply("away:802-11-wireless\n", paused=True)), 2)
        self.assertEqual(len(self.apply("away:802-11-wireless\n", missing=True)), 1)

    def test_own_tunnel_events_do_not_undo_manual_toggles(self):
        with mock.patch("sys.argv", ["policy", "--home-uuid", "home", "wg-hermes", "down"]), mock.patch.object(policy, "reconcile") as reconcile:
            self.assertEqual(policy.main(), 0)
        reconcile.assert_not_called()


if __name__ == "__main__":
    unittest.main()
