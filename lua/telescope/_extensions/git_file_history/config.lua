local gfh_actions = require("telescope._extensions.git_file_history.actions")

local config = {}

config.values = {
    mappings = {
        i = {
            ["<C-g>"] = gfh_actions.open_in_browser,
        },
        n = {
            ["<C-g>"] = gfh_actions.open_in_browser,
        },
    },
}

config.setup = function(opts)
    opts = opts or {}

    config.values.mappings = vim.tbl_deep_extend(
        "force",
        config.values.mappings,
        require("telescope.config").values.mappings
    )
    config.values = vim.tbl_deep_extend("force", config.values, opts)
end

return config
