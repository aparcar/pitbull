module("luci.controller.voucher", package.seeall)

local utils = require('voucher.utils')
local config = require('voucher.config')
local http = require('luci.http')

-- /usr/lib/lua/luci/controller/voucher.lua

function readAll(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

function print_r (t, name, indent)
    local tableList = {}
    function table_r (t, name, indent, full)
        local id = not full and name
        or type(name)~="number" and tostring(name) or '['..name..']'
        local tag = indent .. id .. ' = '
        local out = {}	-- result
        if type(t) == "table" then
            if tableList[t] ~= nil then table.insert(out, tag .. '{} -- ' .. tableList[t] .. ' (self reference)')
            else
                tableList[t]= full and (full .. '.' .. id) or id
                if next(t) then -- Table not empty
                    table.insert(out, tag .. '{')
                    for key,value in pairs(t) do 
                        table.insert(out,table_r(value,key,indent .. '|  ',tableList[t]))
                    end 
                    table.insert(out,indent .. '}')
                else table.insert(out,tag .. '{}') end
            end
        else 
            local val = type(t)~="number" and type(t)~="boolean" and '"'..tostring(t)..'"' or tostring(t)
            table.insert(out, tag .. val)
        end
        return table.concat(out, '\n')
    end
    return table_r(t,name or 'Value',indent or '')
end

function index()
    local page, root

    -- Making portal as default
    root = node()
    root.target = alias("portal")
    root.index  = true

    -- Main window with auth enabled
    status = entry({"portal"}, firstchild(), _("Captive Portal"), 9.5)
    status.dependent = false
    status.sysauth = "root"
    status.sysauth_authenticator = "htmlauth"

    -- Rest of entries
    entry({"portal","voucher"}, call("action_voucher_admin"), _("Voucher Admin"), 80).dependent=false
    entry({"portal","voucher", "auth"}, call("action_voucher_auth")).dependent=false
end

local function add_voucher(values_map)
    local key, voucher, expiretime, uploadlimit, downloadlimit, amountofmacsallowed, command

    key = values_map.key
    voucher = values_map.voucher
    expiretime = values_map.expiretime
    uploadlimit = values_map.uploadlimit
    downloadlimit = values_map.downloadlimit
    amountofmacsallowed = values_map.amountofmacsallowed


    command = '/usr/bin/voucher add_voucher '..key..' '..voucher..' '..expiretime..' '..uploadlimit..' '..downloadlimit..' '..amountofmacsallowed
    fd = io.popen(command)
    fd:close()
end

local function get_mac_from_ip(ip)
    local command = 'ping -i 0.2 -w 0.2 -c 1 '..ip..' >/dev/null; cat /proc/net/arp | grep '..ip..' | grep br-lan | awk \'{print $4}\' | head -c -1'
    fd = io.popen(command, 'r')
    local output = fd:read('*all')
    fd:close()
    return output
end

local function auth_voucher(values_map, ip)
    local voucher, mac, command

    voucher = values_map.voucher
    mac = get_mac_from_ip( ip )


    command = '/usr/bin/voucher auth_voucher '..mac..' '..voucher
    fd = io.popen(command, 'r')
    local output = fd:read('*all')
    fd:close()

    command2 = '/usr/bin/captive-portal'
    fd2 = io.popen(command2, 'r')
    local output2 = fd2:read('*all')
    fd2:close()

    return command..'\n'..output
end

local function check_voucher(ip)
    local mac, command

    mac = get_mac_from_ip( ip )

    command = '/usr/bin/voucher check_voucher '..mac
    fd = io.popen(command, 'r')
    local output = fd:read('*all')
    fd:close()

    return output
end

function action_voucher_admin()
    if (luci.http.formvalue('action') == 'add_voucher') then
        add_voucher(luci.http.formvalue())
    end
    luci.template.render("admin_portal/voucher",{
        vouchers=utils.from_csv_to_table(config.db),
        form=print_r(luci.http.formvalue())
    })
end

function action_voucher_auth()
    result = ''
    local ip = string.sub(http.getenv('REMOTE_ADDR'), 8)
    if (luci.http.formvalue('action') == 'auth_voucher') then
        result = auth_voucher(luci.http.formvalue(), ip)
    else
        result = check_voucher(ip)
    end
    luci.template.render("portal/auth_voucher",{
        result=result,
    })
end
