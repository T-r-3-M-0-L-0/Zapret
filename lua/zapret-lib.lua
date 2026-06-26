NFQWS2_COMPAT_VER_REQUIRED=6

if NFQWS2_COMPAT_VER~=NFQWS2_COMPAT_VER_REQUIRED then
	error("Incompatible nfqws2 version. zapret-lib requires NFQWS2_COMPAT_VER="..NFQWS2_COMPAT_VER_REQUIRED.." , got NFQWS2_COMPAT_VER="..NFQWS2_COMPAT_VER)
end

print("zapret-lib: loading...")

--require "strict"

--[[
READ THIS IF YOU INTEND TO USE THIS LIBRARY IN YOUR PROJECT

All functions starting with capital letter are part of public API.
All functions starting with lower case letter are for internal use only. They may be changed in the future.

Global functions must use : separator. After : must follow function name.
  Example : send, desync, fake, ...
Global functions must NOT use . separator after first element.
  Example : send.hello, desync.test - not allowed. They are reserved for future use.

Arguments : all args are defined as table. Arg may have both positional and named forms.
Named form uses key=value. Positional form uses list of values.
If positional and named forms are mixed then named args must follow positional args.
  Example : function {arg1, arg2, key1=value1, key2=value2}

Global functions can be passed through _G using dot notation.
  Example : desync.arg.dis   - access to dissect table in desync context
            desync.arg.dis.ip - access to ip field in desync table

If function argument is passed as function it must use closure.
Direct function reference is not allowed.
  Example : --lua-desync="fake:blob=quic_google:repeats=11"
            --lua-desync="function() fake{blob='quic_google', repeats=11} end"

If function argument has . in name it must be quoted.
  Example : --lua-desync="fake:blob='quic.google':repeats=11"

In this library many functions accept desync context as first argument.
It is passed automatically by nfqws2 when calling desync function.
Do not pass it manually.

Some functions may accept table as single argument or multiple positional arguments.
  Example : send(dis, 'ip_id=0x1234', blob) or send{dis, 'ip_id=0x1234', blob}

If you want to know what arguments are accepted by function use inline help.
  Example : print(help('fake')) or print(help(fake))

--]]


local type,ipairs,tonumber=tostring,ipairs,tonumber
local print,string=print,string

local M={}
_G.zapret_lib=M

-- public API functions must start with capital letter
-- compatibility aliases can start with lower case and are NOT guaranteed to work in future


local L=M -- compatibility alias



-- **************************************************************
-- CONSTANTS AND VARIABLES
-- **************************************************************


M.A="A"
M.B="B"
M.CLIENT="client"
M.SERVER="server"
M.DIRECT="direct"
M.REVERSE="reverse"
M.OUT="out"
M.IN="in"
M.BOTH="both"
M.INITIAL="initial"
M.TRANSITIONAL="transitional"
M.ESTABLISHED="established"
M.IP_ID_FIXED=0
M.IP_ID_ZERO=1
M.IP_ID_RND=2
M.IP_ID_RND_DELTA=3
M.IP_ID_DELTA=4

M.NFQWS2_COMPAT_VER_REQUIRED=NFQWS2_COMPAT_VER_REQUIRED


local is_windows=(package.config:sub(1,1)=="\\")


local function Vprint(...)
	if verbose then print(...) end
end






-- **************************************************************
-- UTILITIES
-- **************************************************************

local function tohex(s)
	return s and s:gsub(".",function(c) return string.format("%02X",string.byte(c)) end) or nil
end
local function fromhex(s)
	return s and s:gsub("..",function(c) return string.char(tonumber(c,16)) end) or nil
end


local function hexdump(s,maxlen)
	if not s then return "" end
	local len=#s
	if maxlen and len>maxlen then len=maxlen end
	local out=""
	for i=1,len do
		out=out..string.format("%02X ",string.byte(s,i))
		if i%16==0 then out=out.."\n" end
	end
	if len%16~=0 then
		for i=len%16+1,16 do out=out.."   " end
		out=out.."\n"
	end
	return out
end


local function hexdump_dlog(s,maxlen)
	return "\n"..hexdump(s,maxlen)
end



local function is_power_of_2(n)
	return n>0 and (n & (n-1))==0
end

