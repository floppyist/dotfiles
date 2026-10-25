-- Desktop palette from dotfiles.conf (generated: ~/.config/dotfiles/nvim.lua).
-- Falls back to the defaults when `dotfiles apply` has not run yet.
local defaults = {
  bg = "#191c1c",
  surface = "#252a2a",
  overlay = "#313838",
  fg = "#ebdbb2",
  subtle = "#a89984",
  muted = "#7c6f64",
  accent = "#cc241d",
  accent_text = "#fb4934",
  on_accent = "#191c1c",
  red = "#fb4934",
  green = "#b8bb26",
  yellow = "#fabd2f",
  blue = "#83a598",
  purple = "#d3869b",
  aqua = "#8ec07c",
  orange = "#fe8019",
}

local ok, generated = pcall(dofile, vim.fn.expand("~/.config/dotfiles/nvim.lua"))
if ok and type(generated) == "table" then
  return vim.tbl_extend("force", defaults, generated)
end
return defaults
