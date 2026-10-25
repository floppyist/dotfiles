-- Gruvbox, matching the desktop palette (i3, polybar, rofi, dunst, alacritty).
-- Palette and accent come from dotfiles.conf (lua/config/palette.lua).
-- The background is transparent: it comes from alacritty (bg, terminal_opacity).
-- To go back to catppuccin: set colorscheme = "catppuccin-frappe" below (LazyVim ships it).
local p = require("config.palette")

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
        -- editor
        CursorLine = { bg = p.surface },
        CursorLineNr = { fg = p.accent_text, bold = true },
        LineNr = { fg = p.muted },
        Visual = { bg = p.overlay },
        WinSeparator = { fg = p.overlay, bg = "NONE" },
        StatusLine = { bg = "NONE" },
        -- floating windows: sharp frame in the overlay color, title in the accent
        NormalFloat = { bg = "NONE" },
        FloatBorder = { fg = p.overlay, bg = "NONE" },
        FloatTitle = { fg = p.accent_text, bold = true },
        Pmenu = { bg = p.bg, fg = p.subtle },
        PmenuSel = { bg = p.surface, fg = p.fg, bold = true },
        PmenuSbar = { bg = p.bg },
        PmenuThumb = { bg = p.overlay },
        -- telescope: rofi look (prompt chevron, accent bar on the selected row)
        TelescopeBorder = { fg = p.overlay, bg = "NONE" },
        TelescopePromptBorder = { fg = p.overlay, bg = "NONE" },
        TelescopeResultsBorder = { fg = p.overlay, bg = "NONE" },
        TelescopePreviewBorder = { fg = p.overlay, bg = "NONE" },
        TelescopeTitle = { fg = p.accent_text, bold = true },
        TelescopeResultsTitle = { fg = p.subtle },
        TelescopePreviewTitle = { fg = p.subtle },
        TelescopePromptTitle = { fg = p.on_accent, bg = p.accent, bold = true },
        TelescopePromptPrefix = { fg = p.accent_text },
        TelescopeSelection = { bg = p.surface, fg = p.fg, bold = true },
        TelescopeSelectionCaret = { fg = p.accent, bg = p.surface },
        TelescopeMatching = { fg = p.accent_text, bold = true },
        TelescopeResultsNormal = { fg = p.subtle },
        -- completion (blink.cmp)
        BlinkCmpMenu = { bg = p.bg, fg = p.subtle },
        BlinkCmpMenuBorder = { fg = p.overlay, bg = "NONE" },
        BlinkCmpMenuSelection = { bg = p.surface, fg = p.fg, bold = true },
        BlinkCmpLabelMatch = { fg = p.accent_text, bold = true },
        BlinkCmpDocBorder = { fg = p.overlay, bg = "NONE" },
        BlinkCmpSignatureHelpBorder = { fg = p.overlay, bg = "NONE" },
        -- command line popup and messages (noice)
        NoiceCmdlinePopupBorder = { fg = p.overlay },
        NoiceCmdlinePopupTitle = { fg = p.accent_text, bold = true },
        NoiceCmdlineIcon = { fg = p.accent_text },
        NoiceCmdlinePopupBorderSearch = { fg = p.overlay },
        NoiceCmdlineIconSearch = { fg = p.yellow },
        -- which-key
        WhichKeyBorder = { fg = p.overlay },
        WhichKeyTitle = { fg = p.accent_text, bold = true },
        WhichKey = { fg = p.accent_text },
        WhichKeyGroup = { fg = p.blue },
        WhichKeyDesc = { fg = p.fg },
        WhichKeySeparator = { fg = p.muted },
        -- dashboard and notifications (snacks)
        SnacksDashboardHeader = { fg = p.accent },
        SnacksDashboardIcon = { fg = p.accent_text },
        SnacksDashboardKey = { fg = p.accent_text, bold = true },
        SnacksDashboardDesc = { fg = p.fg },
        SnacksDashboardFooter = { fg = p.muted },
        SnacksDashboardSpecial = { fg = p.accent_text },
        SnacksNotifierBorderInfo = { fg = p.blue },
        SnacksNotifierBorderWarn = { fg = p.yellow },
        SnacksNotifierBorderError = { fg = p.red },
        SnacksInputBorder = { fg = p.overlay },
        SnacksInputTitle = { fg = p.accent_text, bold = true },
        -- file tree
        NeoTreeWinSeparator = { fg = p.overlay, bg = "NONE" },
        NeoTreeCursorLine = { bg = p.surface },
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
