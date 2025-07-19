return {
  -- 1. Python LSP 配置（含错误显示与快捷键）
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "nvim-telescope/telescope.nvim", -- 用于错误列表搜索
    },
    ft = "python",
    config = function()
      -- 全局诊断配置（右侧显示错误符号 + 行尾提示）
      vim.diagnostic.config({
        signs = true, -- 右侧显示错误/警告符号
        sign_text = {
          [vim.diagnostic.severity.ERROR] = "E",
          [vim.diagnostic.severity.WARN] = "W",
          [vim.diagnostic.severity.INFO] = "I",
          [vim.diagnostic.severity.HINT] = "H",
        },
        virtual_text = true, -- 行尾显示简短错误信息
        float = {
          source = "always", -- 悬浮窗口显示完整错误来源
          border = "rounded", -- 圆角边框更美观
        },
        update_in_insert = false, -- 插入模式不更新诊断（提升性能）
      })

      -- 初始化 mason-lspconfig
      require("mason-lspconfig").setup()

      -- LSP 启动处理器
      require("mason-lspconfig").setup_handlers({
        -- 所有 LSP 通用配置
        function(server_name)
          require("lspconfig")[server_name].setup({
            on_attach = function(client, bufnr)
              local opts = { buffer = bufnr, silent = true }
              -- 基础 LSP 快捷键
              vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
              vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
              vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
              vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
              vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
            end,
          })
        end,

        -- Pyright 单独配置（修复序列化问题 + 错误处理）
        pyright = function()
          -- 初始化时获取 Python 路径（字符串类型，避免序列化错误）
          local function get_initial_python_path()
            local venv = require("swenv.api").get_current_venv()
            return venv and venv.python or "python"
          end
          local initial_python_path = get_initial_python_path()

          require("lspconfig").pyright.setup({
            on_attach = function(client, bufnr)
              local opts_base = { buffer = bufnr, silent = true } -- 基础选项

              -- 继承通用 LSP 快捷键
              vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts_base)
              vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts_base)
              vim.keymap.set("n", "K", vim.lsp.buf.hover, opts_base)
              vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts_base)
              vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts_base)

              -- 错误查看快捷键（显式合并选项，避免 ... 用法）
              vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, 
                vim.tbl_extend("force", opts_base, { desc = "显示当前行错误详情" })
              )
              vim.keymap.set("n", "]d", vim.diagnostic.goto_next, 
                vim.tbl_extend("force", opts_base, { desc = "跳转到下一个错误" })
              )
              vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, 
                vim.tbl_extend("force", opts_base, { desc = "跳转到上一个错误" })
              )
              vim.keymap.set("n", "<leader>q", function()
                vim.diagnostic.setloclist() -- 错误列表写入位置列表
                vim.cmd("lopen") -- 打开下方错误列表窗口
              end, vim.tbl_extend("force", opts_base, { desc = "显示所有错误列表" }))
              vim.keymap.set("n", "<leader>xx", "<cmd>Telescope diagnostics<CR>", 
                vim.tbl_extend("force", opts_base, { desc = "右侧显示可搜索的错误列表" })
              )

              -- 手动更新 LSP 环境配置（切换环境后用）
              vim.keymap.set("n", "<leader>lr", function()
                local venv = require("swenv.api").get_current_venv()
                if venv and venv.python then
                  client.config.settings.python.pythonPath = venv.python
                  client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
                  vim.notify("LSP 已同步至 " .. venv.name .. " 环境")
                end
              end, vim.tbl_extend("force", opts_base, { desc = "手动同步 LSP 环境" }))
            end,

            settings = {
              python = {
                pythonPath = initial_python_path, -- 字符串类型，解决序列化问题
                analysis = {
                  diagnosticMode = "workspace", -- 检查整个工作区
                  reportMissingImports = true, -- 报告缺失的库
                  reportSyntaxErrors = true, -- 报告语法错误
                  typeCheckingMode = "basic", -- 基础类型检查
                  autoSearchPaths = true, -- 自动搜索项目路径
                },
              },
            },
          })
        end,
      })
    end,
  },

  -- 2. Conda环境管理 (关键修复)
  {
    "AckslD/swenv.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    ft = "python",
    config = function()
      local conda_root = "D:/miniconda"
      local conda_envs_path = conda_root .. "/envs"

      -- 增强版环境验证
      local function is_valid_env(path)
        if vim.fn.isdirectory(path) ~= 1 then return false end
        -- Windows下检查python.exe的两种可能位置
        return vim.fn.filereadable(path .. "/python.exe") == 1 or
            vim.fn.filereadable(path .. "/Scripts/python.exe") == 1
      end

      -- 获取Python可执行文件完整路径
      local function get_python_exe(env_path)
        if vim.fn.filereadable(env_path .. "/python.exe") == 1 then
          return env_path .. "/python.exe"
        end
        return env_path .. "/Scripts/python.exe"
      end

      require("swenv").setup({
        get_venvs = function()
          local venvs = {}

          -- 硬编码确保yolo环境
          local yolo_path = conda_envs_path .. "/yolo"
          if is_valid_env(yolo_path) then
            table.insert(venvs, {
              name = "yolo",
              path = yolo_path,
              python = get_python_exe(yolo_path) -- 明确指定python路径
            })
          end

          -- 添加base环境
          if is_valid_env(conda_root) then
            table.insert(venvs, {
              name = "base",
              path = conda_root,
              python = get_python_exe(conda_root)
            })
          end

          -- 确保至少有一个环境
          if #venvs == 0 then
            vim.notify("未找到任何Python环境!", vim.log.levels.ERROR)
          end

          return venvs
        end,

        post_set_venv = function()
          local current_venv = require("swenv.api").get_current_venv()
          if current_venv then
            -- 更新LSP配置
            require("lspconfig").pyright.setup({
              settings = {
                python = {
                  pythonPath = current_venv.python or get_python_exe(current_venv.path)
                }
              }
            })
            vim.notify("已切换到: " .. current_venv.name .. "\n" .. current_venv.path)
          end
          vim.cmd("LspRestart")
        end
      })

      -- 切换环境快捷键
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "python",
        callback = function()
          vim.keymap.set("n", "<leader>cv", function()
            require("swenv.api").pick_venv()
          end, { desc = "切换Python环境", buffer = true })
        end
      })
    end
  },

  -- 3. 代码运行器 (关键修复)
  {
    "CRAG666/code_runner.nvim",
    ft = "python",
    config = function()
      require("code_runner").setup({
        filetype = {
          python = function()
            local venv = require("swenv.api").get_current_venv()
            if venv and venv.python then
              return venv.python .. " $fileName"
            end
            return "python $fileName" -- 回退到系统Python
          end
        },
        mode = "float",
        float = {
          border = "single",
        },
      })

      vim.keymap.set("n", "<leader>r", ":RunCode<CR>", { desc = "运行当前文件" })
    end
  },

  -- 其他插件...
  {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = { python = { "black", "isort" } } }
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "python" } }
  },
  {
    "mfussenegger/nvim-dap-python",
    config = function()
      require("dap-python").setup("python") -- 自动检测Python路径
    end
  }
}
