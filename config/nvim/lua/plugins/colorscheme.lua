-- Gruvbox, matching the desktop palette (i3, polybar, rofi, dunst, alacritty).
-- The background is transparent: it comes from alacritty (#191c1c, 90 % opacity).
-- To go back to catppuccin: set colorscheme = "catppuccin-frappe" below (LazyVim ships it).
return {
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      contrast = "hard",
      transparent_mode = true,
      italic = {
        strings = false,
        emphasis = true,
        comments = true,
        operators = false,
        folds = true,
      },
      overrides = {
        CursorLine = { bg = "#252a2a" },
        CursorLineNr = { fg = "#fb4934", bold = true },
        Visual = { bg = "#313838" },
        NormalFloat = { bg = "NONE" },
        FloatBorder = { fg = "#313838", bg = "NONE" },
        WinSeparator = { fg = "#313838", bg = "NONE" },
        TelescopeBorder = { fg = "#313838", bg = "NONE" },
        TelescopeSelection = { bg = "#252a2a" },
        TelescopePromptPrefix = { fg = "#fb4934" },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
