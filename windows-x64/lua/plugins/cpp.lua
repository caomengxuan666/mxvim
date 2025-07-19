return {
  -- 1. CMake 项目管理（保持不变）
  {
    "Civitasv/cmake-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    ft = { "c", "cpp", "cmake" },
    config = function()
      require("cmake-tools").setup({
        cmake_command = "cmake",
        cmake_regenerate_on_save = true,
        build_dir = tostring(vim.fn.getcwd() .. "/build"),
        build_type = "Debug",
        keymaps = {
          toggle_panel = "<leader>cm",
          run = "<leader>cr",
          build = "<leader>cb",
          debug = "<leader>cd",
        },
      })
    end,
  },

  -- 2. C++ LSP 配置（保持不变）
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    ft = { "c", "cpp", "h", "hpp" },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup()

      require("lspconfig").clangd.setup({
        cmd = {
          "clangd",
          "--background-index",
          "--compile-commands-dir=build",
          "--suggest-missing-includes",
          "--clang-tidy",
        },
        on_attach = function(client, bufnr)
          local opts = { buffer = bufnr }
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
          vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
        end,
      })
    end,
  },

  -- 3. 调试支持（添加 nvim-nio 依赖）
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "jay-babu/mason-nvim-dap.nvim",
      -- 新增：添加 nvim-nio 依赖
      "nvim-neotest/nvim-nio",
      -- nvim-dap-ui 依赖 nvim-nio
      "rcarriga/nvim-dap-ui",
    },
    ft = { "c", "cpp" },
    config = function()
      require("mason-nvim-dap").setup({
        ensure_installed = { "lldb" },
      })

      local dap = require("dap")
      dap.adapters.lldb = {
        type = "executable",
        command = "lldb-vscode",
        name = "lldb",
      }

      dap.configurations.cpp = {
        {
          name = "Launch",
          type = "lldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/build/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          args = {},
          runInTerminal = false,
        },
      }

      dap.configurations.c = dap.configurations.cpp

      require("dapui").setup()
      dap.listeners.after.event_initialized["dapui_config"] = function()
        require("dapui").open()
      end
    end,
  },

  -- 4. 语法高亮（保持不变）
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "c", "cpp" })
      end
    end,
  },
}
