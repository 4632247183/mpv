local msg = require 'mp.msg'

local function val2str(val)
    if type(val) == "boolean" then
        if val then val = "yes" else val = "no" end
    end
    return val
end

-- converts val to type of desttypeval
local function typeconv(desttypeval, val)
    if type(desttypeval) == "boolean" then
        if val == "yes" then
            val = true
        elseif val == "no" then
            val = false
        else
            msg.error("Error: Can't convert " .. val .. " to boolean!")
            val = nil
        end
    elseif type(desttypeval) == "number" then
        if not (tonumber(val) == nil) then
            val = tonumber(val)
        else
            msg.error("Error: Can't convert " .. val .. " to number!")
            val = nil
        end
    end
    return val
end

-- performs a deep-copy of the given option value
local function opt_copy(val)
    return val -- no tables currently
end

-- compares the given option values for equality
local function opt_equal(val1, val2)
    return val1 == val2
end

local function read_options(options, identifier, on_update)
    if identifier == nil then
        identifier = mp.get_script_name()
    end
    msg.debug("reading options for " .. identifier)

    -- read config file
    local conffilename = "script-opts/" .. identifier .. ".conf"
    local conffile = mp.find_config_file(conffilename)
    if conffile == nil then
        msg.debug(conffilename .. " not found.")
        conffilename = "lua-settings/" .. identifier .. ".conf"
        conffile = mp.find_config_file(conffilename)
        if conffile then
            msg.warn("lua-settings/ is deprecated, use directory script-opts/")
        end
    end
    local f = conffile and io.open(conffile,"r")
    if f == nil then
        -- config not found
        msg.debug(conffilename .. " not found.")
    else
        -- config exists, read values
        msg.verbose("Opened config file " .. conffilename .. ".")
        local linecounter = 1
        for line in f:lines() do
            if string.find(line, "#") == 1 then

            else
                local eqpos = string.find(line, "=")
                if eqpos == nil then

                else
                    local key = string.sub(line, 1, eqpos-1)
                    local val = string.sub(line, eqpos+1)

                    -- match found values with defaults
                    if options[key] == nil then
                        msg.warn(conffilename..":"..linecounter..
                            " unknown key " .. key .. ", ignoring")
                    else
                        local convval = typeconv(options[key], val)
                        if convval == nil then
                            msg.error(conffilename..":"..linecounter..
                                " error converting value '" .. val ..
                                "' for key '" .. key .. "'")
                        else
                            options[key] = convval
                        end
                    end
                end
            end
            linecounter = linecounter + 1
        end
        io.close(f)
    end

    --parse command-line options
    local prefix = identifier.."-"

    local option_types = {}
    for key, value in pairs(options) do
        option_types[key] = opt_copy(value)
    end

    local function parse_opts(full, options)
        local changelist = {}
        for key, val in pairs(full) do
            if not (string.find(key, prefix, 1, true) == nil) then
                key = string.sub(key, string.len(prefix)+1)

                -- match found values with defaults
                if option_types[key] == nil then
                    msg.warn("script-opts: unknown key " .. key .. ", ignoring")
                else
                    local convval = typeconv(option_types[key], val)
                    if convval == nil then
                        msg.error("script-opts: error converting value '" .. val ..
                            "' for key '" .. key .. "'")
                    else
                        if not opt_equal(options[key], convval) then
                            changelist[key] = true
                            options[key] = convval
                        end
                    end
                end
            end
        end
        return changelist
    end

    --initial
    parse_opts(mp.get_property_native("options/script-opts"), options)

    --runtime updates
    if on_update then
        -- Current option state, so that we can detect changes, even if the
        -- caller messes with the options table.
        local cur_opts = {}

        for key, value in pairs(options) do
            cur_opts[key] = opt_copy(value)
        end

        mp.observe_property("options/script-opts", "native", function(name, val)
            local changelist = parse_opts(val, cur_opts)
            for key, _ in pairs(changelist) do
                -- copy to user
                options[key] = opt_copy(cur_opts[key])
            end
            if #changelist then
                on_update(changelist)
            end
        end)
    end

end

-- backwards compatibility with broken read_options export
_G.read_options = read_options

return {
    read_options = read_options,
}
