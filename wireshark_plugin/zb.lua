do

	local dprint = function(...)
		print(table.concat({"Lua:", ...}," "))
		local log = assert(io.open("lua.log", "a"))
		log:write(table.concat({"Lua:", ...}," ") .. "\n")
		log:close()
	end

	local default_settings =
	{
		comport  = '\\\\.\\pipe\\wiresharkTx',		-- This is the default for Windows
		channel  = 20
	}

	dprint("========================================")
	dprint("Started lua script on " .. os.date())
	dprint("========================================")

	local bHaveParamPort = false
	local bHaveParamChan = false

	dprint("Looking for environment variables")
	local ecom = os.getenv("ZBL_COMPORT")
	if(ecom~=nil)then
		default_settings["comport"] = ecom
		bHaveParamPort = true
		dprint("	Found environment COM port " .. ecom)
	end
	local echn = os.getenv("ZBL_CHANNEL")
	if(echn~=nil)then
		if tonumber(echn) and tonumber(echn)>=11 and tonumber(echn)<=26 then
			default_settings["channel"] = tonumber(echn)
			bHaveParamChan = true
			dprint("	Found environment Channel " .. echn)
		else
			info("	Unusable environment variable ZB_CHANNEL '"..echn.."' value must be a number between 11 and 26")
			dprint("	Unusable environment variable ZB_CHANNEL '"..echn.."' value must be a number between 11 and 26")
		end
	end
	dprint("Parsing command line parameters")
	local args={...} -- get passed-in args
	if args and #args > 0 then
		for _, arg in ipairs(args) do
		    local name, value = arg:match("(.+)=(.+)")
		    if name and value then
				dprint("	name="..name.."; value="..value)
				if name=="comport" then
					default_settings["comport"] = value
					dprint("	Found argument COM port " .. value)
					bHaveParamPort = true
				elseif name=="channel" then
					if tonumber(value) and tonumber(value)>=11 and tonumber(value)<=26 then
						default_settings["channel"] = tonumber(value)
						bHaveParamChan = true
						dprint("	Found argument Channel " .. value)
					else
						error("	commandline argument '"..name.."' value must be a number between 11 and 26")
					end
				else
					error("	unknow commandline argument '"..name.."'")
				end
		    else
		        error("	invalid commandline argument syntax")
		    end
		end
	end

--	local p_zbparams = Proto("zbparams","ZBParams");
	local p_zbparams104 = Proto("zbparams1","ZBParams1");
	local p_zbparams127 = Proto("zbparams2","ZBParams2");
	local f_channum1  = ProtoField.uint8("zbparams1.channum", "Channel", base.DEC)
	local f_chanfrq1  = ProtoField.float("zbparams1.chanfrq", "Frequency")
	local f_channum2  = ProtoField.uint8("zbparams2.channum", "Channel", base.DEC)
	local f_chanfrq2  = ProtoField.float("zbparams2.chanfrq", "Frequency")
	
	p_zbparams104.fields = { f_channum1, f_chanfrq1 }
	p_zbparams127.fields = { f_channum2, f_chanfrq2 }

	local data_dis = Dissector.get("data")

	function do_dissect(buf,pkt,subtree)
		pkt.cols.protocol = "zbparams"
		pkt.cols.src = "JN516x"
		pkt.cols.dst = "PC"

		local ftyp = buf(2,1):uint()
		if(ftyp==0)then
			local chan = buf(3,1):uint()
			local freq = buf(4,4):float()
			pkt.cols.info:append("Channel=" .. chan .. " (" .. string.format("%.3f", freq/1000000) .. " GHz)")
			subtree:add(f_channum1,buf:range(3,1))
			subtree:add(f_chanfrq1,buf:range(4,4)):set_text(string.format("Frequency: %.3f GHz", freq/1000000))
--			subtree:add(f_channum1,chan)
--			subtree:add(f_chanfrq1,freq/1000000):append_text("GHz")
		elseif(ftyp==1)then
			pkt.cols.info = "Syntax error, could not interpret command."
		end
	end

-- Dissection routine
    function p_zbparams104.dissector(buf,pkt,root)
--		dprint("[0:2]=" .. buf(0,2):uint())
		set_color_filter_slot(4, "zbee_zcl")				-- Purple 2
		set_color_filter_slot(7, "zbee_nwk.cmd.id == 0x08")		-- Green  3 - Link Status
		if (buf:len() < 2) or (buf(0,2):uint() ~= 0x0700) then
			orig104:call(buf,pkt,root)
		else
			local pktlen = buf:reported_length_remaining()
			local subtree = root:add(p_zbparams104,buf:range(0,pktlen))
			do_dissect(buf,pkt,subtree)
		end
    end

    function p_zbparams127.dissector(buf,pkt,root)

		set_color_filter_slot(4, "zbee_zcl")				-- Purple 2
		set_color_filter_slot(7, "zbee_nwk.cmd.id == 0x08")		-- Green  3 - Link Status
		if (buf:len() < 2) or (buf(0,2):uint() ~= 0x0700) then
			orig127:call(buf,pkt,root)
		else
			local pktlen = buf:reported_length_remaining()
			local subtree = root:add(p_zbparams127,buf:range(0, pktlen))
			do_dissect(buf,pkt,subtree)
		end
    end

	local channel_pref_enum = {
		{  1,  "Channel 11 (2.405GHz)", 11 },
		{  2,  "Channel 12 (2.410GHz)", 12  },
		{  3,  "Channel 13 (2.415GHz)", 13  },
		{  4,  "Channel 14 (2.420GHz)", 14  },
		{  5,  "Channel 15 (2.425GHz)", 15  },
		{  6,  "Channel 16 (2.430GHz)", 16  },
		{  7,  "Channel 17 (2.435GHz)", 17  },
		{  8,  "Channel 18 (2.440GHz)", 18  },
		{  9,  "Channel 19 (2.445GHz)", 19  },
		{ 10,  "Channel 20 (2.450GHz)", 20  },
		{ 11,  "Channel 21 (2.455GHz)", 21  },
		{ 12,  "Channel 22 (2.460GHz)", 22  },
		{ 13,  "Channel 23 (2.465GHz)", 23  },
		{ 14,  "Channel 24 (2.470GHz)", 24  },
		{ 15,  "Channel 25 (2.475GHz)", 25  },
		{ 16,  "Channel 26 (2.480GHz)", 25  },
	}
