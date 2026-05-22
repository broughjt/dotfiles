# Standard-Dark theme for Kakoune
# Ported from the standard-dark Emacs theme (standard-themes package)

# Color palette
declare-option str bg_main       'rgb:000000'
declare-option str fg_main       'rgb:ffffff'
declare-option str bg_dim        'rgb:272727'
declare-option str fg_dim        'rgb:a6a6a6'
declare-option str bg_alt        'rgb:363636'
declare-option str fg_alt        'rgb:a0afef'
declare-option str bg_active     'rgb:606060'
declare-option str red           'rgb:ff6f60'
declare-option str red_warmer    'rgb:ff7f24'
declare-option str green         'rgb:44cc44'
declare-option str green_cooler  'rgb:98fb98'
declare-option str yellow        'rgb:eedd82'
declare-option str yellow_cooler 'rgb:ffa07a'
declare-option str blue          'rgb:87ceff'
declare-option str blue_faint    'rgb:b0c4de'
declare-option str magenta_cooler 'rgb:ce82ff'
declare-option str cyan          'rgb:00ffff'
declare-option str cyan_warmer   'rgb:87cefa'
declare-option str cyan_cooler   'rgb:7fffd4'
declare-option str bg_mode_line  'rgb:505050'
declare-option str fg_mode_line  'rgb:ffffff'
declare-option str cursor        'rgb:ffffff'
declare-option str fg_space      'rgb:606070'

declare-option str psel 'rgb:20009d'
declare-option str ssel 'rgb:334815'

# For code
set-face global value    "%opt{fg_main}"
set-face global type     "%opt{green_cooler}"
set-face global variable "%opt{yellow}"
set-face global keyword  "%opt{cyan}"
set-face global module   "%opt{fg_main}"
set-face global function "%opt{cyan_warmer}"
set-face global string   "%opt{yellow_cooler}"
set-face global builtin  "%opt{blue_faint}"
set-face global constant "%opt{cyan_cooler}"
set-face global comment  "%opt{red_warmer}"
set-face global meta     "%opt{red}"

set-face global operator "%opt{fg_main}"
set-face global comma    "%opt{fg_main}"
set-face global bracket  "%opt{fg_alt}"

# For markup
set-face global title  "%opt{magenta_cooler}"
set-face global header "%opt{yellow}"
set-face global bold   "%opt{magenta_cooler}"
set-face global italic "%opt{cyan}"
set-face global mono   "%opt{green}"
set-face global block  "%opt{blue}"
set-face global link   "%opt{cyan}"
set-face global bullet "%opt{green}"
set-face global list   "%opt{fg_main}"

# Builtin faces
set-face global Default            "%opt{fg_main},%opt{bg_main}"
set-face global PrimarySelection   "default,%opt{psel}"
set-face global SecondarySelection "default,%opt{ssel}"
set-face global PrimaryCursor      "%opt{bg_main},%opt{cursor}"
set-face global SecondaryCursor    "%opt{bg_main},%opt{fg_alt}"
set-face global PrimaryCursorEol   "%opt{bg_main},%opt{red}"
set-face global SecondaryCursorEol "%opt{bg_main},%opt{blue}"
set-face global LineNumbers        "%opt{fg_dim},%opt{bg_main}"
set-face global LineNumberCursor   "%opt{fg_alt},%opt{bg_main}+b"
set-face global LineNumbersWrapped "%opt{bg_dim},%opt{bg_main}+i"
set-face global MenuForeground     "%opt{bg_main},%opt{fg_main}+b"
set-face global MenuBackground     "%opt{fg_main},%opt{bg_alt}"
set-face global MenuInfo           "%opt{fg_alt},%opt{bg_alt}"
set-face global Information        "%opt{fg_mode_line},%opt{bg_mode_line}"
set-face global Error              "%opt{red},%opt{bg_mode_line}"
set-face global StatusLine         "%opt{fg_mode_line},%opt{bg_mode_line}"
set-face global StatusLineMode     "%opt{fg_mode_line},%opt{bg_mode_line}"
set-face global StatusLineInfo     "%opt{fg_mode_line},%opt{bg_mode_line}"
set-face global StatusLineValue    "%opt{fg_mode_line},%opt{bg_mode_line}"
set-face global StatusCursor       "%opt{fg_main},%opt{blue}"
set-face global Prompt             "%opt{fg_mode_line},%opt{bg_mode_line}"
set-face global MatchingChar       "%opt{cyan},%opt{bg_main}"
set-face global Whitespace         "%opt{fg_space},%opt{bg_main}+f"
set-face global WrapMarker         Whitespace
set-face global BufferPadding      "%opt{bg_main},%opt{bg_main}"
