local lenght,readable,wn
local ihkazmodule = [[
{
  "sub_name":"Find World",
  "icon":"TravelExplore",
  "menu":[
    {
      "type":"label",
      "text":"Find World iHkaz"
    },
    {
      "type":"divider"
    },          
    {
      "type": "input_int",
      "text": " Set Lenght",
      "default": "5",
      "label": "Lenght",
      "placeholder": "Number",
      "icon": "FormatListNumbered",
      "alias": "ihkaz_set_lenght"
    },
    {
    "type": "toggle",
    "text": "Readable",
    "default": false,
    "alias": "ihkaz_readable"
    },
    {
      "type":"toggle",
      "text":"With Number",
      "default":false,
      "alias":"ihkaz_withnumber"
    },
    {
    "type": "button",
    "text": "Find!",
    "alias": "ihkaz_find"
    },
    {
      "type": "divider"
    },
    {
      "type": "label",
      "text": "More Script :\nWebsite:https://ihkaz.my.id\nDiscord:Pangerans"
    }
  ]
}
]]
addIntoModule(ihkazmodule)

function getreadable(len)
    function xxx(a)
         b = "BCDFGHJKLMNPQRSTVWXYZ"
         c = "AEIOU" -- Vocal Character
         d = ""
        for e = 1, a do
            if e % 2 == 1 then
                 f = math.random(1, #b)
                d = d .. b:sub(f, f)
            else
                 f = math.random(1, #c)
                d = d .. c:sub(f, f)
            end
        end
        return d
    end
    math.randomseed(os.time())
     g = 3
     h = xxx(len)
    return h
end

function getstring(a, b)
    math.randomseed(os.time())
    local c = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local d = "0123456789"
    local e = b and c .. d or c
    local f = {}
    for g = 1, a do
        local h = math.random(1, #e)
        f[g] = e:sub(h, h)
    end
    return table.concat(f)
end

function onValue(type,name,value)
  if name == "ihkaz_set_lenght" then
    lenght = value
  end
  if name == "ihkaz_withnumber" then
    wn = getValue(0,"ihkaz_withnumber")
  end
  if name == "ihkaz_readable" then
    readable = getValue(0,"ihkaz_readable")
  end
  if name == "ihkaz_find" then
    if wn and readable then
      sendDialog({title = "Warning",message = "You can only choose one option, not both.",confirm = "Understood",alias = "CHOICE_WARNING"})
      else
        if wn then
          growtopia.warpTo(getstring(lenght,true))
        elseif readable then
          growtopia.warpTo(getreadable(lenght))
            else
              growtopia.warpTo(getstring(lenght,false))
        end
    end
  end
end
applyHook()