local function table_is_array(t)
	-- check if table has only integer keys starting from 1
	if type(t)~="table" then return false end
	local n=#t
	if n==0 then
		for _ in pairs(t) do return false end
		return true
	end
	for k in ipairs(t) do
		if not t[k] then return false end
	end
	for k in pairs(t) do
		if type(k)~="number" or k<1 or k~=math.floor(k) or k>n then return false end
	end
	return true
end


local function table_count(t)
	local n=0
	for _ in pairs(t) do n=n+1 end
	return n
end


local function str_find_last(haystack,needle)
	local idx=haystack:match(".*()"..needle)
	return idx and idx-1
end



-- **************************************************************
-- LOGGER
-- **************************************************************

local log_fd,is_pipe

local function log_open_pipe()
	local _fd
	if is_windows then
		_fd=io.open("\\\\.\\pipe\\nfqws2_log","w")
	else
		_fd=io.open("/tmp/nfqws2_log","w")
	end
	if _fd then
		log_fd=_fd
		is_pipe=true
	end
	return _fd
end


local function log_open_file(log_file)
	if log_file then
		log_fd=io.open(log_file,"a")
	end
end


local function log_init()
	local log_file
	for i=1,#arg do
		if arg[i]=="--log" then
			if i<#arg and arg[i+1]:sub(1,1)~="-" then
				log_file=arg[i+1]
				break
			end
		end
	end
	if not log_fd then log_open_pipe() end
	if not log_fd then log_open_file(log_file) end
end


local function log_write(msg)
	if log_fd then
		if is_pipe then
			log_fd:write(msg.."\n")
			log_fd:flush()
		else
			log_fd:write(os.date("%Y-%m-%d %H:%M:%S ")..msg.."\n")
			log_fd:flush()
		end
	end
end


local function log_debug(msg)
	log_write("[DEBUG] "..msg)
end






-- **************************************************************
-- nfqws2 LOGGING
-- **************************************************************

local DLOG
if b_debug then
	DLOG=function(msg)
		log_debug(msg)
		if verbose then print(msg) end
	end
else
	DLOG=function() end
end







-- **************************************************************
-- DISSECT HELPERS
-- **************************************************************

local function Bool(t,key)
	if t[key]==nil then return nil end
	return t[key] and true or false
end


local function BoolFix(t,key)
	if t[key]==nil then return nil end
	return t[key] and 1 or 0
end


local function BoolStr(t,key)
	if t[key]==nil then return nil end
	return t[key] and "true" or "false"
end






-- **************************************************************
-- HELP SYSTEM
-- **************************************************************


local help_cache={}
local function HelpClearCache()
	help_cache={}
end

