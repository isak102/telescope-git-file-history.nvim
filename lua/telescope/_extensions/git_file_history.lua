local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
    error("This plugin requires nvim-telescope/telescope.nvim")
end

local has_plenary, pfiletype = pcall(require, "plenary.filetype")
if not has_plenary then
    error("This plugin requires nvim-lua/plenary.nvim")
end

if vim.fn.executable("git") == 0 then
    error("This plugin requires git to be installed")
end

if vim.fn.executable("awk") == 0 then
    error("This plugin requires awk to be installed")
end

local action_set = require("telescope.actions.set")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local conf = require("telescope.config").values
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local putils = require("telescope.previewers.utils")
local entry_display = require("telescope.pickers.entry_display")
local make_entry = require("telescope.make_entry")
local gfh_actions = require("telescope._extensions.git_file_history.actions")
local gfh_config = require("telescope._extensions.git_file_history.config")

-- separator between commit message and file path. (no path should ever contain this string I hope)
local SEPARATOR = "§X§Y§Z§"

local function split_string(inputString, separator)
    if separator == nil then
        separator = "%s"
    end
    local t = {}
    for str in string.gmatch(inputString, "([^" .. separator .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local function make_commit_entry(opts)
    opts = opts or {}

    local displayer = entry_display.create({
        separator = " ",
        items = {
            { width = 7 },
            { width = 10 },
            { remaining = true },
        },
    })

    local make_display = function(entry)
        return displayer({
            { string.sub(entry.value, 1, 7), "TelescopeResultsIdentifier" },
            { entry.date, "TelescopeResultsConstant" },
            entry.msg,
        })
    end

    return function(entry)
        if entry == "" then
            return nil
        end

        local parts = split_string(entry, SEPARATOR)
        local path = parts[2]

        local info = split_string(parts[1], " ")

        local hash = info[1]
        local date = info[2]
        local msg = table.concat(info, " ", 3)

        if not msg then
            msg = "<empty commit message>"
        end

        return make_entry.set_default_entry_mt({
            value = hash,
            ordinal = hash .. " " .. date .. " " .. msg,
            msg = msg,
            date = date,
            path = path,
            display = make_display,
            current_file = opts.current_file,
        }, opts)
    end
end

local function is_git_directory()
    local result = vim.fn.system("git rev-parse --is-inside-work-tree")
    return result == "true\n"
end

local function git_file_history(opts)
    opts = opts or {}
    opts.entry_maker = vim.F.if_nil(opts.entry_maker, make_commit_entry(opts))

    if not is_git_directory() then
        error(vim.fn.getcwd() .. " is not a git directory")
    end

    pickers
        .new(opts, {
            results_title = "Commits for current file",
            finder = finders.new_oneshot_job({
                "sh",
                "-c",
                "git log --follow --decorate --format='%H %ad%d %s' --date=format:'%Y-%m-%d' --name-only "
                    .. vim.fn.expand("%")
                    .. " | awk '{if (!NF) next; if (line) {print line \""
                    .. SEPARATOR
                    .. '" $0; line=""} else {line=$0}}\'',
            }, opts),
            sorter = conf.file_sorter(opts),
            attach_mappings = function(prompt_bufnr, map)
                local function open(cmd)
                    local selection = action_state.get_selected_entry()
                    local hash = selection.value

                    actions.close(prompt_bufnr)

                    local command = cmd .. hash .. ":" .. selection.path
                    vim.cmd(command)
                end

                action_set.select:replace(function()
                    open("Gedit ")
                end)
                actions.select_tab:replace(function()
                    open("Gtabedit ")
                end)
                actions.select_horizontal:replace(function()
                    open("Gsplit ")
                end)
                actions.select_vertical:replace(function()
                    open("Gvsplit ")
                end)

                for mode, tbl in pairs(gfh_config.values.mappings) do
                    for key, action in pairs(tbl) do
                        map(mode, key, action)
                    end
                end

                return true
            end,
            previewer = previewers.new_buffer_previewer({
                title = "File contents at commit",
                get_buffer_by_name = function(_, entry)
                    return entry.value .. ":" .. entry.path
                end,

                define_preview = function(self, entry, _)
                    if self.state.bufname == entry.value .. ":" .. entry.path then
                        return
                    end
                    local cmd = {
                        "sh",
                        "-c",
                        "GIT_PAGER=cat git show " .. entry.value .. ":" .. entry.path,
                    }
                    local ft = pfiletype.detect(entry.path)
                    putils.job_maker(cmd, self.state.bufnr, {
                        value = entry.value,
                        bufname = entry.value .. ":" .. entry.path,
                        cwd = opts.cwd,
                        callback = function(bufnr, content)
                            if not content then
                                return
                            end
                            require("telescope.previewers.utils").highlighter(bufnr, ft)
                        end,
                    })
                end,
            }),
        })
        :find()
end

return telescope.register_extension({
    setup = gfh_config.setup,
    exports = {
        git_file_history = git_file_history,
        actions = gfh_actions,
    },
})
