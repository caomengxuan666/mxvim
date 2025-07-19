return {
  -- 依赖：telescope（LazyVim 已内置）
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      -- 媒体文件预览插件
      {
        "nvim-telescope/telescope-media-files.nvim",
        config = function()
          -- 初始化插件
          require("telescope").setup({
            extensions = {
              media_files = {
                -- 支持的图片格式
                filetypes = { "png", "jpg", "jpeg", "webp", "gif" },
                -- 最大宽度/高度（根据终端调整）
                max_width = 100,
                max_height = 100,
                -- 启用预览
                find_cmd = "fd" -- 需安装 fd-find（见下方说明）
              }
            }
          })
          -- 加载扩展
          require("telescope").load_extension("media_files")
        end,
      },
    },
  },
}