-- Parameters
	p_zbparams104.prefs.comport = Pref.string("Serial port", default_settings.comport, "Serial port used to send commands")
	p_zbparams104.prefs.channel = Pref.enum("Channel", default_settings.channel, "Zigbee channel to listen on", channel_pref_enum)
	function p_zbparams104.prefs_changed()
--		dprint("p_zbparams104 prefs_changed called: channel = " .. p_zbparams104.prefs.channel .. ", serial port = " .. p_zbparams104.prefs.comport)
		if(not bHaveParamPort)then
			default_settings.comport  = p_zbparams104.prefs.comport
			dprint("Using saved port " .. default_settings.comport)
		end
		if(not bHaveParamChan)then
			default_settings.channel  = p_zbparams104.prefs.channel
			dprint("Using saved channel " .. default_settings.channel)
			local portname = default_settings.comport
			local channel  = default_settings.channel
			local com = assert(io.open(portname, "w"))
			com:write("C:" .. channel .. "\n")
			com:close()
		end
	end

-- Initialization routine
	function p_zbparams104.init()
	end
	function p_zbparams127.init()
	end
-- Register dissector
	local wtap_encap_table = DissectorTable.get("wtap_encap")
	orig104 = wtap_encap_table:get_dissector(104)
	orig127 = wtap_encap_table:get_dissector(127)
	wtap_encap_table:add(104, p_zbparams104)
	wtap_encap_table:add(127, p_zbparams127)
--	local wpan_panid_table = DissectorTable.get("wpan.panid")
--	wpan_panid_table:add(3, p_zbparams)

	local function dialog_menu()
		local function dialog_func(portname,channel)

			if portname == "" then 
				portname = default_settings.comport
			else
				default_settings.comport = portname
			end
			if channel  == "" then
				channel = default_settings.channel
			else
				default_settings.channel = channel
			end
			dprint("About to send C:" .. channel .. " on " .. portname)
			local com = assert(io.open(portname, "w"))
			com:write("C:" .. channel .. "\n")
			com:close()
		end

		local portname = default_settings.comport
		local channel  = default_settings.channel
		new_dialog("ZB Config",dialog_func,"Serial port (blank is " .. portname .. ")","Channel (blank is " .. channel .. ")")

	end

	local function zbinit()
		local portname = default_settings.comport
		local channel  = default_settings.channel
		local com = assert(io.open(portname, "w"))
		dprint("About to send INI:" .. channel .. " on " .. portname)
		com:write("INI:" .. channel .. "\n")
--		com:write("STA\n")
--		dprint("About to send C:" .. channel .. " on " .. portname)
--		com:write("C:" .. channel .. "\n")
		com:close()
	end
	local function zbstart()
		local portname = default_settings.comport
		local channel  = default_settings.channel
		local com = assert(io.open(portname, "w"))
		dprint("About to send STA:" .. channel .. " on " .. portname)
		com:write("STA:".. channel .. "\n")
--		dprint("About to send C:" .. channel .. " on " .. portname)
--		com:write("C:" .. channel .. "\n")
		com:close()
	end
	local function zbstop()
		local portname = default_settings.comport
		local com = assert(io.open(portname, "w"))
		dprint("About to send STO on " .. portname)
		com:write("STO\n")
		com:close()
	end
	local function zbtest()
		local portname = default_settings.comport
		local com = assert(io.open(portname, "w"))
		dprint("About to send TST on " .. portname)
		com:write("TST\n")
		com:close()
	end
	local function zbbrq()
		local portname = default_settings.comport
		local com = assert(io.open(portname, "w"))
		dprint("About to send BRQ on " .. portname)
		com:write("BRQ\n")
		com:close()
	end
	local function zb1Mbps()
		local portname = default_settings.comport
		local com = assert(io.open(portname, "w"))
		dprint("About to send BRD:1000000 on " .. portname)
		com:write("BRD:1000000\n")
		com:close()
	end

--	register_menu("ZB/0. Init",zbinit,MENU_TOOLS_UNSORTED)
	register_menu("ZB/1. Start",zbstart,MENU_TOOLS_UNSORTED)
	register_menu("ZB/2. Stop",zbstop,MENU_TOOLS_UNSORTED)
	register_menu("ZB/3. Options",dialog_menu,MENU_TOOLS_UNSORTED)
	register_menu("ZB/8. Set 1Mbps",zb1Mbps,MENU_TOOLS_UNSORTED)
	register_menu("ZB/9. Test",zbtest,MENU_TOOLS_UNSORTED)
	register_menu("ZB/A. Beacon Request",zbbrq,MENU_TOOLS_UNSORTED)
end

