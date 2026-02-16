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
local entry_display = require("telescope.pickers.entry_display")
local gfh_actions = require("telescope._extensions.git_file_history.actions")
local gfh_config = require("telescope._extensions.git_file_history.config")

local function is_git_directory()
    local result = vim.fn.system("git rev-parse --is-inside-work-tree")
    return result:sub(1, 4) == "true"
end

local function git_log()
    local file_path = vim.fn.expand("%")
    local prefix =
        'git --no-pager log --follow --name-status --pretty=format:"hash: %H%ndate: %ad%nmessage: %s%n" --date=short '
    local cmd = prefix .. '"' .. file_path .. '"'
    local content = vim.fn.system(cmd)

    local commits = {}
    local current_commit = {}

    for line in content:gmatch("[^\n]+") do
        if line:match("^hash:") then
            if next(current_commit) then
                table.insert(commits, current_commit)
            end
            current_commit = { hash = line:match("^hash: (.+)$") }
        elseif line:match("^date:") then
            current_commit.date = line:match("^date: (.+)$")
        elseif line:match("^message:") then
            current_commit.message = line:match("^message: (.+)$")
        elseif line:match("^%S") then
            local type, remainder = line:match("^(%S+)%s+(.+)$")
            current_commit.type = type
            if remainder then
                local old_name, new_name = remainder:match("^(.-)\t(.*)$")
                if not old_name or old_name == "" then
                    old_name = remainder
                    new_name = ""
                end
                current_commit.old_name = old_name and old_name:gsub("%s+$", "") or ""
                current_commit.new_name = new_name and new_name:gsub("^%s+", "") or ""
                current_commit.path = #current_commit.new_name > 0 and current_commit.new_name
                    or current_commit.old_name
            end
        elseif line == "" and next(current_commit) then
            table.insert(commits, current_commit)
            current_commit = {}
        end
    end

    if next(current_commit) then
        table.insert(commits, current_commit)
    end

    return commits
end

local function git_show(entry)
    return vim.fn.system("git --no-pager show " .. entry.value .. ":" .. '"' .. entry.path .. '"')
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
                    local displayer = entry_display.create({
                        separator = " ",
                        items = {
                            { width = 10 },
                            { width = 7 },
                            { remaining = true },
                        },
                    })

                    return {
                        value = entry.hash,
                        display = function()
                            return displayer({
                                { entry.date, "TelescopeResultsConstant" },
                                { string.sub(entry.hash, 1, 7), "TelescopeResultsIdentifier" },
                                entry.message,
                            })
                        end,
                        ordinal = entry.hash .. entry.date .. (entry.message or ""),
                        path = entry.path,
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

                    local command = cmd
                        .. hash
                        .. ":"
                        .. (path:find(" ") and ('"' .. path .. '"') or path)
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
                    vim.api.nvim_buf_set_lines(
                        self.state.bufnr,
                        0,
                        -1,
                        false,
                        vim.split(content, "\n")
                    )

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
