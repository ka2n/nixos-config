local group = vim.api.nvim_create_augroup("ReadonlyGenerated", { clear = true })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = group,
    pattern = "*.gen.*",
    callback = function()
        vim.bo.readonly = true
    end,
})

local function checkDoNotEdit()
    local first = vim.fn.getline(1)
    if first and string.find(first, "DO NOT EDIT") then
        vim.bo.readonly = true
    end
end

vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    pattern = "*",
    callback = checkDoNotEdit,
})
