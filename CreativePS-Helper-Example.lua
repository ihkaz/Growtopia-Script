local gl = getLocal
local dbuilder =
    load(
    makeRequest(
        "https://raw.githubusercontent.com/ihkaz/GT-Dialog-Builder-in-lua/refs/heads/main/DialogBuilder.lua",
        "GET"
    ).content
)()
dbuilder.importrttex(
    {
        url = "https://raw.githubusercontent.com/ihkaz/GT-Dialog-Builder-in-lua/refs/heads/main/banner.rttex",
        name = "UI/ihkazbanner.rttex"
    }
)
ihkaz = {
    logs = function(a)
        logToConsole("`0[`4ihkaz.my.id``]`` " .. a)
    end,
    bank = function(_, amount)
        sendPacket(2, string.format("action|dialog_return\ndialog_name|bank_%s\nbgl_count|%d", _, amount))
    end,
    startdialog = function()
        return dbuilder.new():setbody(
            {textcolor = "`b", quickexit = true, bg = {255, 255, 255, 200}, border = {0, 0, 0, 250}}
        ):addlabel(true, {label = "iHkaz Community Helper ", size = "big", id = 9474}):addimagebutton(
            {name = "ihkazbanner", path = "interface/large/UI/ihkazbanner.rttex"}
        ):addsmalltext("More Script : https://ihkaz.my.id"):addspacer(2):addlabel(
            true,
            {label = "Whats New? PATCH [ `430 / 07 / 2025`` ]", size = "small", id = 6124}
        ):addspacer():addsmalltext(
            {
                "[+] Cool UI",
                "[+] Command /dwl /ddl /dbgl /dblack"
            }
        ):addbutton(false, {value = "ihkaz_listcommand", label = "Show List Command"}):setDialog(
            {
                name = "ihkazstart",
                applylabel = "Thanks iHkaz!",
                closelabel = "Close"
            }
        ):showdialog()
    end,
    commandinfo = function()
        local categories, order = {}, {}
        for name, cmd in pairs(ihkaz.command) do
            if not categories[cmd.category] then
                categories[cmd.category] = {}
                table.insert(order, cmd.category)
            end
            table.insert(categories[cmd.category], {name = name, desc = cmd.desc, label = cmd.label})
        end
        table.sort(order)
        local base =
            dbuilder.new():setbody({textcolor = "`0", bg = {0, 0, 0, 200}, border = {255, 255, 255, 250}}):addlabel(
            true,
            {label = "List Command", size = "big", id = 32}
        ):addsmalltext("Total Command : "..#ihkaz.command.." Commands. More Script : https://ihkaz.my.id")
        for _, category in ipairs(order) do
            base:addspacer()
            base:addlabel(false, {label = "  " .. category .. "", size = "small"})
            base:addspacer()
            for _, cmd in ipairs(categories[category]) do
                base:addlabel(
                    true,
                    {label = string.format("/%s - %s", cmd.name, cmd.desc), size = "small", id = cmd.label}
                )
            end
            base:addspacer()
        end
        return base:setDialog({name = "ihkaz_listcommand", closelabel = "Close"}):showdialog()
    end,
    getamount = function(id)
        local a = getInventory()
        if type(a) ~= "table" then
            return 0
        end
        for _, inv in pairs(getInventory()) do
            if inv.id == id then
                return inv.amount
            end
        end
        return 0
    end,
    t10 = function(id)
        sendPacketRaw(false, {type = 10, value = id})
    end,
    path = function(z, x, y)
        sendPacketRaw(
            false,
            {
                type = 0,
                x = x,
                y = y,
                state = z
            }
        )
    end,
    balance = function()
        return (getamount(242)) + (getamount(1796) * 100) + (getamount(7188) * 10000)
    end,
    checkthread = function(label)
        for _,thread in pairs(getThreadsID) do
            if thread == label then
                return true
            end
        end
        return false
    end
    ,
    drop = function(id, amount, facing, x, y)
        ihkaz.path(facing, x, y)
        sendPacket(
            2,
            string.format("action|dialog_return\ndialog_name|drop\nitem_drop|%d|\nitem_count|%d|", id, amount)
        )
    end,
    command = {
        ["wd"] = {
            func = function(amount)
                if tonumber(amount) then
                    ihkaz.bank("withdraw", amount)
                    ihkaz.logs("Withdraw " .. amount .. " From Banks")
                    return
                end
                ihkaz.logs("Usage : /wd `9<amount>``")
            end,
            label = 7188,
            desc = "Withdraw Blue Gem Lock from the bank",
            category = "Bank Helper"
        },
        ["depo"] = {
            func = function(amount)
                if tonumber(amount) then
                    ihkaz.bank("deposit", amount)
                    ihkaz.logs("Deposit " .. amount .. " From Banks")
                    return
                end
                ihkaz.logs("Usage : /depo `9<amount>``")
            end,
            label = 7188,
            desc = "Deposit Blue Gem Lock to the bank",
            category = "Bank Helper"
        },
        ["dwl"] = {
            func = function(amount)
                if ihkaz.checkthread("DLTHREAD") then return end
                amount = tonumber(amount)
                if not amount then
                    ihkaz.logs("`0Usage : /dwl `9<amount>``")
                    return
                end

                local MAX_STACK = 250
                local TARGET = math.min(amount, MAX_STACK)
                local facing = getLocal().facing and 48 or 32
                local x, y = getLocal().pos.x, getLocal().pos.y

                if ihkaz.getamount(242) < TARGET then
                    runThread(
                        function()
                            while ihkaz.getamount(242) < TARGET do
                                local WL = ihkaz.getamount(242)

                                if ihkaz.getamount(1796) > 0 and WL + 100 <= MAX_STACK then
                                    ihkaz.t10(1796)
                                    sleep(200)
                                elseif ihkaz.getamount(7188) > 0 and WL + 100 <= MAX_STACK then
                                    ihkaz.t10(7188)
                                    sleep(200)
                                else
                                    break
                                end
                            end

                            if ihkaz.getamount(242) < TARGET then
                                ihkaz.logs("`4Cannot reach target WL due to capacity limit or not enough locks!``")
                                return
                            end

                            ihkaz.drop(242, TARGET, facing, x, y)
                        end
                    ,"WLTHREAD")
                else
                    ihkaz.drop(242, TARGET, facing, x, y)
                end
            end,
            label = 242,
            desc = "Shortcut Drop World Lock",
            category = "Dropping Command"
        },
        ["ddl"] = {
            func = function(amount)
                if ihkaz.checkthread("WLTHREAD") then return end
                amount = tonumber(amount)
                if not amount then
                    ihkaz.logs("`0Usage : /ddl `9<amount>``")
                    return
                end

                local MAX_STACK = 250
                local TARGET = math.min(amount, MAX_STACK)
                local facing = getLocal().facing and 48 or 32
                local x, y = getLocal().pos.x, getLocal().pos.y

                if ihkaz.getamount(1796) < TARGET then
                    runThread(
                        function()
                            while ihkaz.getamount(1796) < TARGET do
                                local DL = ihkaz.getamount(1796)
                                if ihkaz.getamount(7188) > 0 and DL + 100 <= MAX_STACK then
                                    ihkaz.t10(7188)
                                    sleep(200)
                                else
                                    break
                                end
                            end
                            if ihkaz.getamount(1796) < TARGET then
                                ihkaz.logs(
                                    "`4Cannot reach target Diamond Lock due to capacity limit or not enough locks!``"
                                )
                                return
                            end
                            ihkaz.drop(1796, TARGET, facing, x, y)
                        end
                    ,"DLTHREAD")
                else
                    ihkaz.drop(1796, TARGET, facing, x, y)
                end
            end,
            label = 1796,
            desc = "Shortcut Drop Diamond Lock",
            category = "Dropping Command"
        },
        ["dbgl"] = {
            func = function(amount)
                if not tonumber(amount) then
                    ihkaz.logs("`0Usage : /dbl `9<amount>``")
                    return
                end
                local facing, x, y = getLocal().facing and 48 or 32, getLocal().pos.x, getLocal().pos.y
                ihkaz.drop(7188, tonumber(amount), facing, x, y)
            end,
            label = 7188,
            desc = "Shortcut Drop Blue Gem Lock",
            category = "Dropping Command"
        },
        ["dblack"] = {
            func = function(amount)
                if not tonumber(amount) then
                    ihkaz.logs("`0Usage : /dblack `9<amount>``")
                    return
                end
                local facing, x, y = getLocal().facing and 48 or 32, getLocal().pos.x, getLocal().pos.y
                ihkaz.drop(11550, tonumber(amount), facing, x, y)
            end,
            label = 11550,
            desc = "Shortcut Drop Black Gem Lock",
            category = "Dropping Command"
        },
        ["ihkazhelp"] = {
            func = function()
                ihkaz.startdialog()
            end,
            label = 32,
            desc = "Show Patch,List Command & Anything!",
            category = "Helper"
        }
    },
    actionbutton = {
        ["listcommand"] = function()
            ihkaz.commandinfo()
        end
    }
}
function commandhandler(a, b)
    if b:match("action|input\n|text|/(.+)") then
        local command, params = (b:match("action|input\n|text|/(.+)")):match("^(%S+)%s*(.*)")
        if command and ihkaz.command[command] then
            ihkaz.command[command].func(params)
            return true
        end
    end
end

function buttonhandler(a, b)
    if b:match("buttonClicked|ihkaz_(.-)") then
        buttons = b:match("buttonClicked|ihkaz_(.-)\n")
        if ihkaz.actionbutton[buttons] then
            ihkaz.actionbutton[buttons]()
        end
    end
end
ihkaz.startdialog()
AddHook("OnTextPacket", "COMMANDHANDLER", commandhandler)
AddHook("OnTextPacket", "BUTTONHANDLER", buttonhandler)