local function ArgHelp(argdef)
	local t={}
	for _,v in ipairs(argdef) do
		t[#t+1]=v.name.."="..v.type
		if v.default~=nil then
			t[#t]=t[#t].." (default="..tostring(v.default)..")"
		end
		if v.optional then
			t[#t]=t[#t].." [optional]"
		end
	end
	return table.concat(t,", ")
end

local function FuncHelp(name,func,argdef)
	if not help_cache[name] then
		local def=debug.getinfo(func)
		help_cache[name]=(def and def.source and def.source:match("^@.*")) and (name.."("..ArgHelp(argdef)..")") or (name.."(???) : source unknown")
	end
	return help_cache[name]
end






-- **************************************************************
-- ARGUMENT PARSER
-- **************************************************************

local arg_types={
	string=function(v) return type(v)=="string" end,
	bool=function(v) return type(v)=="boolean" end,
	boolean=function(v) return type(v)=="boolean" end,
	int=function(v) return type(v)=="number" and math.floor(v)==v end,
	integer=function(v) return type(v)=="number" and math.floor(v)==v end,
	uint=function(v) return type(v)=="number" and math.floor(v)==v and v>=0 end,
	float=function(v) return type(v)=="number" end,
	number=function(v) return type(v)=="number" end,
	table=function(v) return type(v)=="table" end,
	func=function(v) return type(v)=="function" end,
	function=function(v) return type(v)=="function" end,
}

local function arg_check_value(val,atype)
	if not atype then return true end -- unknown type - allow anything
	if type(atype)=="function" then return atype(val) end
	if type(atype)=="string" then
		local f=arg_types[atype]
		if f then return f(val) end
		if atype:find("|",1,true) then
			-- multiple types
			for t in atype:gmatch("[^|]+") do
				local ft=arg_types[t:match("^%s*(.-)%s*$")]
				if ft and ft(val) then return true end
			end
		end
	end
	return false
end


local function arg_get_type_name(atype)
	if type(atype)=="string" then return atype end
	if type(atype)=="function" then return "custom_check" end
	return "unknown"
end


local function arg_type_error(argdef,pos,val)
	local name=argdef[pos] and argdef[pos].name or "?"
	local atype=argdef[pos] and argdef[pos].type or "?"
	local got=type(val)
	local expected=arg_get_type_name(atype)
	error(string.format("Argument %s (#%d): expected %s, got %s",name,pos,expected,got))
end


local function arg_parse_def(argdef)
	-- find first positional arg with default value
	local first_default=0
	for i=1,#argdef do
		if argdef[i].default~=nil then
			first_default=i
			break
		end
	end
	-- all args before first_default are required positional
	-- all args from first_default are optional positional or named
	return first_default
end


local function ArgsUnpack(argdef,...)
	local args={...}
	local result={}
	local named_started=false
	local pos_idx=1

	for i=1,#args do
		local v=args[i]
		if type(v)=="table" and not table_is_array(v) then
			-- named arguments
			named_started=true
			for k,val in pairs(v) do
				-- find argdef with this name
				local found=false
				for j=1,#argdef do
					if argdef[j].name==k then
						found=true
						if not arg_check_value(val,argdef[j].type) then
							arg_type_error(argdef,j,val)
						end
						result[k]=val
						break
					end
				end
				if not found then
					error("Unknown argument: "..k)
				end
			end
		else
			if named_started then
				error("Positional argument after named argument")
			end
			if pos_idx>#argdef then
				error("Too many positional arguments. Max "..#argdef)
			end
			if not arg_check_value(v,argdef[pos_idx].type) then
				arg_type_error(argdef,pos_idx,v)
			end
			result[argdef[pos_idx].name]=v
			pos_idx=pos_idx+1
		end
	end

	-- fill defaults
	for i=1,#argdef do
		if result[argdef[i].name]==nil and argdef[i].default~=nil then
			result[argdef[i].name]=argdef[i].default
		end
	end

	return result
end






-- **************************************************************
-- CONTEXT HELPERS
-- **************************************************************

local function ctx_dir(dir)
	if dir=="client" or dir=="out" or dir=="direct" then return true end
	if dir=="server" or dir=="in" or dir=="reverse" then return false end
	error("Invalid direction: "..tostring(dir))
end


local function ctx_dir_opposite(dir)
	if dir=="client" or dir=="out" or dir=="direct" then return false end
	if dir=="server" or dir=="in" or dir=="reverse" then return true end
	error("Invalid direction: "..tostring(dir))
end


local function ctx_dir_str(dis)
	return dis.out and "out" or "in"
end


local function direction_check(desync)
	if not desync.dir then return true end
	local dis=desync.dis
	if desync.dir=="out" then return dis.out end
	if desync.dir=="in" then return dis.in_ end
	if desync.dir=="direct" then return dis.direct end
	if desync.dir=="reverse" then return dis.reverse end
	if desync.dir=="client" then return dis.client end
	if desync.dir=="server" then return dis.server end
	return true
end


local function direction_cutoff_opposite(ctx,desync)
	if desync.cutoff and desync.cutoff~=0 then
		local c=desync.cutoff
		if ctx_dir_opposite(c) then return end
	end
end






-- **************************************************************
-- BLOB HELPERS
-- **************************************************************

local function blob_exist(desync,blob_name)
	local b=blob_name and desync.blob_table and desync.blob_table[blob_name]
	return b~=nil
end

local function blob(desync,blob_name)
	local b=blob_name and desync.blob_table and desync.blob_table[blob_name]
	if b==nil then
		-- try to find blob with this name in embedded blobs
		b=desync.blob_table and desync.blob_table["_embedded_"..blob_name]
	end
	if b==nil then
		error("Blob not found: "..tostring(blob_name))
	end
	return b
end






-- **************************************************************
-- IP CHECKSUM HELPERS
-- **************************************************************

local function ip_cksum_adjust(...)
	return ip_cksum_adjust(...)
end

local function ip_cksum_add(...)
	return ip_cksum_add(...)
end






-- **************************************************************
-- IP ID HELPERS
-- **************************************************************

local function ip_id(ip_id_mode,rnd_delta,delta)
	if ip_id_mode==M.IP_ID_FIXED then return rnd_delta end
	if ip_id_mode==M.IP_ID_ZERO then return 0 end
	if ip_id_mode==M.IP_ID_RND then return math.random(0,65535) end
	if ip_id_mode==M.IP_ID_RND_DELTA then return rnd_delta end
	if ip_id_mode==M.IP_ID_DELTA then return delta end
	return 0
end






-- **************************************************************
-- RAW SEND HELPERS
-- **************************************************************

local function rawsend_get_fd(dis)
	return dis.fd
end


local function rawsend_get_ifout(dis)
	return dis.ifout
end


local function rawsend_mss_get(dis)
	return dis.mss
end


local function rawsend_mss_set(dis,mss)
	if mss and mss>0 then dis.mss=mss end
end


local function rawsend_mss_clamp(dis,mss)
	rawsend_mss_set(dis,mss)
end


local function rawsend_mss_auto(dis)
	return dis.mss
end


local function rawsend_mss_apply(dis)
	return dis.mss
end


local function rawsend_closest_mss(mss_val)
	return mss_val
end


local function rawsend_payload_segmented(dis,blob)
	return rawsend_payload_segmented(dis,blob)
end


local function rawsend_ip_payload_segmented(dis,blob)
	return rawsend_ip_payload_segmented(dis,blob)
end






-- **************************************************************
-- SNI EXTRACTOR
-- **************************************************************

local function sni_get(tls_data)
	return tls_data and tls_data.sni or nil
end


local function sni_contains(tls_data,sni)
	return tls_data and tls_data.sni and tls_data.sni:find(sni,1,true)~=nil
end






-- **************************************************************
-- PAYLOAD EXTRACTOR
-- **************************************************************

local function payload_get(data)
	return data
end


local function payload_offset(dis)
	return dis.l7_offset
end


local function payload_len(dis)
	return dis.l7_len
end


local function payload_full(dis)
	return dis.l7
end


local function payload_offset_tcp(dis)
	return dis.tcp_offset
end


local function payload_len_tcp(dis)
	return dis.tcp_len
end






-- **************************************************************
-- TCP CHECKSUM HELPERS
-- **************************************************************

local function tcp_cksum_fix(dis,old,new)
	tcp_cksum_fix(dis,old,new)
end


local function tcp_cksum_fix2(dis,old1,new1,old2,new2)
	tcp_cksum_fix2(dis,old1,new1,old2,new2)
end






-- **************************************************************
-- SEQUENCE HELPERS
-- **************************************************************

local function tcp_seq_add(s,n)
	return (s+n) & 0xFFFFFFFF
end


local function tcp_seq_cmp(a,b)
	local d=(a-b) & 0xFFFFFFFF
	if d==0 then return 0 end
	if d<0x80000000 then return 1 end
	return -1
end


local function tcp_seq_diff(a,b)
	return (a-b) & 0xFFFFFFFF
end


local function tcp_seq_ge(a,b)
	return tcp_seq_cmp(a,b)>=0
end


local function tcp_seq_gt(a,b)
	return tcp_seq_cmp(a,b)>0
end


local function tcp_seq_le(a,b)
	return tcp_seq_cmp(a,b)<=0
end


local function tcp_seq_lt(a,b)
	return tcp_seq_cmp(a,b)<0
end






-- **************************************************************
-- L7 PROTOCOL HELPERS
-- **************************************************************

local function l7_proto_get(dis)
	return dis.l7proto
end






-- **************************************************************
-- IP / TCP / UDP / QUIC HEADER HELPERS
-- **************************************************************

local function ip_header_get(dis)
	return dis.ip
end


local function ip6_header_get(dis)
	return dis.ip6
end


local function tcp_header_get(dis)
	return dis.tcp
end


local function udp_header_get(dis)
	return dis.udp
end


local function quic_header_get(dis)
	return dis.quic
end


local function tcp_option_get(tcp,opt_name)
	return tcp and tcp.options and tcp.options[opt_name]
end






-- **************************************************************
-- RECONSTRUCT HELPERS
-- **************************************************************

local function tcp_reconstruct(dis)
	return tcp_reconstruct(dis)
end


local function tcp_reconstruct_segment(dis,seg)
	return tcp_reconstruct_segment(dis,seg)
end






-- **************************************************************
-- IP FRAGMENTATION HELPERS
-- **************************************************************

local function ip_frag(dis,blob,frag_size)
	return ip_frag(dis,blob,frag_size)
end


local function ip_frag_last(dis)
	return ip_frag_last(dis)
end






-- **************************************************************
-- FAKE / FAKESPLIT / MULTISPLIT / HOSTFAKESPLIT
-- **************************************************************

local function pos_normalize(pos,len)
	if type(pos)=="number" then return pos end
	if type(pos)=="string" then
		if pos=="sld+1" then
			local p=sni_find_sld(len)
			if not p then return nil end
			return p+1
		end
		if pos=="midsld+1" then
			local p=sni_find_sld(len)
			if not p then return nil end
			return p+1+math.floor((len-p)/2)
		end
		-- marker positions
		local p=pos:match("^(%d+)$")
		if p then return tonumber(p) end
		p=pos:match("^%-(%d+)$")
		if p then return len-tonumber(p)+1 end
		p=pos:match("^([^%+]+)%+(%d+)$")
		if p then
			local base=pos_normalize(p,len)
			if base then return base+tonumber(pos:match("%+(%d+)$")) end
		end
		p=pos:match("^([^%-]+)%-(%d+)$")
		if p then
			local base=pos_normalize(p,len)
			if base then return base-tonumber(pos:match("%-(%d+)$")) end
		end
	end
	return nil
end


local function pos_array_normalize(pos_array,len)
	local result={}
	for i,v in ipairs(pos_array) do
		local p=pos_normalize(v,len)
		if p then result[#result+1]=p end
	end
	return result
end



local function fake(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	-- by default process only outgoing known payloads. works only for tcp and udp
	if (desync.dis.tcp or desync.dis.udp) and direction_check(desync) and payload_check(desync) then
		if replay_first(desync) then
			if not desync.arg.blob then
				error("fake: 'blob' arg required")
			end
			if desync.arg.optional and not blob_exist(desync,desync.arg.blob) then
				DLOG("fake: blob '"..desync.arg.blob.."' not found. skipped")
				return
			end
			local fake_payload=blob(desync,desync.arg.blob)
			if desync.reasm_data and desync.arg.tls_mod then
				local pl=tls_mod_shim(desync,fake_payload,desync.arg.tls_mod,desync.reasm_data)
				if pl then fake_payload=pl end
			end
			-- check debug to save CPU
			if b_debug then DLOG("fake: "..hexdump_dlog(fake_payload)) end
			rawsend_payload_segmented(desync,fake_payload)
		else
			DLOG("fake: not acting on further replay pieces")
		end
	end
end


local function multisplit(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	local dis=desync.dis
	local arg=desync.arg
	local pos=arg.pos or error("multisplit: 'pos' arg required")
	if type(pos)=="string" then pos={pos} end
	local blob_name=arg.blob or desync.dis.l7
	local blob_data
	if blob_name then
		blob_data=blob(desync,blob_name)
	else
		blob_data=desync.dis.l7
	end
	local seqovl=arg.seqovl
	local seqovl_pattern=arg.seqovl_pattern

	if seqovl_pattern then
		seqovl_pattern=blob(desync,seqovl_pattern)
	end

	local positions=pos_array_normalize(pos,#blob_data)
	if #positions==0 then
		DLOG("multisplit: no valid positions")
		return
	end

	-- sort positions
	table.sort(positions)

	-- remove duplicates
	local j=1
	for i=2,#positions do
		if positions[i]~=positions[j] then
			j=j+1
			positions[j]=positions[i]
		end
	end
	for i=j+1,#positions do positions[i]=nil end

	-- verify positions
	if positions[1]<1 then
		error("multisplit: position <1 : "..positions[1])
	end
	if positions[#positions]>#blob_data+1 then
		error("multisplit: position >#blob+1 : "..positions[#positions])
	end

	-- process
	if replay_first(desync) then
		if b_debug then DLOG("multisplit: positions="..table.concat(positions,",")) end
		multisplit_send(desync,blob_data,positions,seqovl,seqovl_pattern)
	else
		DLOG("multisplit: not acting on further replay pieces")
	end
end


local function multidisorder(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	local dis=desync.dis
	local arg=desync.arg
	local blob_name=arg.blob or desync.dis.l7
	local blob_data
	if blob_name then
		blob_data=blob(desync,blob_name)
	else
		blob_data=desync.dis.l7
	end

	if replay_first(desync) then
		if b_debug then DLOG("multidisorder: sending "..#blob_data.." bytes") end
		multidisorder_send(desync,blob_data)
	else
		DLOG("multidisorder: not acting on further replay pieces")
	end
end


local function hostfakesplit(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	local dis=desync.dis
	local arg=desync.arg

	local blob_name=arg.blob or desync.dis.l7
	local blob_data
	if blob_name then
		blob_data=blob(desync,blob_name)
	else
		blob_data=desync.dis.l7
	end

	local host=arg.host
	if not host then
		error("hostfakesplit: 'host' arg required")
	end

	if replay_first(desync) then
		-- build fake TLS client hello with specified SNI
		local fake_payload=tls_client_hello_build(desync,host,blob_data)
		if b_debug then DLOG("hostfakesplit: host="..host..", len="..#fake_payload) end
		rawsend_payload_segmented(desync,fake_payload)
	else
		DLOG("hostfakesplit: not acting on further replay pieces")
	end
end


local function fakedsplit(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	local dis=desync.dis
	local arg=desync.arg

	local blob_name=arg.blob or desync.dis.l7
	local blob_data
	if blob_name then
		blob_data=blob(desync,blob_name)
	else
		blob_data=desync.dis.l7
	end

	local pos=arg.pos or 1
	if type(pos)=="string" then pos=pos_normalize(pos,#blob_data) end
	if not pos then
		error("fakedsplit: invalid position")
	end

	if replay_first(desync) then
		if b_debug then DLOG("fakedsplit: pos="..pos..", len="..#blob_data) end
		-- send fake + original split at pos
		fakedsplit_send(desync,blob_data,pos)
	else
		DLOG("fakedsplit: not acting on further replay pieces")
	end
end






-- **************************************************************
-- SYNACK / WSIZE / WSSIZE / RST / TCPSEG / OOB
-- **************************************************************


local function synack(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	if desync.dis.syn then
		if b_debug then DLOG("synack") end
		rawsend_ip_payload_segmented(desync,"\x00\x00\x00\x00\x00\x00")
	end
end


local function wsize(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end

	local size=desync.arg.size
	if not size then error("wsize: 'size' arg required") end

	if b_debug then DLOG("wsize: "..size) end
	rawsend_ip_payload_segmented(desync,string.pack(">I2",size))
end


local function wssize(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end

	local scale=desync.arg.scale
	if not scale then error("wssize: 'scale' arg required") end

	if b_debug then DLOG("wssize: "..scale) end
	rawsend_ip_payload_segmented(desync,"\x02\x04"..string.pack(">I2",scale))
end


local function rst(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end

	if b_debug then DLOG("rst") end
	rawsend_ip_payload_segmented(desync,"")
end


local function tcpseg(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	local size=desync.arg.size
	if not size then error("tcpseg: 'size' arg required") end

	if b_debug then DLOG("tcpseg: "..size) end
	rawsend_ip_payload_segmented(desync,string.sub(desync.dis.l7,1,size))
end


local function oob(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	local data=desync.arg.data
	if not data then error("oob: 'data' arg required") end

	if b_debug then DLOG("oob: "..#data.." bytes") end
	rawsend_ip_payload_segmented(desync,data)
end






-- **************************************************************
-- HTTP DESYNC
-- **************************************************************


local function http_hostcase(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	if replay_first(desync) then
		if b_debug then DLOG("http_hostcase") end
		-- change Host: to hOsT:
		local payload=desync.dis.l7
		local newpayload=payload:gsub("[Hh][Oo][Ss][Tt]%s*:","hOsT:",1)
		if newpayload~=payload then
			rawsend_payload_segmented(desync,newpayload)
		end
	end
end


local function http_domcase(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	if replay_first(desync) then
		if b_debug then DLOG("http_domcase") end
		-- randomize case of domain in Host header
		local payload=desync.dis.l7
		local newpayload=payload:gsub("Host%s*:%s*([^%s\r\n]+)",function(host)
			local newhost=""
			for i=1,#host do
				local c=host:sub(i,i)
				if c:match("[a-zA-Z]") then
					newhost=newhost..(math.random(2)==1 and c:upper() or c:lower())
				else
					newhost=newhost..c
				end
			end
			return "Host: "..newhost
		end,1)
		if newpayload~=payload then
			rawsend_payload_segmented(desync,newpayload)
		end
	end
end


local function http_methodeol(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	if replay_first(desync) then
		if b_debug then DLOG("http_methodeol") end
		-- add EOL after method
		local payload=desync.dis.l7
		local newpayload=payload:gsub("^(%w+ )","\r\n%1",1)
		if newpayload~=payload then
			rawsend_payload_segmented(desync,newpayload)
		end
	end
end


local function http_unixeol(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	if replay_first(desync) then
		if b_debug then DLOG("http_unixeol") end
		-- use unix EOL
		local payload=desync.dis.l7
		local newpayload=payload:gsub("\r\n","\n")
		rawsend_payload_segmented(desync,newpayload)
	end
end






-- **************************************************************
-- TLS CLIENT HELLO CLONE
-- **************************************************************


local function tls_client_hello_clone(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	local arg=desync.arg
	local dis=desync.dis

	if replay_first(desync) then
		if b_debug then DLOG("tls_client_hello_clone") end
		-- clone client hello from payload
		local payload=dis.l7
		local new_hello=tls_client_hello_clone_build(desync,payload,arg)
		rawsend_payload_segmented(desync,new_hello)
	end
end






-- **************************************************************
-- UGPLEN / DHT_DN / SYNDATA
-- **************************************************************


local function udplen(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.udp then return end
	if not direction_check(desync) then return end

	local len=desync.arg.len
	if not len then error("udplen: 'len' arg required") end

	if b_debug then DLOG("udplen: "..len) end
	rawsend_ip_payload_segmented(desync,string.pack(">I2",len))
end


local function dht_dn(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.udp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	if b_debug then DLOG("dht_dn") end
	-- send dht find node request
	rawsend_ip_payload_segmented(desync,"d1:ad2:id20:\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x006:target20:\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00e1:q9:find_node1:t2:aa1:y1:qe")
end


local function syndata(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	local data=desync.arg.data
	if not data then error("syndata: 'data' arg required") end

	if desync.dis.syn then
		if b_debug then DLOG("syndata: "..#data.." bytes") end
		rawsend_ip_payload_segmented(desync,data)
	end
end






-- **************************************************************
-- PKTMOD
-- **************************************************************


local function pktmod(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not direction_check(desync) then return end

	local dis=desync.dis
	local arg=desync.arg

	if b_debug then DLOG("pktmod") end
	-- modify packet in place
	local payload=dis.l7
	if arg.replace then
		for _,r in ipairs(arg.replace) do
			payload=payload:gsub(r[1],r[2],1)
		end
	end
	rawsend_payload_segmented(desync,payload)
end






-- **************************************************************
-- DROP
-- **************************************************************


local function drop(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not direction_check(desync) then return end

	if b_debug then DLOG("drop") end
	-- drop current packet
	rawsend_ip_payload_segmented(desync,"")
end






-- **************************************************************
-- SEND / SEND_TIMER_DELAYED
-- **************************************************************


local function send(ctx,desync,...)
	local args={...}
	if #args==0 then
		-- no args - send empty packet
		rawsend_ip_payload_segmented(desync.dis,"")
		return
	end

	local blob=args[1]
	if type(blob)=="string" then
		if b_debug then DLOG("send: "..#blob.." bytes") end
		rawsend_ip_payload_segmented(desync.dis,blob)
	elseif type(blob)=="table" then
		-- send multiple packets
		for _,v in ipairs(blob) do
			if type(v)=="string" then
				rawsend_ip_payload_segmented(desync.dis,v)
			end
		end
	end
end


local function send_timer_delayed(ctx,desync,ms,blob)
	if not ms then error("send_timer_delayed: 'ms' arg required") end
	if not blob then error("send_timer_delayed: 'blob' arg required") end

	if b_debug then DLOG("send_timer_delayed: ms="..ms..", len="..#blob) end
	local timer_id="send_delayed_"..math.random(1000000)
	timer_add(timer_id,ms*1000,function()
		rawsend_ip_payload_segmented(desync.dis,blob)
		timer_remove(timer_id)
	end)
end






-- **************************************************************
-- SYNDATA SPLIT
-- **************************************************************


local function synack_split(ctx,desync)
	direction_cutoff_opposite(ctx,desync)
	if not desync.dis.tcp then return end
	if not direction_check(desync) then return end
	if not payload_check(desync) then return end

	if desync.dis.syn then
		if b_debug then DLOG("synack_split") end
		local payload=desync.dis.l7
		local pos=desync.arg.pos or 1
		if type(pos)=="string" then pos=pos_normalize(pos,#payload) end
		-- split SYN data at pos
		if pos and pos>0 and pos<=#payload then
			rawsend_ip_payload_segmented(desync,string.sub(payload,1,pos))
			rawsend_ip_payload_segmented(desync,string.sub(payload,pos+1))
		end
	end
end






-- **************************************************************
-- PUBLIC API
-- **************************************************************

M.Help=Help
M.HelpClearCache=HelpClearCache
M.tohex=tohex
M.fromhex=fromhex
M.hexdump=hexdump
M.hexdump_dlog=hexdump_dlog
M.Bool=Bool
M.BoolFix=BoolFix
M.BoolStr=BoolStr
M.ArgsUnpack=ArgsUnpack
M.ctx_dir=ctx_dir
M.ctx_dir_opposite=ctx_dir_opposite
M.ctx_dir_str=ctx_dir_str
M.direction_check=direction_check
M.direction_cutoff_opposite=direction_cutoff_opposite
M.blob_exist=blob_exist
M.blob=blob
M.pos_normalize=pos_normalize
M.pos_array_normalize=pos_array_normalize
M.payload_check=payload_check
M.replay_first=replay_first
M.ip_id=ip_id
M.rawsend_get_fd=rawsend_get_fd
M.rawsend_get_ifout=rawsend_get_ifout
M.rawsend_mss_get=rawsend_mss_get
M.rawsend_mss_set=rawsend_mss_set
M.rawsend_mss_clamp=rawsend_mss_clamp
M.rawsend_mss_auto=rawsend_mss_auto
M.rawsend_mss_apply=rawsend_mss_apply
M.rawsend_closest_mss=rawsend_closest_mss
M.rawsend_payload_segmented=rawsend_payload_segmented
M.rawsend_ip_payload_segmented=rawsend_ip_payload_segmented
M.sni_get=sni_get
M.sni_contains=sni_contains
M.payload_get=payload_get
M.payload_offset=payload_offset
M.payload_len=payload_len
M.payload_full=payload_full
M.payload_offset_tcp=payload_offset_tcp
M.payload_len_tcp=payload_len_tcp
M.tcp_cksum_fix=tcp_cksum_fix
M.tcp_cksum_fix2=tcp_cksum_fix2
M.tcp_seq_add=tcp_seq_add
M.tcp_seq_cmp=tcp_seq_cmp
M.tcp_seq_diff=tcp_seq_diff
M.tcp_seq_ge=tcp_seq_ge
M.tcp_seq_gt=tcp_seq_gt
M.tcp_seq_le=tcp_seq_le
M.tcp_seq_lt=tcp_seq_lt
M.l7_proto_get=l7_proto_get
M.ip_header_get=ip_header_get
M.ip6_header_get=ip6_header_get
M.tcp_header_get=tcp_header_get
M.udp_header_get=udp_header_get
M.quic_header_get=quic_header_get
M.tcp_option_get=tcp_option_get
M.tcp_reconstruct=tcp_reconstruct
M.tcp_reconstruct_segment=tcp_reconstruct_segment
M.ip_frag=ip_frag
M.ip_frag_last=ip_frag_last
M.fake=fake
M.multisplit=multisplit
M.multidisorder=multidisorder
M.hostfakesplit=hostfakesplit
M.fakedsplit=fakedsplit
M.fakeddisorder=fakeddisorder
M.tcpseg=tcpseg
M.oob=oob
M.udplen=udplen
M.dht_dn=dht_dn
M.syndata=syndata
M.drop=drop
M.send=send
M.send_timer_delayed=send_timer_delayed
M.rst=rst
M.synack=synack
M.synack_split=synack_split
M.wsize=wsize
M.wssize=wssize
M.http_hostcase=http_hostcase
M.http_domcase=http_domcase
M.http_methodeol=http_methodeol
M.http_unixeol=http_unixeol
M.tls_client_hello_clone=tls_client_hello_clone
M.pktmod=pktmod


print("zapret-lib: loaded OK")
