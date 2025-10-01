local source = {}

source.new = function()
	local self = setmetatable({}, { __index = source })
	return self
end

function source.is_available()
	return vim.bo.filetype == "jq"
end

function source.get_debug_name()
	return "jq_cmp"
end

function source.get_trigger_characters()
	return { "." }
end

---Invoke completion (required).
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source.complete(_, params, callback)
	local allTags = {"#one", "#two", "#other", "#stuff"}
  local commandBuffer = params.context.bufnr
  if not vim.b[commandBuffer] then
    vim.notify("Jq buffer isn't linked to input buffer", vim.log.levels.WARN)
	  callback({ items = {}, isIncomplete = false })
    return
  end
  local inputBuffer = vim.b[commandBuffer].jq_input_buffer
	local jqin = table.concat(vim.api.nvim_buf_get_lines(inputBuffer, 0, -1, false), "\n")
	local jqcmd = table.concat(vim.api.nvim_buf_get_lines(commandBuffer, 0, -1, false), "\n")

  jqcmd = string.gsub(jqcmd, "%.[^%.]*$", "")
  jqcmd = string.gsub(jqcmd, "|%s*$", "")
  if jqcmd == "" then
    jqcmd = "."
  end
  jqcmd = jqcmd .. " | keys"

  local syscmd = vim.system({"jq", "-cr", jqcmd}, {
    stdin = jqin,
    text = true,
  }):wait()
  if syscmd.code ~= 0 then
    vim.notify("Error running jq: ".. syscmd.stderr, vim.log.levels.WARN)
	  callback({ items = {}, isIncomplete = false })
    return
  end
  local procout = vim.split(syscmd.stdout, "\n")[1]
  local keys = vim.json.decode(procout)
	local items = {}
	for _, key in ipairs(keys) do
    if type(key) == "number" then
		  table.insert(items, { label = "["..key.."]" })
    else
		  table.insert(items, { label = key })
    end
	end
	callback({ items = items, isIncomplete = false })
end

function source.resolve(_, completion_item, callback)
	callback(completion_item)
end

function source.execute(_, completion_item, callback)
	callback(completion_item)
end

---Register your source to nvim-cmp.
require("cmp").register_source("jq_cmp", source)
