return {
	{
		"saghen/blink.cmp",
		version = "*",
		build = function()
			require("blink.cmp").build():pwait()
		end,
		dependencies = {
			"saghen/blink.lib",
			"Kaiser-Yang/blink-cmp-avante",
		},
		event = { "InsertEnter", "CmdLineEnter" },
		---@module 'blink.cmp'
		---@type blink.cmp.Config
		opts = {
			signature = {
				enabled = true,
			},
			completion = {
				documentation = {
					auto_show = true,
				},
			},
			sources = {
				default = { "avante", "snippets", "lsp", "path", "buffer" },
				providers = {
					avante = {
						module = "blink-cmp-avante",
						name = "avante",
						opts = {},
					},
				},
			},
		},
		opts_extend = { "sources.default" },
	},
}
