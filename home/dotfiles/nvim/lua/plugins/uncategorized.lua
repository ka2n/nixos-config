return {
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
	},
	{
		"obsidian-nvim/obsidian.nvim",
		version = "*",
		ft = "markdown",
		cmd = "Obsidian",
		opts = {
			legacy_commands = false,
			workspaces = {
				{
					name = "notes",
					path = "~/Documents/Vaults/Notes",
					overrides = {
						daily_notes = {},
					},
				},
			},
			daily_notes = {
				folder = "dailynotes",
				date_format = "%Y-%m-%d",
			},
			completion = {
				min_chars = 2,
			},
		},
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown", "Avante" },
		opts = {
			file_types = { "markdown", "Avante" },
		},
	},
	{
		"nvim-neo-tree/neo-tree.nvim",
		cmd = "Neotree",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
		},
		opts = {
			filesystem = {
				filtered_items = {
					always_show = {
						".github",
						".storybook",
					},
				},
			},
		},
	},
	{ "thinca/vim-quickrun", cmd = "QuickRun" },
	{ "tpope/vim-repeat", event = "VeryLazy" },
	{ "kylechui/nvim-surround", event = "VeryLazy", config = true },
	{
		"easymotion/vim-easymotion",
		init = function()
			vim.g.EasyMotion_do_mapping = 0
			vim.g.EasyMotion_smartcase = 1
			vim.g.EasyMotion_startofline = 0
			vim.g.EasyMotion_keys = ";hklyuiopnm,qwertasdgzxcvbjf"
			vim.g.EasyMotion_enter_jump_first = 1
			vim.g.EasyMotion_space_jump_first = 1
			vim.g.EasyMotion_use_migemo = 0
		end,
		event = "VeryLazy",
	},
}
