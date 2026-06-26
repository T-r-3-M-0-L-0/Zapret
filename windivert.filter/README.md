# Windivert Payload Filters

These files are REQUIRED but NOT included in this repository.
They are only available in the zapret2 release zip.

## Download

1. Go to https://github.com/bol-van/zapret2/releases
2. Download `zapret2-v1.0.2.zip` (or latest version)
3. Extract `windivert.filter\` folder contents to this directory

## Required files

| File | Purpose |
|------|---------|
| `windivert_part.discord_media.txt` | Discord media UDP payload filter |
| `windivert_part.stun.txt` | STUN protocol payload filter |
| `windivert_part.quic_initial_ietf.txt` | QUIC Initial payload filter |
| `windivert_part.wireguard.txt` | WireGuard payload filter |

## How it works

These filters tell WinDivert to intercept ONLY packets with specific payloads:
- QUIC Initial packets (for YouTube/Google bypass)
- STUN packets (for Discord voice)
- Discord media packets
- WireGuard packets

**For Honor P2P traffic does NOT match any of these filters**, so it passes through untouched.
