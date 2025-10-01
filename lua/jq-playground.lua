local M = {}

---@class JqPlaygroundConfig
---@field command? string
---@field additional_args? string[]
M.default_conf = {
	command = "jq",
	additional_args = {},
}

---@param localConfig? JqPlaygroundConfig
---@return JqPlaygroundConfig
M.getFinalConfig = function(localConfig)
	return vim.tbl_deep_extend("force", M.default_conf, vim.g.jq_playground or {}, localConfig or {})
end

---Open JQ Playground
---@param conf? JqPlaygroundConfig optional config table to override global and default config
M.JQ = function(conf)
	local fullConfig = M.getFinalConfig(conf)
	-- save in buffer id
	local inputBuffer = vim.api.nvim_get_current_buf()
	-- new tab
	vim.cmd.tabnew()
	local inputWin = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(inputWin, inputBuffer)
	-- create 4 windows
	local commandBuffer = vim.api.nvim_create_buf(false, true)
	vim.bo[commandBuffer].filetype = "jq"
  vim.b[commandBuffer].jq_input_buffer = inputBuffer
	vim.api.nvim_buf_set_name(commandBuffer, "JQ Command")

	local outBuffer = vim.api.nvim_create_buf(false, true)
	vim.bo[outBuffer].filetype = vim.bo[inputBuffer].filetype
	vim.api.nvim_buf_set_name(outBuffer, "JQ Output")
	local errBuffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(errBuffer, "JQ Error")

	local outWin = vim.api.nvim_open_win(outBuffer, false, { split = "right", win = inputWin })
	local commandWin = vim.api.nvim_open_win(commandBuffer, false, { split = "below", win = inputWin, height = 10 })
	local errWin = vim.api.nvim_open_win(errBuffer, false, { split = "below", win = outWin, height = 10 })

	vim.keymap.set({ "n", "i" }, "<C-Enter>", function()
		local jqin = table.concat(vim.api.nvim_buf_get_lines(inputBuffer, 0, -1, false), "\n")
		local jqcmd = table.concat(vim.api.nvim_buf_get_lines(commandBuffer, 0, -1, false), "\n")

		local cmd = {}
		table.insert(cmd, fullConfig.command)
		for _, value in ipairs(fullConfig.additional_args) do
			table.insert(cmd, value)
		end
    table.insert(cmd, jqcmd)

		local syscmd = vim.system(cmd, {
			stdin = jqin,
			text = true,
		}):wait()
		if syscmd.code == 0 then
			vim.api.nvim_buf_set_lines(outBuffer, 0, -1, false, vim.split(syscmd.stdout, "\n"))
		end
		vim.api.nvim_buf_set_lines(errBuffer, 0, -1, false, vim.split(syscmd.stderr, "\n"))
	end, { buffer = commandBuffer })

	vim.api.nvim_create_autocmd({ "WinClosed" }, {
		pattern = { tostring(commandWin), tostring(outWin), tostring(errWin), tostring(inputWin) },
		callback = function()
			vim.api.nvim_win_close(outWin, false)
			vim.api.nvim_buf_delete(outBuffer, {})
			vim.api.nvim_win_close(commandWin, false)
			vim.api.nvim_buf_delete(commandBuffer, {})
			vim.api.nvim_win_close(errWin, false)
			vim.api.nvim_buf_delete(errBuffer, {})
			vim.api.nvim_win_close(inputWin, false)
		end,
	})
end

return M
