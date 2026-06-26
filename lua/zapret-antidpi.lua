--[[

NFQWS2 ANTIDPI LIBRARY

--lua-init=@zapret-lib.lua --lua-init=@zapret-antidpi.lua
--lua-desync="fake:blob=quic_google:repeats=11:ip_id=zero"
--lua-desync="multisplit:pos=1,host:tcp_md5:ip_autottl=-2,3-20"
--lua-desync="hostfakesplit:host=www.google.com:tcp_md5:ip_autottl=-2,3-20"
--lua-desync="fakedsplit:pos=1:tcp_md5:ip_autottl=-2,3-20"

This library provides standard anti-DPI desync strategies.
It depends on zapret-lib.lua loaded first.

USAGE:
  --lua-init=@zapret-lib.lua
  --lua-init=@zapret-antidpi.lua
  --filter-tcp=80 --filter-l7=http
    --out-range=-d10
    --payload=http_req
     --lua-desync=fake:blob=fake_default_http:ip_autottl=-2,3-20:tcp_md5
     --lua-desync=fakedsplit:ip_autottl=-2,3-20:tcp_md5
    --new
  --filter-tcp=443 --filter-l7=tls
    --out-range=-d10
    --payload=tls_client_hello
     --lua-desync=fake:blob=fake_default_tls:tcp_md5:repeats=6:tls_mod=rnd,dupsid
     --lua-desync=hostfakesplit:pos=method+2
    --new

QUIC:
  --filter-udp=443 --filter-l7=quic
    --payload=quic_initial
     --lua-desync=fake:blob=quic_google:repeats=11

DISCORD/STUN:
  --filter-l7=wireguard,stun,discord
    --payload=wireguard_initiation,wireguard_cookie,stun,discord_ip_discovery
     --lua-desync=fake:blob=stun_bin:repeats=6

BLOBS:
  --blob=quic_google:@"files\fake\quic_initial_www_google_com.bin"
  --blob=stun_bin:@"files\fake\stun.bin"

--]]

print("zapret-antidpi: loading...")

-- load parent lib
local Z = _G.zapret_lib or error("zapret-lib not loaded. Load zapret-lib.lua first with --lua-init")

local NFQWS2_COMPAT_VER_REQUIRED=6
if NFQWS2_COMPAT_VER~=NFQWS2_COMPAT_VER_REQUIRED then
	error("Incompatible nfqws2 version. zapret-antidpi requires NFQWS2_COMPAT_VER="..NFQWS2_COMPAT_VER_REQUIRED.." , got NFQWS2_COMPAT_VER="..NFQWS2_COMPAT_VER)
end


-- **************************************************************
-- DEFAULT FAKE BLOBS
-- **************************************************************

-- These are embedded automatically by winws2 if not overridden
-- fake_default_http  - simple HTTP GET request
-- fake_default_https - simple HTTPS (TLS 1.2) ClientHello
-- fake_default_tls   - TLS ClientHello (Google-like)
-- fake_default_quic  - QUIC Initial packet

-- To override with custom blob:
--   --blob=fake_default_tls:@"path\to\tls.bin"


-- **************************************************************
-- HTTP STRATEGIES
-- **************************************************************


-- http_fake: send fake HTTP request
-- args: blob=<blob_name>, ip_autottl, ip6_autottl, tcp_md5, ip_id, ip6_id, ip4frag, ip6frag
function http_fake(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="fake_default_http"},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
		{name="tcp_md5",type="boolean",default=false},
		{name="ip_id",type="string",optional=true},
		{name="ip6_id",type="string",optional=true},
		{name="ip4frag",type="int",optional=true},
		{name="ip6frag",type="int",optional=true},
	},desync.arg)

	desync.arg=arg
	Z.fake(ctx,desync)
end


-- http_fakedsplit: fake + split HTTP request
function http_fakedsplit(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="fake_default_http"},
		{name="pos",type="string|int",default="method+2"},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
		{name="tcp_md5",type="boolean",default=false},
	},desync.arg)

	desync.arg=arg
	Z.fakedsplit(ctx,desync)
end


-- http_multisplit: split HTTP request at multiple positions
function http_multisplit(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="fake_default_http"},
		{name="pos",type="table",default={"1","host","midsld+1","-10"}},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
		{name="tcp_md5",type="boolean",default=false},
	},desync.arg)

	desync.arg=arg
	Z.multisplit(ctx,desync)
end



