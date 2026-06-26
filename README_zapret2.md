# Zapret2 Migration Branch

This branch contains an experimental migration to **zapret2** (nfqws2/winws2) from the original author (bol-van).

## Why zapret2?

- **Lua-based strategies** - fully programmable, not fixed parameters
- **Payload-based UDP filtering** - catches only QUIC/STUN/Discord payloads, NOT random UDP ports
- **No more `--filter-udp=1024-65535`** - For Honor P2P and other games pass through cleanly
- **Flexible ranges** - replace `cutoff=n2` with proper packet/data byte ranges
- **Automatic TCP segmentation** - no more MSS worries

## Files you need to download manually

The following files are **NOT in this repo** - download them from the [zapret2 releases](https://github.com/bol-van/zapret2/releases):

### Required binaries (Windows)
1. `winws2.exe` - the new engine (replaces `winws.exe`)
2. `WinDivert.dll` / `WinDivert64.sys` - may be included in release or use existing

### Windivert payload filters (from release zip: `zapret2-vX.Y.Z.zip`)
Extract these to `windivert.filter\` folder:
- `windivert_part.discord_media.txt`
- `windivert_part.stun.txt`
- `windivert_part.quic_initial_ietf.txt`
- `windivert_part.wireguard.txt`

## Structure

```
Zapret/
  bin/
    winws2.exe          <-- download from zapret2 releases
    WinDivert.dll       <-- existing or from release
    WinDivert64.sys     <-- existing or from release
  lua/
    zapret-lib.lua      <-- included
    zapret-antidpi.lua  <-- included
  windivert.filter/     <-- download from zapret2 releases
    windivert_part.discord_media.txt
    windivert_part.stun.txt
    windivert_part.quic_initial_ietf.txt
  files/
    fake/
      quic_initial_www_google_com.bin
      stun.bin
      tls_clienthello_www_google_com.bin
  lists/                <-- your existing lists
  service2.bat          <-- service manager for zapret2
  ALT13_01_z2.bat       <-- example strategy
```

## Strategy format changes

### Old (zapret1):
```bat
--wf-tcp=80,443 --wf-udp=443,50000-50100
--filter-udp=443 --hostlist=list.txt --dpi-desync=fake --dpi-desync-repeats=6
--dpi-desync-fake-quic="bin\quic.bin" --dpi-desync-autottl=1 --dpi-desync-cutoff=n2
```

### New (zapret2):
```bat
--wf-tcp-out=80,443
--wf-raw-part=@"windivert.filter\windivert_part.quic_initial_ietf.txt"
--lua-init=@"lua\zapret-lib.lua" --lua-init=@"lua\zapret-antidpi.lua"
--filter-tcp=80 --filter-l7=http --out-range=-d10 --payload=http_req
  --lua-desync=fake:blob=fake_default_http:tcp_md5:ip_autottl=-2,3-20
  --new
--filter-udp=443 --filter-l7=quic --payload=quic_initial
  --lua-desync=fake:blob=quic_google:repeats=11
```

## Key differences

| Feature | zapret1 | zapret2 |
|---------|---------|---------|
| Engine | `winws.exe` | `winws2.exe` |
| Strategies | Fixed params | Lua functions |
| UDP filter | By port ranges | By payload type |
| Cutoff | `--dpi-desync-cutoff=n2` | `--out-range=-d10` |
| Fooling | `--dpi-desync-fooling=md5sig` | `:tcp_md5` inline |
| Auto TTL | `--dpi-desync-autottl=1` | `:ip_autottl=-2,3-20` |
| Fake files | `--dpi-desync-fake-tls=file.bin` | `--blob=name:@file.bin` then `:blob=name` |

## How to test

1. Download `winws2.exe` and windivert filters from zapret2 releases
2. Place them in correct folders
3. Run `ALT13_01_z2.bat` as administrator
4. Check if Discord, YouTube, For Honor work

## Service installation

Use `service2.bat` (WIP) - or run strategy .bat files directly as admin.

For service mode with winws2, the command is:
```bat
sc create zapret binPath= "\"C:\path\to\bin\winws2.exe\" --wf-tcp-out=80,443 ..." start= auto
```
