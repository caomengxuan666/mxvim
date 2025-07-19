-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- 强制设置默认shell为cmd.exe（全局生效）
vim.o.shell = "cmd.exe"
-- 指定shell执行命令的参数（cmd需要/c参数来执行命令字符串）
vim.o.shellcmdflag = "/c"
-- 确保命令中的路径被正确用双引号包裹（解决空格/特殊字符问题）
vim.o.shellxquote = "\""
-- 处理管道命令的引用方式
vim.o.shellpipe = "| tee"
vim.o.shellredir = ">%s 2>&1"