-- **************************************************************
-- TLS STRATEGIES
-- **************************************************************


-- tls_fake: send fake TLS ClientHello
-- args: blob=<blob_name>, tls_mod, repeats, ip_autottl, tcp_md5, ip_id
function tls_fake(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="fake_default_tls"},
		{name="tls_mod",type="string",optional=true},
		{name="repeats",type="int",default=6},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
		{name="tcp_md5",type="boolean",default=false},
	},desync.arg)

	desync.arg=arg
	for i=1,arg.repeats do
		Z.fake(ctx,desync)
	end
end


-- tls_hostfakesplit: hostfakesplit with SNI modification
function tls_hostfakesplit(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="host",type="string",default="www.google.com"},
		{name="pos",type="string|int",default="method+2"},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
		{name="tcp_md5",type="boolean",default=false},
		{name="repeats",type="int",default=1},
	},desync.arg)

	desync.arg=arg
	for i=1,arg.repeats do
		Z.hostfakesplit(ctx,desync)
	end
end


-- tls_fakedsplit: fake + split TLS
function tls_fakedsplit(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="fake_default_tls"},
		{name="pos",type="string|int",default=1},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
		{name="tcp_md5",type="boolean",default=false},
	},desync.arg)

	desync.arg=arg
	Z.fakedsplit(ctx,desync)
end


-- tls_multisplit: split TLS at multiple positions
function tls_multisplit(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="fake_default_tls"},
		{name="pos",type="table",default={"1","host","midsld+1","-10"}},
		{name="seqovl",type="int",optional=true},
		{name="seqovl_pattern",type="string",optional=true},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
		{name="tcp_md5",type="boolean",default=false},
	},desync.arg)

	desync.arg=arg
	Z.multisplit(ctx,desync)
end


-- tls_multidisorder: send TLS with multidisorder
function tls_multidisorder(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="fake_default_tls"},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
		{name="tcp_md5",type="boolean",default=false},
	},desync.arg)

	desync.arg=arg
	Z.multidisorder(ctx,desync)
end



-- **************************************************************
-- QUIC STRATEGIES
-- **************************************************************


-- quic_fake: send fake QUIC Initial packet
-- args: blob=<blob_name>, repeats
function quic_fake(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="fake_default_quic"},
		{name="repeats",type="int",default=11},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
	},desync.arg)

	desync.arg=arg
	for i=1,arg.repeats do
		Z.fake(ctx,desync)
	end
end



-- **************************************************************
-- UDP / STUN / DISCORD STRATEGIES
-- **************************************************************


-- udp_fake: send fake UDP packet
function udp_fake(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="fake_default_quic"},
		{name="repeats",type="int",default=6},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
	},desync.arg)

	desync.arg=arg
	for i=1,arg.repeats do
		Z.fake(ctx,desync)
	end
end


-- stun_fake: send fake STUN packet
function stun_fake(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="stun_bin"},
		{name="repeats",type="int",default=6},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
	},desync.arg)

	desync.arg=arg
	for i=1,arg.repeats do
		Z.fake(ctx,desync)
	end
end


-- discord_fake: send fake Discord media packet
function discord_fake(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="fake_default_quic"},
		{name="repeats",type="int",default=6},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
	},desync.arg)

	desync.arg=arg
	for i=1,arg.repeats do
		Z.fake(ctx,desync)
	end
end


-- wireguard_fake: send fake WireGuard initiation
function wireguard_fake(ctx,desync)
	local arg=Z.ArgsUnpack({
		{name="blob",type="string",default="fake_default_quic"},
		{name="repeats",type="int",default=6},
		{name="ip_autottl",type="string",optional=true},
		{name="ip6_autottl",type="string",optional=true},
	},desync.arg)

	desync.arg=arg
	for i=1,arg.repeats do
		Z.fake(ctx,desync)
	end
end



-- **************************************************************
-- CONVENIENCE FUNCTIONS
-- **************************************************************


-- auto: automatically select strategy based on L7 protocol
function auto(ctx,desync)
	local l7=desync.dis.l7proto
	if l7=="http" then
		http_fake(ctx,desync)
	elseif l7=="tls" then
		tls_hostfakesplit(ctx,desync)
	elseif l7=="quic" then
		quic_fake(ctx,desync)
	elseif l7=="stun" or l7=="discord" then
		stun_fake(ctx,desync)
	end
end



print("zapret-antidpi: loaded OK")
