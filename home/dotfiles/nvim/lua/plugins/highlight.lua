return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter").install({
				"bash", "c", "css", "diff", "dockerfile", "git_config", "git_rebase", "gitcommit", "gitignore",
				"go", "gomod", "gosum", "hcl", "html", "javascript", "jsdoc", "json", "just", "lua", "luadoc",
				"markdown", "markdown_inline", "nix", "php", "php_only", "query", "regex", "scss", "sql", "terraform",
				"toml", "tsx", "typescript", "vim", "vimdoc", "yaml", "blade",
			})

			vim.treesitter.language.register("markdown", { "mdx" })

			local group = vim.api.nvim_create_augroup("TreesitterStart", { clear = true })
			vim.api.nvim_create_autocmd("FileType", {
				group = group,
				callback = function(ev)
					if vim.b[ev.buf].ts_highlight then
						return
					end
					local lang = vim.treesitter.language.get_lang(ev.match)
					if lang and vim.treesitter.language.add(lang) then
						vim.treesitter.start(ev.buf, lang)
					end
				end,
			})
		end,
	},
	{ "GR3YH4TT3R93/nvim-highlight-colors", event = "VeryLazy", config = true },
}
