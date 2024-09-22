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

local action_set = require("telescope.actions.set")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local conf = require("telescope.config").values
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local gfh_actions = require("telescope._extensions.git_file_history.actions")
local gfh_config = require("telescope._extensions.git_file_history.config")

local function is_git_directory()
    local result = vim.fn.system("git rev-parse --is-inside-work-tree")
    return result:sub(1, 4) == "true"
end

local function git_log()
    local file_path = vim.fn.expand("%")
    local cmd = 'git --no-pager log --follow --decorate --format="%H %ad %s" --date=format:"%Y-%m-%d" --name-only "' .. file_path .. '"'
    local content = vim.fn.system(cmd)

    local commits = {}

    local pattern = "([a-f0-9]+) (%d%d%d%d%-%d%d%-%d%d) (.-)\n\n([^\r\n]+)"

    for hash, date, message, path in content:gmatch(pattern) do
        table.insert(commits, {
            hash = hash,
            date = date,
            message = message,
            path = path
        })
    end

    return commits
end

local function git_show(entry)
    return vim.fn.system("git --no-pager show " .. entry.value .. ":" .. entry.path)
end

local function git_file_history(opts)
    opts = opts or {}

    if not is_git_directory() then
        error(vim.fn.getcwd() .. " is not a git directory")
    end

    pickers
        .new(opts, {
            results_title = "Commits for current file",
            finder = finders.new_table({
                results = git_log(),
                entry_maker = function(entry)
                    return {
                        value = entry.hash,
                        display = entry.date .. " [" .. entry.hash:sub(1, 7) .. "] " .. entry.message,
                        ordinal = entry.hash .. entry.date .. entry.message,
                        path = entry.path
                    }
                end,
            }),
            sorter = conf.file_sorter(opts),
            attach_mappings = function(prompt_bufnr, map)
                local function open(cmd)
                    local selection = action_state.get_selected_entry()
                    local hash = selection.value
                    local path = selection.path

                    actions.close(prompt_bufnr)

                    local command = cmd .. hash .. ":" .. path
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

                    local content = git_show(entry)
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(content, "\n"))

                    local ft = pfiletype.detect(entry.path, {})
                    require("telescope.previewers.utils").highlighter(self.state.bufnr, ft)
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
