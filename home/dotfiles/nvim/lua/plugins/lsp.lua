return {
	{
		"neovim/nvim-lspconfig",
		version = "^2",
		event = "VeryLazy",
		dependencies = {
			{ "mason-org/mason.nvim", version = "^2" },
			{ "mason-org/mason-lspconfig.nvim", version = "^2" },
			{ "j-hui/fidget.nvim", opts = {} },
			"saghen/blink.cmp",
		},
		config = function()
			require("mason").setup()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"ts_ls",
					"lua_ls",
				},
			})

			local group = vim.api.nvim_create_augroup("LSP", { clear = true })
			vim.api.nvim_create_autocmd("LspAttach", {
				group = group,
				callback = function(ev)
					local client = vim.lsp.get_client_by_id(ev.data.client_id)
					if client == nil then
						return
					end

					if client:supports_method("textDocument/documentHighlight", ev.buf) then
						vim.api.nvim_clear_autocmds({ group = group, buffer = ev.buf })
						vim.api.nvim_create_autocmd("CursorHold", {
							callback = function()
								vim.lsp.buf.document_highlight()
							end,
							group = group,
							buffer = ev.buf,
						})
						vim.api.nvim_create_autocmd("CursorMoved", {
							callback = function()
								vim.lsp.buf.clear_references()
							end,
							group = group,
							buffer = ev.buf,
						})
					end
				end,
			})

			vim.api.nvim_create_user_command("Format", function(args)
				local range = nil
				if args.count ~= -1 then
					local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
					range = {
						start = { args.line1, 0 },
						["end"] = { args.line2, end_line:len() },
					}
				end
				require("conform").format({ async = true, lsp_format = "fallback", range = range })
			end, { range = true })

			vim.api.nvim_create_user_command("OR", function()
				vim.lsp.buf.code_action({
					context = { only = { "source.removeUnusedImports" }, diagnostics = {} },
					apply = true,
				})

				vim.lsp.buf.code_action({
					context = { only = { "source.organizeImports" }, diagnostics = {} },
					apply = true,
				})
			end, { nargs = 0 })

			vim.keymap.set({ "n" }, "[g", function()
				vim.diagnostic.jump({ count = -1, float = true })
			end, { desc = "Go to previous diagnostic" })
			vim.keymap.set({ "n" }, "]g", function()
				vim.diagnostic.jump({ count = 1, float = true })
			end, { desc = "Go to next diagnostic" })

			vim.keymap.set({ "n" }, "gd", function()
				vim.lsp.buf.definition()
			end, { desc = "Go to definition" })
			vim.keymap.set({ "n" }, "gy", function()
				vim.lsp.buf.type_definition()
			end, { desc = "Go to type definition" })
			vim.keymap.set({ "n" }, "gi", function()
				vim.lsp.buf.implementation()
			end, { desc = "Go to implementation" })
			vim.keymap.set({ "n" }, "gr", function()
				require("telescope.builtin").lsp_references()
			end, { desc = "Go to references" })

			vim.keymap.set({ "n" }, "gh", function()
				local clients = vim.lsp.get_clients({ bufnr = 0 })
				if #clients > 0 then
					vim.lsp.buf.hover()
				else
					vim.notify("No LSP clients attached to this buffer", vim.log.levels.WARN)
				end
			end, { desc = "LSP: show documentation" })

			vim.keymap.set({ "n" }, "<Leader>rn", function()
				vim.lsp.buf.rename()
			end, { desc = "Rename symbol" })

			vim.keymap.set({ "n", "x" }, "<Leader>a", function()
				vim.lsp.buf.code_action()
			end, { desc = "Code action" })
			vim.keymap.set({ "n" }, "<Leader>ac", function()
				vim.lsp.buf.code_action()
			end, { desc = "Code action for buffer" })
			vim.keymap.set({ "n" }, "<Leader>qf", function()
				vim.lsp.buf.code_action({ context = { only = { "quickfix" } } })
			end, { desc = "Quick fix" })

			vim.keymap.set({ "n" }, "<Leader>cl", function()
				vim.lsp.codelens.run()
			end, { desc = "Run code lens" })

			vim.keymap.set({ "n" }, "<M-O>", "<cmd>OR<cr>", { desc = "Organize imports" })
		end,
	},
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		---@module 'conform'
		---@type conform.setupOpts
		opts = {
			format_on_save = {
				timeout_ms = 500,
				lsp_format = "fallback",
			},
			default_format_opts = {
				lsp_format = "fallback",
			},
			formatters_by_ft = {
				lua = { "stylua" },
				typescript = { "biome", "prettier", stop_after_first = true },
				typescriptreact = { "biome", "prettier", stop_after_first = true },
				go = { "goimports", "gofmt" },
			},
		},
	},
}
