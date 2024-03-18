local action_state = require("telescope.actions.state")

local gfh_actions = {}

local function is_https_url(url)
    return url:match("^https://")
end

local function get_repo_url()
    local repo_url = vim.fn.system("git remote get-url $(git remote)")

    if not is_https_url(repo_url) then
        repo_url = repo_url:gsub(":", "/")
        repo_url = repo_url:gsub("git@", "https://")
    end
    repo_url = repo_url:gsub("%.git", "")
    repo_url = repo_url:gsub("[^/]+@dev", "dev")
    repo_url = repo_url:gsub("\n", "")

    return repo_url
end

local function url_encode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %.])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

local function get_file_at_commit_url(repo_url, hash, path)
    if repo_url:match("dev.azure.com") then
        return repo_url .. "?path=" .. url_encode(path) .. "&version=GC" .. hash .. "&_a=contents"
    else
        return repo_url .. "/blob/" .. hash .. "/" .. path
    end
end

gfh_actions.open_in_browser = function()
    local config = require("telescope._extensions.git_file_history.config").values
    local current_entry = action_state.get_selected_entry()
    local repo_url = get_repo_url()
    local full_url = get_file_at_commit_url(repo_url, current_entry.value, current_entry.path)

    local open_cmd = config.browser_command
    if not open_cmd then
        if vim.fn.executable("xdg-open") == 1 then
            open_cmd = "xdg-open"
        elseif vim.fn.executable("open") == 1 then
            open_cmd = "open"
        elseif vim.fn.executable("start") == 1 then
            open_cmd = "start"
        elseif vim.fn.executable("wslview") == 1 then
            open_cmd = "wslview"
        else
            error("No command available to open URL [xdg-open, open, start or wslview]")
            return
        end
    end

    local output = vim.fn.jobstart({ open_cmd, full_url }, { detach = true })
    if output <= 0 then
        error(string.format("Failed to open URL: %s with command: %s", full_url, open_cmd))
    end
end

return gfh_actions
