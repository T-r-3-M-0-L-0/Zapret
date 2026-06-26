@echo off
chcp 65001 > nul
:: ALT13_01 for zapret2 (winws2)
:: Based on ESK hostfakesplit + ALT13_01 structure
:: Uses payload-based UDP filtering - NO catch-all UDP port ranges
:: For Honor P2P passes through because unknown UDP payloads are NOT intercepted

cd /d "%~dp0"
call service2.bat status_zapret 2>nul
call service2.bat load_user_lists 2>nul
echo:

set "BIN=%~dp0bin\"
set "LISTS=%~dp0lists\"
cd /d %BIN%

start "zapret2: %~n0" /min "%BIN%winws2.exe" ^
--wf-tcp-out=80,443,2053,2083,2087,2096,8443 ^
--wf-udp-out=443 ^
--lua-init=@"%~dp0lua\zapret-lib.lua" --lua-init=@"%~dp0lua\zapret-antidpi.lua" ^
--lua-init="fake_default_tls = tls_mod(fake_default_tls,'rnd,rndsni')" ^
--blob=quic_google:@"%~dp0files\fake\quic_initial_www_google_com.bin" ^
--blob=stun_bin:@"%~dp0files\fake\stun.bin" ^
--wf-raw-part=@"%~dp0windivert.filter\windivert_part.discord_media.txt" ^
--wf-raw-part=@"%~dp0windivert.filter\windivert_part.stun.txt" ^
--wf-raw-part=@"%~dp0windivert.filter\windivert_part.quic_initial_ietf.txt" ^
--filter-tcp=80 --filter-l7=http ^
  --out-range=-d10 ^
  --payload=http_req ^
   --lua-desync=fake:blob=fake_default_http:ip_autottl=-2,3-20:ip6_autottl=-2,3-20:tcp_md5 ^
   --lua-desync=fakedsplit:ip_autottl=-2,3-20:ip6_autottl=-2,3-20:tcp_md5 ^
  --new ^
--filter-tcp=443 --filter-l7=tls --hostlist="%LISTS%list-google.txt" ^
  --out-range=-d10 ^
  --payload=tls_client_hello ^
   --lua-desync=fake:blob=fake_default_tls:tcp_md5:repeats=6:tls_mod=rnd,dupsid,sni=www.google.com ^
   --lua-desync=hostfakesplit:pos=method+2 ^
  --new ^
--filter-tcp=80,443 --filter-l7=tls ^
  --out-range=-d10 ^
  --payload=tls_client_hello ^
   --lua-desync=fake:blob=fake_default_tls:tcp_md5:tcp_seq=-10000:repeats=6 ^
   --lua-desync=hostfakesplit:pos=method+2:tcp_md5:ip_autottl=-2,3-20:ip6_autottl=-2,3-20 ^
  --new ^
--filter-udp=443 --filter-l7=quic --hostlist="%LISTS%list-google.txt" ^
  --payload=quic_initial ^
   --lua-desync=fake:blob=quic_google:repeats=11 ^
  --new ^
--filter-udp=443 --filter-l7=quic ^
  --payload=quic_initial ^
   --lua-desync=fake:blob=fake_default_quic:repeats=11 ^
  --new ^
--filter-l7=wireguard,stun,discord ^
  --payload=wireguard_initiation,wireguard_cookie,stun,discord_ip_discovery ^
   --lua-desync=fake:blob=stun_bin:repeats=6
