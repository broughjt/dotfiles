# Standard-Light theme for Kakoune
# Ported from the standard-light Emacs theme (standard-themes package)

# Color palette
declare-option str bg_main        'rgb:ffffff'
declare-option str fg_main        'rgb:000000'
declare-option str bg_dim         'rgb:ebebeb'
declare-option str fg_dim         'rgb:7f7f7f'
declare-option str bg_alt         'rgb:dcdcdc'
declare-option str fg_alt         'rgb:193f8f'
declare-option str bg_active      'rgb:bfbfbf'
declare-option str red            'rgb:b3303a'
declare-option str red_faint      'rgb:b22222'
declare-option str green          'rgb:228b22'
declare-option str blue           'rgb:001faf'
declare-option str blue_warmer    'rgb:3a5fcd'
declare-option str blue_cooler    'rgb:0000ff'
declare-option str blue_faint     'rgb:483d8b'
declare-option str magenta_cooler 'rgb:800080'
declare-option str magenta_warmer 'rgb:8b2252'
declare-option str cyan_cooler    'rgb:008b8b'
declare-option str yellow_cooler  'rgb:a0522d'
declare-option str bg_mode_line   'rgb:b3b3b3'
declare-option str fg_mode_line   'rgb:000000'
declare-option str cursor         'rgb:000000'
declare-option str fg_space       'rgb:bababa'

declare-option str psel 'rgb:eedc82'
declare-option str ssel 'rgb:b4eeb4'

# For code
set-face global value    "%opt{fg_main}"
set-face global type     "%opt{green}"
set-face global variable "%opt{yellow_cooler}"
set-face global keyword  "%opt{magenta_cooler}"
set-face global module   "%opt{fg_main}"
set-face global function "%opt{blue_cooler}"
set-face global string   "%opt{magenta_warmer}"
set-face global builtin  "%opt{blue_faint}"
set-face global constant "%opt{cyan_cooler}"
set-face global comment  "%opt{red_faint}"
set-face global meta     "%opt{red}"

set-face global operator "%opt{fg_main}"
set-face global comma    "%opt{fg_main}"
set-face global bracket  "%opt{fg_alt}"

# For markup
set-face global title  "%opt{magenta_cooler}"
set-face global header "%opt{yellow_cooler}"
set-face global bold   "%opt{magenta_cooler}"
set-face global italic "%opt{blue}"
set-face global mono   "%opt{green}"
set-face global block  "%opt{blue_warmer}"
set-face global link   "%opt{blue_warmer}"
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
set-face global MatchingChar       "%opt{cyan_cooler},%opt{bg_main}"
set-face global Whitespace         "%opt{fg_space},%opt{bg_main}+f"
set-face global WrapMarker         Whitespace
set-face global BufferPadding      "%opt{bg_main},%opt{bg_main}"
