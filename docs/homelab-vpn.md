# Homelab VPN

The reference laptop uses NetworkManager's native WireGuard support. The
`hermes-homelab` profile automatically turns off on the saved `Hermes-Trusted`
home connection and turns on when another Wi-Fi, wired or mobile connection is
active. With no uplink it turns off. If home and another uplink are both active,
home takes precedence. Internet traffic continues through the current connection.

The home connection is matched by UUID in `hosts/nixos/default.nix`, not by the
Wi-Fi display name. Renaming that profile preserves the match; recreating it
requires updating the configured UUID. The reference host's NetworkManager
dispatcher runs `scripts/hermes-vpn-policy.py` on network changes, including
connection startup after boot. It adds no resident daemon or timer. WireGuard's
own autoconnect setting stays disabled so it cannot independently start at home.

Manual toggles still work; the next uplink event reapplies the automatic policy:

```bash
nmcli connection up hermes-homelab
nmcli connection down hermes-homelab
```

To keep it off until explicitly resumed or the next reboot:

```bash
sudo hermes-vpn-policy --pause
sudo hermes-vpn-policy --resume
```

Only `10.10.10.0/24` and `10.10.40.0/24` enter the tunnel. Internet traffic keeps
the current connection's default route. The tunnel does not carry IPv6.
When enabled on a network that also uses either subnet, the tunnel's lower route
metric takes precedence for that subnet. Turn the VPN off for direct home access.

`services.resolved` in `hosts/nixos/default.nix` starts systemd-resolved through
systemd. The NixOS module integrates it with NetworkManager and supplies the DNS
stub in `/etc/resolv.conf`. The VPN profile registers `~home.arpa` with Hermes at
`10.10.10.1`; other DNS names use the existing network's resolvers. Disabling the
VPN removes its DNS route. Resolved's public fallback servers and LLMNR/mDNS
listeners are disabled; the existing Avahi service keeps local discovery.

The host's Caddy root CA remains declared in `security.pki.certificateFiles`.
Do not disable certificate checks or add browser exceptions for homelab access.

## Import credentials

Download a fresh export from Hermes into Downloads and restrict its access.
For the reference host, the rebuild supplies the import command:

```bash
chmod 600 ~/Downloads/wireguard-peer.conf
hermes-vpn-import --check ~/Downloads/wireguard-peer.conf
sudo hermes-vpn-import ~/Downloads/wireguard-peer.conf
sudo hermes-vpn-policy
```

The importer validates a single-interface, single-peer export, replaces its
routes and DNS with the split-tunnel policy, and adds a 25-second keepalive if
missing. It rejects unsupported options, never runs WireGuard hooks and never
activates the profile. It refuses to overwrite an existing profile.

NetworkManager stores the private key and optional preshared key in
`/etc/NetworkManager/system-connections/hermes-homelab.nmconnection`, owned by
root with mode `0600`. This file is runtime state on the encrypted root filesystem,
outside Git and the Nix store. Do not copy the export or keyfile into this
repository, a Nix path literal, command arguments, shared logs or unencrypted
backups. Do not use `nmcli --show-secrets` in diagnostic output.

## Verify and recover

With the VPN enabled away from home, verify the two routes, ordinary internet
routing, DNS link selection and HTTPS without bypassing CA verification:

```bash
ip route get 10.10.10.10
ip route get 10.10.40.1
ip route get 1.1.1.1
resolvectl status wg-hermes
resolvectl query vaultwarden.home.arpa
curl --connect-timeout 5 --max-time 15 -I https://vaultwarden.home.arpa
```

The two private destinations must use `wg-hermes`; the internet destination must
use the current physical connection. Confirm a recent WireGuard handshake with
`sudo wg show wg-hermes latest-handshakes` if `wg` is available; never use
`showconf` or `dump`, which can expose secrets. A successful local home test does
not establish external reachability: repeat over a hotspot or another network.

On 2026-11-02, the NetworkManager profile installed both private routes and
registered the `home.arpa` DNS route correctly. Enabling it on the home LAN
caused ordinary DNS queries through the overlapping physical LAN to time out;
keep it off at home as intended. No firewall checks were relaxed. An isolated
temporary tunnel using the imported credentials passed a fresh handshake,
Hermes DNS resolution and HTTPS to Vaultwarden with certificate verification.
The test left the desktop's routes unchanged, and direct home and internet
access passed afterward. Actual away-network operation remains unverified.

Pause automatic activation to disable the tunnel and remove its DNS registration.
To remove the profile entirely:

```bash
sudo hermes-vpn-policy --pause
sudo nmcli connection delete hermes-homelab
```

The local VPN profile is independent of NixOS generations. System rollback does
not delete it. To revert the resolver change as well, restore the previous host
configuration and rebuild, or use `sudo nixos-rebuild switch --rollback`.
The reference host's pre-VPN generation was 117 on 2026-11-02; select that
generation from the boot menu for a complete system rollback while it is retained.
Generation rollback leaves the imported profile in place. Generation 119 predates
the automatic dispatcher policy and provides the manual-only VPN setup.

After verifying the imported profile and connectivity, delete the downloaded
export with `rm -- ~/Downloads/wireguard-peer.conf`. SSD wear leveling and Btrfs
copy-on-write mean overwriting with `shred` cannot guarantee erasure. Deletion
removes the accessible copy; the root filesystem is encrypted. If the export was
shared or otherwise exposed, revoke that peer on Hermes and generate a new key.
