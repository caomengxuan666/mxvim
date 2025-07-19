return { -- C++ LSP 配置（增强补全与依赖解析）
{
    "neovim/nvim-lspconfig",
    dependencies = {"williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim"},
    ft = {"c", "cpp", "h", "hpp"},
    config = function()
        require("mason").setup()
        require("mason-lspconfig").setup({
            ensure_installed = {"clangd", "cmake"} -- 确保安装 C++ 和 CMake LSP
        })

        -- C++ LSP (clangd) 配置
        require("lspconfig").clangd.setup({
            cmd = {"clangd", "--background-index", "--compile-commands-dir=build", "-j=64", "--all-scopes-completion",
                   "--completion-style=detailed", "--header-insertion=iwyu", "--header-insertion-decorators",
                   "--pch-storage=memory", "--cross-file-rename", "--enable-config", "--fallback-style=WebKit",
                   "--pretty", "--suggest-missing-includes", "--clang-tidy", "--limit-results=100",
                   "--query-driver=C:/Program Files/Microsoft Visual Studio/2022/Preview/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe",
                   "--clang-tidy-checks=cppcoreguidelines-*,performance-*,buggrone-*,portablity-*,modernize-*,google-*"},
            on_attach = function(client, bufnr)
                local opts = {
                    buffer = bufnr,
                    silent = true
                }
                -- C++ 常用 LSP 快捷键
                vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
                vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
                vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
                vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
                vim.keymap.set("n", "<leader>rf", vim.lsp.buf.references, opts) -- 查看引用
            end
        })

        -- CMake LSP 配置（提供 CMakeLists.txt 补全）
        require("lspconfig").cmake.setup({
            cmd = {"cmake-language-server"}, -- 依赖 mason 安装的 cmake-language-server
            filetypes = {"cmake"},
            init_options = {
                buildDirectory = "build" -- 指向构建目录
            }
        })
    end
}, -- 调试支持
{
    "mfussenegger/nvim-dap",
    dependencies = {"jay-babu/mason-nvim-dap.nvim", "nvim-neotest/nvim-nio", -- 异步支持
    "rcarriga/nvim-dap-ui" -- 调试 UI
    },
    ft = {"c", "cpp"},
    config = function()
        require("mason-nvim-dap").setup({
            ensure_installed = {"lldb"} -- C++ 调试器
        })

        local dap = require("dap")
        -- 配置 lldb 调试器
        dap.adapters.lldb = {
            type = "executable",
            command = "lldb-vscode", -- mason 安装的 lldb 适配器
            name = "lldb"
        }

        -- C++ 调试配置
        dap.configurations.cpp = {{
            name = "Launch",
            type = "lldb",
            request = "launch",
            -- 自动获取 build 目录下的可执行文件（优先选择与项目名匹配的）
            program = function()
                local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
                return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/build/" .. project_name, "file")
            end,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
            args = {}, -- 可添加命令行参数
            runInTerminal = false
        }}
        -- C 调试复用 C++ 配置
        dap.configurations.c = dap.configurations.cpp

        -- 调试 UI 配置
        require("dapui").setup({
            floating = {
                border = "rounded"
            } -- 圆角边框
        })
        -- 调试开始时自动打开 UI
        dap.listeners.after.event_initialized["dapui_config"] = function()
            require("dapui").open()
        end
    end
}, -- 代码补全增强（与 LSP 配合）
{
    "hrsh7th/nvim-cmp",
    dependencies = {"hrsh7th/cmp-nvim-lsp", -- LSP 补全源
    "hrsh7th/cmp-path", -- 路径补全
    "hrsh7th/cmp-buffer" -- 缓冲区补全
    },
    ft = {"c", "cpp", "cmake"},
    config = function()
        local cmp = require("cmp")
        cmp.setup({
            sources = {{
                name = "nvim_lsp"
            }, -- 优先使用 LSP 补全（包括 CMake 和 C++）
            {
                name = "path"
            }, {
                name = "buffer"
            }},
            mapping = cmp.mapping.preset.insert({
                ["<CR>"] = cmp.mapping.confirm({
                    select = true
                }), -- 回车确认补全
                ["<Tab>"] = cmp.mapping.select_next_item(), -- Tab 下一个
                ["<S-Tab>"] = cmp.mapping.select_prev_item() -- Shift+Tab 上一个
            })
        })
    end
}, -- CMake 自动化构建工具（适配最新 API）
{
    "Civitasv/cmake-tools.nvim",
    ft = {"c", "cpp", "cmake"},
    dependencies = {"nvim-lua/plenary.nvim" -- 官网明确要求的依赖
    },
    config = function()
        -- 官网推荐：引入系统判断模块
        local osys = require("cmake-tools.osys")

        -- 严格按照官网默认配置初始化
        require("cmake-tools").setup({
            cmake_command = "cmake", -- CMake 命令路径（官网默认）
            ctest_command = "ctest", -- CTest 命令路径（官网默认）
            cmake_use_preset = true, -- 官网默认启用 preset
            cmake_regenerate_on_save = true, -- 保存 CMakeLists.txt 时自动重新生成
            -- cmake_generate_options = {"-DCMAKE_EXPORT_COMPILE_COMMANDS=1"}, -- 生成编译命令文件
            cmake_build_options = {"-j64"}, -- 构建时的额外参数

            -- 构建目录配置（官网推荐格式，支持宏扩展）
            cmake_build_directory = function()
                if osys.iswin32 then
                    return "out\\${variant:buildType}" -- Windows 路径格式
                else
                    return "out/${variant:buildType}" -- 类 Unix 路径格式
                end
            end,

            -- 关键：生成时传递vcpkg工具链参数，与命令行效果一致
            cmake_generate_options = {"-DCMAKE_TOOLCHAIN_FILE=D:/vcpkg/scripts/buildsystems/vcpkg.cmake",
                                      "-DVCPKG_TARGET_TRIPLET=x64-windows", -- 告诉 vcpkg 使用 x64 版本的库
            "-A x64", -- 关键补充：告诉 CMake 构建架构为 x64（针对 VS 生成器）
            "-DCMAKE_EXPORT_COMPILE_COMMANDS=1"},

            -- 编译命令处理（官网默认使用软链接）
            cmake_compile_commands_options = {
                action = "soft_link", -- 软链接到项目根目录
                target = vim.loop.cwd() -- 目标路径（项目根目录）
            },

            -- 调试配置（与官网保持一致，使用 codelldb）
            cmake_dap_configuration = {
                name = "cpp",
                type = "codelldb",
                request = "launch",
                stopOnEntry = false,
                runInTerminal = true,
                console = "integratedTerminal"
            },

            -- 执行器配置（官网默认使用 quickfix）
            cmake_executor = {
                name = "quickfix",
                opts = {},
                default_opts = {
                    quickfix = {
                        show = "always",
                        position = "belowright",
                        size = 10,
                        encoding = "utf-8",
                        auto_close_when_success = true
                    }
                }
            },

            -- 运行器配置（官网默认使用 terminal）
            cmake_runner = {
                name = "terminal",
                opts = {},
                default_opts = {
                    terminal = {
                        name = "Main Terminal",
                        prefix_name = "[CMakeTools]: ",
                        split_direction = "horizontal",
                        split_size = 11,
                        start_insert = false,
                        focus = false
                    }
                }
            },

            -- 通知设置（官网默认启用）
            cmake_notifications = {
                runner = {
                    enabled = true
                },
                executor = {
                    enabled = true
                },
                spinner = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"},
                refresh_rate_ms = 100
            },

            -- 其他官网默认配置
            cmake_virtual_text_support = true,
            cmake_use_scratch_buffer = false
        })

        -- 快捷键配置（严格对应官网命令）
        local opts = {
            noremap = true,
            silent = true
        }
        local cmake = require("cmake-tools")


        -- 官网核心命令映射
        vim.keymap.set("n", "<leader>cc", function()
            cmake.generate({})
        end, opts) -- 生成构建文件
        vim.keymap.set("n", "<leader>cb", function()
            cmake.build({})
        end, opts) -- 构建项目

        vim.keymap.set("n", "<leader>cr", function()
            cmake.run({})
        end, opts) -- 运行程序
        
        vim.keymap.set("n", "<leader>F5", function()
            cmake.debug({})
        end, opts) -- 调试程序
        vim.keymap.set("n", "<leader>cx", function()
            cmake.clean()
        end, opts) -- 清理构建产物
        vim.keymap.set("n", "<leader>ct", function()
            cmake.select_build_type()
        end, opts) -- 选择构建类型
        vim.keymap.set("n", "<leader>ck", function()
            cmake.select_kit()
        end, opts) -- 选择工具链
    end
}}
