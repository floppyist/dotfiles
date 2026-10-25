-- UI in the desktop design: sharp frames, accent blocks like polybar, rofi-style pickers.
local p = require("config.palette")

-- Lualine: the mode is a solid block like the focused polybar workspace (accent in normal
-- mode, the gruvbox color of the mode otherwise); the clock on the right mirrors it.
local function mode(color)
  return {
    a = { fg = p.on_accent, bg = color, gui = "bold" },
    b = { fg = p.fg, bg = p.surface },
    c = { fg = p.subtle, bg = "NONE" },
  }
end

local theme = {
  normal = mode(p.accent),
  insert = mode(p.green),
  visual = mode(p.purple),
  replace = mode(p.orange),
  command = mode(p.yellow),
  terminal = mode(p.aqua),
  inactive = {
    a = { fg = p.muted, bg = p.surface },
    b = { fg = p.muted, bg = p.surface },
    c = { fg = p.muted, bg = "NONE" },
  },
}

return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.theme = theme
      opts.options.section_separators = { left = "", right = "" }
      opts.options.component_separators = { left = "", right = "" }
    end,
  },

  -- Telescope: prompt "❯" and an accent bar on the selected row, like rofi
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    opts = {
      defaults = {
        prompt_prefix = " ❯ ",
        selection_caret = "▌ ",
        entry_prefix = "  ",
        borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
      },
    },
  },

  {
    "folke/noice.nvim",
    optional = true,
    opts = {
      views = {
        cmdline_popup = { border = { style = "single" } },
        popupmenu = { border = { style = "single" } },
        hover = { border = { style = "single" } },
        confirm = { border = { style = "single" } },
      },
    },
  },

  {
    "folke/which-key.nvim",
    optional = true,
    opts = { win = { border = "single" } },
  },

  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      completion = {
        menu = { border = "single" },
        documentation = { window = { border = "single" } },
      },
      signature = { window = { border = "single" } },
    },
  },

  {
    "folke/snacks.nvim",
    optional = true,
    opts = {
      styles = {
        notification = { border = "single" },
        notification_history = { border = "single" },
        input = { border = "single" },
        scratch = { border = "single" },
        float = { border = "single" },
        terminal = { border = "single" },
      },
    },
  },

  {
    "mason-org/mason.nvim",
    optional = true,
    opts = { ui = { border = "single" } },
  },
}
