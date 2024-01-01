return {
    -- Either a module name (ex 'default') that will be fetched in the list of
    -- modules or a module definition)
    {
        -- This define the module 'default' with some kepmaps and some events handlers.
        "default",
        -- This is enabled by default but we can disable this.
        enabled = true,
        keymaps = {
            { "<leader>f", function() gaze.current_client:fullscreen() end }
        },
        events = {
            onNewClient = function(client)
                client:focus();
            end,
        },
    },

    -- This enables the 'tags' module.
    -- Modules can either be defined inline like above or be included from another file.
    -- Gaze will automatically register modules from runtimes/modules/* and from $XDG_CONFIG_ROOT/gaze/modules/*
    "tags",

    -- We can also enable modules and configure it.
    {
        "mouse",
        -- enabled can be true/false/"default".
        -- "default" means that if the module is redefined, this definition will be overidden (instead of a config error)
        enabled = "default",
        -- This set some options for the module
        options = {
            click_to_raise = false,
            cursor_wrap = true,
        },
    },

    {
        "module_with_params",
        -- Set some defaults
        options = {
            term = "ghostty",
            -- options not specified here don't have default and are required.
        },
        function(opts)
            return {
                keymaps = {
                    { opts.key,  function() print(gaze.inspect(gaze.current_client)) end },
                    { opts.term_key, function() gaze.api.exec(opts.term) end },
                },
            }
        end,
    },
}
