return {
	{
		"yetone/avante.nvim",
		event = "VeryLazy",
		version = false,
		build = "make",
		opts = {
			provider = "claude",
			cursor_applying_provider = "groq",
			behaviour = {
				auto_suggestions = false,
				support_paste_from_clipboard = true,
				enable_cursor_planning_mode = false,
				enable_claude_text_editor_tool_mode = true,
			},
			providers = {
				groq = {
					__inherited_from = "openai",
					api_key_name = "GROQ_API_KEY",
					endpoint = "https://api.groq.com/openai/v1/",
					model = "llama-3.3-70b-versatile",
					max_tokens = 32768,
				},
			},
			mappings = {
				suggestion = {
					accept = "<C-l>",
					dismiss = "<C-o>",
					next = "<C-j>",
					prev = "<C-k>",
				},
			},
			rag_service = {
				enabled = false,
				host_mount = os.getenv("HOME") .. "/src",
				provider = "openai",
				endpoint = "https://api.openai.com/v1",
			},
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons",
			{
				"HakonHarnes/img-clip.nvim",
				event = "VeryLazy",
				opts = {
					default = {
						embed_image_as_base64 = false,
						prompt_for_file_name = false,
						drag_and_drop = {
							insert_mode = true,
						},
						use_absolute_path = false,
					},
				},
			},
		},
	},
}
