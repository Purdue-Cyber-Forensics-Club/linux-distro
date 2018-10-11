" vim: foldmethod=marker nowrap
"
" Grammar {{{
" <Template>                  ::= <Line>*
" <Line>                      ::= <EmptyLine> | <Comment> | <KeyValuePair> | <HiGroupDef> |
"                                 <VerbatimText>  | <AuxFile> | <Documentation>
" <VerbatimText>              ::= verbatim <Anything> endverbatim
" <AuxFile>                   ::= auxfile <Path> <Anything> endauxfile
" <Path>                      ::= .+
" <Documentation>             ::= documentation <Anything> enddocumentation
" <Anything>                  ::= .*
" <Comment>                   ::= # .*
" <KeyValuePair>              ::= <PaletteSpec> | <ColorDef> | <Key> : <Value>
" <Key>                       ::= Full name | Short name | Author | Background | ...
" <Value>                     ::= .*
" <PaletteSpec>               ::= <PaletteName> [<Arg> [<Arg>]*]
" <PaletteName>               ::= \w\+
" <Arg>                       ::= number or word
" <ColorDef>                  ::= Color : <ColorName> <GUIValue> <Base256Value> [ <Base16Value> ]
" <ColorName>                 ::= [a-z1-9_]+
" <GUIValue>                  ::= <HexValue> | <RGBValue> | <RGBColorName>
" <HexValue>                  ::= #[a-f0-9]{6}
" <RGBValue>                  ::= rgb ( <8BitNumber> , <8BitNumber> , <8BitNumber> )
" <RGBColorName>              ::= See $VIMRUNTIME/rgb.txt
" <Base256Value>              ::= ~ | <8BitNumber>
" <8BitNumber>                ::= 0 | 1 | ... | 255
" <Base16Value>               ::= 0 | 1 | ... | 15 | Black | DarkRed | ...
" <HiGroupDef>                ::= <LinkedGroup> | <BaseGroup>
" <LinkedGroup>               ::= <HiGroupName> -> <HiGroupName>
" <BaseGroup>                 ::= <HiGroupName> <FgColor> <BgColor> <Attributes>
" <FgColor>                   ::= <ColorName>
" <BgColor>                   ::= <ColorName>
" <Attributes>                ::= <StyleDef>*
" <StyleDef>                  ::= t[term] = <AttrList> | g[ui] = <AttrList> | guisp = <ColorName> | s = <ColorName> | <AttrList>
" <AttrList>                  ::= <Attr> [, <AttrList]
" <Attr>                      ::= bold | italic | reverse | inverse | underline | ...
" }}}
" Generic helper functions {{{
fun! s:slash() abort " Code borrowed from Pathogen (thanks T. Pope!)
  return !exists("+shellslash") || &shellslash ? '/' : '\'
endf

fun! s:is_absolute(path) abort " Code borrowed from Pathogen (thanks T. Pope)
  return a:path =~# (has('win32') ? '^\%([\\/]\|\w:\)[\\/]\|^[~$]' : '^[/~$]')
endf

" Returns path as an absolute path, after verifying that path is valid,
" i.e., it is inside the directory specified in env.
"
" path: a String specifying a relative or absolute path
" env:  a Dictionary with a 'dir' key specifying a valid directory for path.
fun! s:full_path(path, env)
  if s:is_absolute(a:path)
    let l:path = simplify(fnamemodify(a:path, ":p"))
  else
    let l:path = simplify(fnamemodify(a:env['dir'] . s:slash() . a:path, ":p"))
  endif
  let l:dir = simplify(fnamemodify(a:env['dir'], ":p"))
  if !isdirectory(l:dir)
    throw 'FATAL: Path is not a directory: ' . l:dir
  endif
  if match(l:path, '^' . l:dir) == -1
    throw 'Path ' . l:path . ' outside valid directory: ' . l:dir
  endif
  return l:path
endf

fun! s:make_dir(dirpath)
  let l:dirpath = fnamemodify(a:dirpath, ":p")
  if isdirectory(l:dirpath)
    return
  endif
  try
    call mkdir(fnameescape(l:dirpath), "p")
  catch /.*/
    throw 'Could not create directory: ' . l:dirpath
  endtry
endf

" Write the current buffer into path. The path must be inside env['dir'].
fun! s:write_buffer(path, env, overwrite)
  let l:path = s:full_path(a:path, a:env)
  call s:make_dir(fnamemodify(l:path, ":h"))
  if bufloaded(l:path)
    if a:overwrite
      execute "bdelete" bufname(a:path)
    else
      throw "Buffer " . l:path . " exists. Use ! to override."
    endif
  endif
  try
    execute (a:overwrite ? 'write!' : 'write') fnameescape(l:path)
  catch /.*/
    throw 'Could not write ' . l:path . ': ' . v:exception
  endtry
endf

" Without arguments, returns a Dictionary of the color names from $VIMRUNTIME/rgb.txt
" (converted to all lowercase), with the associated hex values.
" If an argument is given, returns the hex value of the specified color name.
fun! s:get_rgb_colors(...) abort
  if !exists('s:rgb_colors')
    let s:rgb_colors = {}
    " Add some color names not in rgb.txt (see syntax.c for the values)
    let s:rgb_colors['darkyellow']   = '#af5f00' " 130
    let s:rgb_colors['lightmagenta'] = '#ffd7ff' " 225
    let s:rgb_colors['lightred']     = '#ffd7d7' " 224
    let l:rgb = readfile($VIMRUNTIME . s:slash() . 'rgb.txt')
    for l:line in l:rgb
      let l:match = matchlist(l:line, '^\s*\(\d\+\)\s*\(\d\+\)\s*\(\d\+\)\s*\(.*\)$')
      if len(l:match) > 4
        let [l:name, l:r, l:g, l:b] = [l:match[4], str2nr(l:match[1]), str2nr(l:match[2]), str2nr(l:match[3])]
        let s:rgb_colors[tolower(l:name)] = colortemplate#colorspace#rgb2hex(l:r, l:g, l:b)
      endif
    endfor
  endif
  if a:0 > 0
    if has_key(s:rgb_colors, tolower(a:1))
      return s:rgb_colors[tolower(a:1)]
    else
      throw 'Unknown RGB color name: ' . a:1
    endif
  endif
  return s:rgb_colors
endf

fun! s:add_error(path, line, col, msg)
  call setloclist(0, [{'filename': a:path, 'lnum' : a:line + 1, 'col': a:col, 'text' : a:msg, 'type' : 'E'}], 'a')
endf

fun! s:add_warning(path, line, col, msg)
  if !get(g:, 'colortemplate_no_warnings', 0)
    call setloclist(0, [{'filename': a:path, 'lnum' : a:line + 1, 'col': a:col, 'text' : a:msg, 'type' : 'W'}], 'a')
  endif
endf

fun! s:add_generic_error(msg)
  call s:add_error(bufname('%'), 0, 1, a:msg)
endf

fun! s:add_generic_warning(msg)
  call s:add_warning(bufname('%'), 0, 1, a:msg)
endf

fun! s:print_error_msg(msg, rethrow)
  redraw
  echo "\r"
  if a:rethrow
    echoerr '[Colortemplate]' a:msg
  else
    echohl Error
    echomsg '[Colortemplate]' a:msg
    echohl None
  endif
endf

" Append a String to the end of the current buffer.
fun! s:put(line)
  call append('$', a:line)
endf
" }}} Helper functions
" Internal state {{{
" Working directory {{{
fun! s:init_working_directory(path)
  if !isdirectory(a:path)
    throw 'FATAL: Path is not a directory: ' . a:path
  endif
  let s:work_dir = fnamemodify(a:path, ":p")
  execute 'lcd' s:work_dir
endf

fun! s:working_directory()
  return s:work_dir
endf
" }}}
" Template {{{
" path: path of the currently processed file
" data: the List of the lines from the file
" linenr: the currently processed line from data
" numlines: total number of lines in the file (i.e. length of data)
" includes: the currently processed included file
" NOTE: we do not keep the whole tree of included files because we process
" everything in one pass in a streaming fashion.
fun! s:new_template()
  return {
        \ 'path':            '',
        \ 'data':            [],
        \ 'linenr':          -1,
        \ 'numlines':         0,
        \ 'includes':        {},
        \ 'load':            function("s:load"),
        \ 'include':         function("s:include"),
        \ 'include_palette': function("s:include_palette"),
        \ 'getl':            function("s:getl"),
        \ 'next_line':       function("s:next_line"),
        \ 'eof':             function("s:eof"),
        \ 'curr_pos':        function("s:curr_pos")
        \ }
endf

fun! s:init_template()
  let s:template = s:new_template()
endf

fun! s:load(path) dict
  let self.path = fnameescape(s:full_path(a:path, {'dir': s:work_dir}))
  let self.data = readfile(self.path)
  let self.numlines = len(self.data)
endf

fun! s:include(path) dict
  if empty(self.includes)
    let self.includes = s:new_template()
  else
    return self.includes.include(a:path)
  endif
  call self.includes.load(a:path)
  let self.includes.linenr = -1
endf

fun! s:eof() dict
  return self.linenr >= self.numlines
endf

" string params are expected to be properly quoted
fun! s:include_palette(name, params) dict
  try
    execute 'let l:colors = colortemplate#'.a:name.'#palette('.join(map(a:params, { _,v -> v =~# '\m^[0-9]\+$' ? v : "'".v."'" }), ',').')'
  catch /.*/
    throw 'Could not load palette: ' . v:exception
  endtry
  let self.includes = s:new_template()
  let self.includes.data = colortemplate#format_palette(l:colors)
  let self.includes.numlines = len(l:colors)
  let self.includes.linenr = -1
endf

" Get current line.
" NOTE: it must be called only after s:next_line() has been invoked at least once.
fun! s:getl() dict
  if empty(self.includes) || self.includes.eof()
    if self.linenr < 0
      throw 'FATAL: invalid call to getl()' " This should never happen, unless there is a bug
    endif
    return self.data[self.linenr]
  else
    return self.includes.getl()
  endif
endf

" Move to the next line. Returns 0 if at eof, 1 otherwise.
fun! s:next_line() dict
  if empty(self.includes)
    let self.linenr += 1
    return !self.eof()
  elseif self.includes.next_line()
    return 1
  else " End of included file
    let self.includes = {}
    let self.linenr += 1
    return !self.eof()
  endif
endf

fun! s:curr_pos() dict
  if empty(self.includes) || self.includes.eof()
    return [self.path, self.linenr]
  else
    return self.includes.curr_pos()
  endif
endf
" }}}
" Tokenizer {{{
" Current token in the currently parsed line
let s:token = { 'spos' :  0, 'pos'  :  0, 'value': '', 'kind' : '' }

fun! s:token.reset() dict
  let self.spos  = 0
  let self.pos   = 0
  let self.value = ''
  let self.kind  = ''
endf

fun! s:token.next() dict
  let [l:char, self.spos, self.pos] = matchstrpos(s:template.getl(), '\s*\zs\S', self.pos) " Get first non-white character starting at pos
  if empty(l:char)
    let self.kind = 'EOL'
    let self.spos = len(s:template.getl()) - 1 " For correct error location
  elseif l:char =~? '\m\a'
    let [self.value, self.spos, self.pos] = matchstrpos(s:template.getl(), '\w\+', self.pos - 1)
    let self.kind = 'WORD'
  elseif l:char =~# '\m[0-9]'
    let [self.value, self.spos, self.pos] = matchstrpos(s:template.getl(), '\d\+', self.pos - 1)
    let self.kind = 'NUM'
  elseif l:char ==# '#'
    if match(s:template.getl(), '^[0-9a-f]\{6}', self.pos) > -1
      let [self.value, self.spos, self.pos] = matchstrpos(s:template.getl(), '#[0-9a-f]\{6}', self.pos - 1)
      let self.kind = 'HEX'
    else
      let self.value = '#'
      let self.kind = 'COMMENT'
    endif
  elseif match(l:char, "[:=.,>~)(-]") > -1
    let self.value = l:char
    let self.kind = l:char
  else
    throw 'Invalid token'
  endif
  return self
endf

fun! s:token.peek() dict
  let l:token = copy(self)
  return l:token.next()
endf
" }}}
" Info {{{
fun! s:init_info()
  let s:info = {
        \ 'fullname': '',
        \ 'shortname': '',
        \ 'author': '',
        \ 'maintainer': '',
        \ 'website': '',
        \ 'description': '',
        \ 'license': '',
        \ 'terminalcolors': ['256'],
        \ 'prefer16colors': 0,
        \ 'optionprefix': ''
        \ }
endf

fun! s:get_info(key)
  return s:info[a:key]
endf

fun! s:set_info(key, value)
  if !has_key(s:info, a:key)
    throw 'Unknown key: ' . a:key
  endif
  if a:key ==# 'terminalcolors'
    if type(a:value) != type([])
      throw 'FATAL: terminalcolors value must be a List (add_info)'
    endif
    if empty(a:value)
      let a:value = ['256']
    endif
    let s:info['prefer16colors'] = (a:value[0] == '16')
  else
    if type(a:value) != type('')
      throw "FATAL: key value must be a String (add_info)"
    endif
  endif
  let s:info[a:key] = a:value
  if a:key ==# 'shortname'
    if empty(a:value)
      throw 'Missing value for short name key'
    elseif len(a:value) > 24
      throw 'The short name must be at most 24 characters long'
    elseif a:value !~? '\m^\w\+$'
      throw 'The short name may contain only letters, numbers and underscore'
    endif
    if empty(s:info['optionprefix'])
      let s:info['optionprefix'] = s:info['shortname']
    endif
  elseif a:key ==# 'optionprefix'
    if a:value !~? '\m\w\+$'
      throw 'The option prefix may contain only letters, numbers and underscore'
    endif
  endif
endf

fun! s:fullname()
  return s:info['fullname']
endf

fun! s:shortname()
  return s:info['shortname']
endf

fun! s:author()
  return s:info['author']
endf

fun! s:maintainer()
  return s:info['maintainer']
endf

fun! s:description()
  return s:info['description']
endf

fun! s:website()
  return s:info['website']
endf

fun! s:license()
  return s:info['license']
endf

fun! s:optionprefix()
  return s:info['optionprefix']
endf

fun! s:use16option(g)
  return (a:g ? 'g:' : '').s:optionprefix().'_use16'
endf

fun! s:terminalcolors()
  return s:info['terminalcolors']
endf

fun! s:has16and256colors()
  return len(s:info['terminalcolors']) > 1
endf

fun! s:prefer16colors()
  return s:info['prefer16colors']
endf

fun! s:preferred_number_of_colors()
  return get(s:info['terminalcolors'], 0, 256)
endf

fun! s:secondary_number_of_colors()
  return get(s:info['terminalcolors'], 1, 16)
endf
" }}}
" Source {{{
fun! s:init_source()
  let s:source = [] " Keep the source lines here
endf

fun! s:add_source_line(line)
  call add(s:source, a:line)
endf

fun! s:print_source_as_comment()
  for l:line in s:source
    call s:put('" ' . l:line)
  endfor
endf
" }}}
" Background {{{
fun! s:init_current_background()
  let s:current_background = ''
  let s:uses_background = { 'dark': 0, 'light': 0 }
endf

fun! s:current_background()
  return empty(s:current_background) ? 'dark' : s:current_background
endf

fun! s:set_current_background(value)
  if a:value !=# 'dark' && a:value !=# 'light'
    throw 'Background can only be dark or light'
  endif
  if s:has_background(a:value)
    throw 'Cannot select ' . a:value . ' background more than once'
  endif
  let s:current_background = a:value
  let s:uses_background[s:current_background] = 1
endf

fun! s:background_undefined()
  return empty(s:current_background)
endf

fun! s:has_background(value)
  if a:value !=# 'dark' && a:value !=# 'light'
    throw 'FATAL: invalid background value (has_background)'
  endif
  return s:uses_background[a:value]
endf

fun! s:has_dark_and_light()
  return s:has_background('dark') && s:has_background('light')
endf
" }}}
" Palette {{{
" A palette is a Dictionary of color names and their definitions. Each
" definition consists of a GUI color value, a base-256 color value,
" a base-16 color value, and a distance between the GUI value and the
" base-256 value (in this order).
" Each background (dark, light) has its own palette.
fun! s:init_palette()
  let s:palette = {
        \ 'dark':  { 'none': ['NONE', 'NONE', 'NONE', 0.0],
        \            'fg':   ['fg',   'fg',   'fg',   0.0],
        \            'bg':   ['bg',   'bg',   'bg',   0.0]
        \          },
        \ 'light': { 'none': ['NONE', 'NONE', 'NONE', 0.0],
        \            'fg':   ['fg',   'fg',   'fg',   0.0],
        \            'bg':   ['bg',   'bg',   'bg',   0.0]
        \          }
        \ }
endf

fun! s:current_palette()
  return s:palette[s:current_background()]
endf

fun! s:palette(background)
  return s:palette[a:background]
endf

fun! s:color_exists(name, background)
  return has_key(s:palette[a:background], a:name)
endf

fun! s:get_color(name, background)
  return s:palette[a:background][a:name]
endf

fun! s:get_term_color(name, background, use16colors)
  return s:palette[a:background][a:name][a:use16colors ? 2 : 1]
endf

fun! s:get_gui_color(name, background)
  let l:col = s:palette[a:background][a:name][0]
  if match(l:col, '\s') > -1 " Quote RGB color name with spaces
    return "'" . l:col . "'"
  else
    return l:col
  endif
endf

" If the GUI value is a color name, convert it to a hex value
fun! s:rgbname2hex(color)
  return match(a:color, '^#') == - 1 ? s:get_rgb_colors(a:color) : a:color
endf

" name:    A color name
" gui:     GUI color name (e.g, indianred) or hex value (e.g., #c4fed6)
" base256: Base-256 color number or -1
" base16:  Base-16 color number or color name
"
" If base256 is -1, its value is inferred.
fun! s:add_color(name, gui, base256, base16)
  let l:gui = s:rgbname2hex(a:gui)
  " Find an approximation and/or a distance from the GUI value if none was provided
  if a:base256 < 0
    let l:approx_color = colortemplate#colorspace#approx(l:gui)
    let l:base256 = l:approx_color['index']
    let l:delta = l:approx_color['delta']
  else
    let l:base256 = a:base256
    let l:delta = (l:base256 >= 16 && l:base256 <= 255
          \ ? colortemplate#colorspace#hex_delta_e(l:gui, g:colortemplate#colorspace#xterm256_hexvalue(l:base256))
          \ : 0.0 / 0.0)
  endif
  if s:background_undefined()
    " Assume color definitions common to both backgrounds
    let s:palette['dark' ][a:name] = [a:gui, l:base256, a:base16, l:delta]
    let s:palette['light'][a:name] = [a:gui, l:base256, a:base16, l:delta]
  else
    " Assume color definition for the current background
    let s:palette[s:current_background()][a:name] = [a:gui, l:base256, a:base16, l:delta]
  endif
endf

fun! s:assert_valid_color_name(name)
  if a:name ==? 'none' || a:name ==? 'fg' || a:name ==? 'bg'
    throw "Colors 'none', 'fg', and 'bg' are reserved names and cannot be overridden"
  endif
  if s:color_exists(a:name, s:current_background())
    throw "Color already defined for " . s:current_background() . " background"
  endif
  " TODO: check that color name starts with alphabetic char
  return 1
endf

fun! s:interpolate(line, use16colors)
  let l:i = (a:use16colors ? 2 : 1)
  let l:line = substitute(a:line, '@term16\(\w\+\)', '\=s:current_palette()[submatch(1)][2]', 'g')
  let l:line = substitute(l:line, '@term256\(\w\+\)', '\=s:current_palette()[submatch(1)][1]', 'g')
  let l:line = substitute(l:line, '@term\(\w\+\)', '\=s:current_palette()[submatch(1)][l:i]', 'g')
  let l:line = substitute(l:line, '@gui\(\w\+\)',  '\=s:current_palette()[submatch(1)][0]', 'g')
  let l:line = substitute(l:line, '\(term[bf]g=\)@\(\w\+\)', '\=submatch(1).s:current_palette()[submatch(2)][l:i]', 'g')
  let l:line = substitute(l:line, '\(gui[bf]g=\|guisp=\)@\(\w\+\)', '\=submatch(1).s:current_palette()[submatch(2)][0]', 'g')
  let l:line = substitute(l:line, '@\(\a\+\)', '\=s:get_info(submatch(1))', 'g')
  return l:line
endf
" }}}
" {{{ Color pairs
" We keep track of pairs of colors used as a fg/bg combination.
" Used for highlighting critical pairs in the various debugging matrices.
fun! s:init_color_pairs()
  let s:fg_bg_pairs = { }
endf

fun! s:add_color_pair(fg, bg)
  let l:key = (a:fg < a:bg) ? a:fg.'/'.a:bg : a:bg.'/'.a:fg
  let s:fg_bg_pairs[l:key] = 1
endf

fun! s:has_color_pair(fg, bg)
  let l:key = (a:fg < a:bg) ? a:fg.'/'.a:bg : a:bg.'/'.a:fg
  return has_key(s:fg_bg_pairs, l:key)
endf
" }}}
" Highlight group {{{
let s:default_hi_groups = [
      \ 'ColorColumn',
      \ 'Comment',
      \ 'Conceal',
      \ 'Constant',
      \ 'Cursor',
      \ 'CursorColumn',
      \ 'CursorLine',
      \ 'CursorLineNr',
      \ 'DiffAdd',
      \ 'DiffChange',
      \ 'DiffDelete',
      \ 'DiffText',
      \ 'Directory',
      \ 'EndOfBuffer',
      \ 'Error',
      \ 'ErrorMsg',
      \ 'FoldColumn',
      \ 'Folded',
      \ 'Identifier',
      \ 'Ignore',
      \ 'IncSearch',
      \ 'LineNr',
      \ 'MatchParen',
      \ 'ModeMsg',
      \ 'MoreMsg',
      \ 'NonText',
      \ 'Normal',
      \ 'Pmenu',
      \ 'PmenuSbar',
      \ 'PmenuSel',
      \ 'PmenuThumb',
      \ 'PreProc',
      \ 'Question',
      \ 'QuickFixLine',
      \ 'Search',
      \ 'SignColumn',
      \ 'Special',
      \ 'SpecialKey',
      \ 'SpellBad',
      \ 'SpellCap',
      \ 'SpellLocal',
      \ 'SpellRare',
      \ 'Statement',
      \ 'StatusLine',
      \ 'StatusLineNC',
      \ 'StatusLineTerm',
      \ 'StatusLineTermNC',
      \ 'TabLine',
      \ 'TabLineFill',
      \ 'TabLineSel',
      \ 'Title',
      \ 'Todo',
      \ 'ToolbarButton',
      \ 'ToolbarLine',
      \ 'Type',
      \ 'Underlined',
      \ 'VertSplit',
      \ 'Visual',
      \ 'VisualNOS',
      \ 'WarningMsg',
      \ 'WildMenu'
      \ ]

fun! s:new_hi_group(name)
  return {
        \ 'name': a:name,
        \ 'fg': '',
        \ 'bg': '',
        \ 'sp': 'none',
        \ 'term': [],
        \ 'gui': []
        \}
endf

fun! s:hi_name(hg)
  return a:hg['name']
endf

fun! s:fg(hg)
  return a:hg['fg']
endf

fun! s:bg(hg)
  return a:hg['bg']
endf

fun! s:sp(hg)
  return a:hg['sp']
endf

fun! s:term_attr(hg)
  return a:hg['term']
endf

fun! s:gui_attr(hg)
  return a:hg['gui']
endf

fun! s:set_fg(hg, colorname)
  if a:colorname ==# 'bg'
    call s:add_warning(s:template.path, s:template.linenr, s:token.pos, "Using 'bg' may cause an error with transparent backgrounds")
  endif
  let a:hg['fg'] = a:colorname
endf

fun! s:set_bg(hg, colorname)
  if a:colorname ==# 'bg'
    call s:add_warning(s:template.path, s:template.linenr, s:token.pos, "Using 'bg' may cause an error with transparent backgrounds")
  endif
  let a:hg['bg'] = a:colorname
endf

fun! s:set_sp(hg, colorname)
  let a:hg['sp'] = a:colorname
endf

fun! s:has_term_attr(hg)
  return !empty(a:hg['term'])
endf

fun! s:has_gui_attr(hg)
  return !empty(a:hg['gui'])
endf

fun! s:add_term_attr(hg, attrlist)
  let a:hg['term'] += a:attrlist
  call uniq(sort(a:hg['term']))
endf

fun! s:add_gui_attr(hg, attrlist)
  let a:hg['gui'] += a:attrlist
  call uniq(sort(a:hg['gui']))
endf

fun! s:term_fg(hg, use16colors)
  return s:get_term_color(s:fg(a:hg), s:current_background(), a:use16colors)
endf

fun! s:term_bg(hg, use16colors)
  return s:get_term_color(s:bg(a:hg), s:current_background(), a:use16colors)
endf

fun! s:gui_fg(hg)
  return s:get_gui_color(s:fg(a:hg), s:current_background())
endf

fun! s:gui_bg(hg)
  return s:get_gui_color(s:bg(a:hg), s:current_background())
endf

fun! s:gui_sp(hg)
  return s:get_gui_color(s:sp(a:hg), s:current_background())
endf
" }}}
" Colorscheme {{{
fun! s:init_colorscheme()
  let s:colorscheme =  {
        \ '16'       : { 'dark': [], 'light': [], 'preamble': [] },
        \ '256'      : { 'dark': [], 'light': [], 'preamble': [] },
        \ 'outpath'  : '/',
        \ 'has_normal': { 'dark': 0, 'light': 0 }
        \ }
  let s:normal_colors = { 'dark': { 'fg': [], 'bg': [] }, 'light': { 'fg': [], 'bg': [] } }
endf

fun! s:has_normal_group(background)
  return s:colorscheme['has_normal'][a:background]
endf

fun! s:add_linked_group_def(src, tgt)
  for l:numcol in s:terminalcolors()
    call add(s:colorscheme[l:numcol][s:current_background()],
          \ 'hi! link ' . a:src . ' ' . a:tgt)
  endfor
endf

" Adds the current highlight group to the colorscheme
" This function must be called only after the background is defined
fun! s:add_highlight_group(hg)
  let l:bg = s:current_background()
  if s:hi_name(a:hg) ==# 'Normal' " Normal group needs special treatment
    if s:fg(a:hg) =~# '\m^\%(fg\|bg\)$' || s:bg(a:hg) =~# '\m^\%(fg\|bg\)$'
      throw "The colors for Normal cannot be 'fg' or 'bg'"
    endif
    if match(s:term_attr(a:hg), '\%(inv\|rev\)erse') > -1 || match(s:gui_attr(a:hg), '\%(inv\|rev\)erse') > -1
      throw "Do not use reverse mode for the Normal group"
    endif
    call add(s:normal_colors[l:bg]['fg'], s:fg(a:hg))
    call add(s:normal_colors[l:bg]['bg'], s:bg(a:hg))
    let s:colorscheme['has_normal'][l:bg] = 1
  endif
  call s:add_color_pair(s:fg(a:hg), s:bg(a:hg))
  for l:numcol in s:terminalcolors()
    let l:use16colors = (l:numcol == '16')
    call add(s:colorscheme[l:numcol][l:bg],
          \ join(['hi', s:hi_name(a:hg),
          \       'ctermfg='  . s:term_fg(a:hg, l:use16colors),
          \       'ctermbg='  . s:term_bg(a:hg, l:use16colors),
          \       'guifg='    . s:gui_fg(a:hg),
          \       'guibg='    . s:gui_bg(a:hg),
          \       'guisp='    . s:gui_sp(a:hg),
          \       'cterm=NONE'. (s:has_term_attr(a:hg) ? ',' . join(s:term_attr(a:hg), ',') : ''),
          \       'gui=NONE'  . (s:has_gui_attr(a:hg)  ? ',' . join(s:gui_attr(a:hg), ',')  : '')
          \ ])
          \ )
  endfor
endf

fun! s:print_colorscheme_preamble(use16colors)
  if !empty(s:colorscheme[a:use16colors ? '16' : '256']['preamble'])
    call append('$', s:colorscheme[a:use16colors ? '16' : '256']['preamble'])
    call s:put('')
  endif
endf

fun! s:print_colorscheme(background, use16colors)
  call append('$', s:colorscheme[a:use16colors ? '16' : '256'][a:background])
endf
" }}}
" Verbatim {{{
fun! s:init_verbatim()
  let s:is_verbatim_block = 0
endf

fun! s:start_verbatim()
  let s:is_verbatim_block = 1
endf

fun! s:stop_verbatim()
  let s:is_verbatim_block = 0
endf

fun! s:is_verbatim()
  return s:is_verbatim_block
endf

fun! s:add_verbatim_line(line)
  for l:numcol in s:terminalcolors()
    try
      let l:line = s:interpolate(a:line, l:numcol == '16')
    catch /.*/
      throw 'Undefined @ value'
    endtry
    if s:background_undefined()
      call add(s:colorscheme[l:numcol]['preamble'], l:line)
    else " Add to current background
      call add(s:colorscheme[l:numcol][s:current_background()], l:line)
    endif
  endfor
endf
" }}}
" Aux files {{{
fun! s:init_aux_files()
  let s:auxfiles = {}    " Mappings from paths to list of lines
  let s:auxfilepath = '' " Path to the currently processed aux file
  let s:is_auxfile = 0   " Set to 1 when processing an aux file
  let s:is_helpfile = 0  " Set to 1 when processing a documentation block
endf

" path: path of the aux file as specified in the template
fun! s:start_aux_file(path)
  if empty(a:path)
    throw 'Missing path'
  endif
  if !has_key(s:auxfiles, a:path)
    let s:auxfiles[a:path] = []
  endif
  let s:auxfilepath = a:path
  let s:is_auxfile = 1
endf

fun! s:stop_aux_file()
  let s:is_auxfile = 0
endf

fun! s:is_aux_file()
  return s:is_auxfile
endf

fun! s:start_help_file()
  let l:path = 'doc' . s:slash() . s:shortname() . '.txt'
  if !has_key(s:auxfiles, l:path)
    let s:auxfiles[l:path] = []
  endif
  let s:auxfilepath = l:path
  let s:is_helpfile = 1
endf

fun! s:is_help_file()
  return s:is_helpfile
endf

fun! s:stop_help_file()
  let s:is_helpfile = 0
endf

fun! s:add_line_to_aux_file(line)
  try " to interpolate variables
    let l:line = s:interpolate(a:line, s:prefer16colors())
  catch /.*/
    throw 'Undefined keyword'
  endtry
  call add(s:auxfiles[s:auxfilepath], l:line)
endf

fun! s:generate_aux_files(outdir, overwrite)
  if get (g:, 'colortemplate_no_aux_files', 0)
    return
  endif
  for l:path in keys(s:auxfiles)
    if match(l:path, '^doc' . s:slash()) > -1 " Help file
      if get(g:, 'colortemplate_no_doc', 0)
        continue
      endif
      silent bot new +setlocal\ tw=78\ noet\ ts=8\ sw=8\ ft=help\ norl
      call append(0, s:auxfiles[l:path])
      call s:predefined_help_text()
    else                                      " Other aux files
      if fnamemodify(l:path, ":e") ==# 'vim'
        silent bot new +setlocal\ ft=vim\ et\ ts=2\ sw=2\ norl\ nowrap
      else
        silent bot new +setlocal\ et\ ts=2\ sw=2\ norl\ nowrap
      endif
      call append(0, s:auxfiles[l:path])
    endif
    if !empty(a:outdir)
      call s:write_buffer(l:path, { 'dir': a:outdir }, a:overwrite)
    endif
  endfor
endf

fun! s:predefined_help_text()
  if s:has16and256colors()
    let l:default = s:prefer16colors()
    let l:pad = len(s:fullname()) + len(s:shortname())
    call s:put(              '=============================================================================='                            )
    call s:put(s:interpolate('@fullname other options' . repeat("\t", max([1,(40-l:pad)/8])) . '*@shortname-other-options*', 0)          )
    call s:put(              ''                                                                                                          )
    let l:pad = len(s:optionprefix())
    call s:put(repeat("\t", max([1,(68-l:pad)/8])) . '*'.s:use16option(1).'*'                                                            )
    call s:put(              'Set to ' . (1-l:default) . ' if you want to force the use of ' .s:secondary_number_of_colors() . ' colors.')
    call s:put(              '>'                                                                                                         )
    call s:put('	let '.s:use16option(1).' = ' . l:default                                                                               )
    call s:put(              '<'                                                                                                         )
  endif
  call s:put(              'vim:tw=78:ts=8:ft=help:norl:'                                                                                )
endf
" }}}
" Initialize state {{{
fun! s:init(work_dir)
  let g:colortemplate_exit_status = 0

  call setloclist(0, [], 'r') " Reset location list

  call s:init_working_directory(a:work_dir)
  call s:init_template()
  call s:init_info()
  call s:init_source()
  call s:init_current_background()
  call s:init_palette()
  call s:init_color_pairs()
  call s:init_colorscheme()
  call s:init_aux_files()
  call s:init_verbatim()
endf
" }}}
" }}} Internal state
" Colorscheme generation {{{
fun! s:assert_requirements()
  if empty(s:fullname())
    call s:add_generic_error('Please specify the full name of your color scheme')
  endif
  if empty(s:shortname())
    call s:add_generic_error('Please specify the short name of your color scheme')
  endif
  if empty(s:author())
    call s:add_generic_error('Please specify an author and the corresponding email')
  endif
  if empty(s:maintainer())
    call s:add_generic_error('Please specify a maintainer and the corresponding email')
  endif
  if empty(s:license())
    let s:info['license'] = 'Vim License (see `:help license`)'
  endif
  if s:has_dark_and_light() && !(s:has_normal_group('dark') && s:has_normal_group('light'))
    call s:add_generic_error('Please define the Normal highlight group for both dark and light background')
  elseif !s:has_normal_group(s:current_background())
    call s:add_generic_error('Please define the Normal highlight group')
  endif
endf

" Checks to be performed on the generated colorscheme code
fun! s:postcheck()
  if get(g:, 'colortemplate_no_warnings', 0)
    return
  endif
  call cursor(1,1)
  " Check for missing highlight groups
  for l:hg in s:default_hi_groups
    if !search('\%(hi\|hi! link\) \<'.l:hg.'\>', 'nW')
      call s:add_generic_warning('No definition for ' . l:hg . ' highlight group')
    endif
  endfor
  " Were debugPC and debugBreakpoint defined? (They shouldn't: see :h colortemplate-best-practices)
  for l:hg in ['debugPC', 'debugBreakpoint']
    if search('\%(hi\|hi! link\) \<'.l:hg.'\>', 'nW')
      call s:add_generic_warning('A colorscheme should not define plugin-specific highlight groups: ' . l:hg )
    endif
  endfor
  " Is g:terminal_ansi_colors defined?
  if !search('g:terminal_ansi_colors','nW')
    call s:add_generic_warning('g:terminal_ansi_colors is not defined (see :help g:terminal_ansi_colors)')
  endif
  if !empty(getloclist(0))
    lopen
  endif
endf

fun! s:print_header()
  if s:has16and256colors()
    let l:default = s:prefer16colors() ? string(s:prefer16colors()) : '&t_Co < 256'
    let l:limit = "(get(g:, '" . s:use16option(0) . "', " . l:default . ") ? 16 : 256)"
  else
    let l:limit = s:preferred_number_of_colors()
  endif
  call setline(1, '" Name:         ' . s:fullname()                                                   )
  if !empty(s:description())
    call s:put(   '" Description:  ' . s:description()                                                )
  endif
  call s:put  (   '" Author:       ' . s:author()                                                     )
  call s:put  (   '" Maintainer:   ' . s:maintainer()                                                 )
  if !empty(s:website())
    call s:put(   '" Website:      ' . s:website()                                                    )
  endif
  call s:put  (   '" License:      ' . s:license()                                                    )
  call s:put  (   '" Last Updated: ' . strftime("%c")                                                 )
  call s:put  (   ''                                                                                  )
  call s:put  (   "if !(has('termguicolors') && &termguicolors) && !has('gui_running')"               )
  call s:put  (   "      \\ && (!exists('&t_Co') || &t_Co < " . l:limit . ')'                         )
  call s:put  (   "  echoerr '[" . s:fullname() . "] There are not enough colors.'"                   )
  call s:put  (   '  finish'                                                                          )
  call s:put  (   'endif'                                                                             )
  call s:put  (   ''                                                                                  )
  if !s:has_dark_and_light()
    call s:put(   'set background=' . s:current_background()                                          )
    call s:put(   ''                                                                                  )
  endif
  call s:put  (   'hi clear'                                                                          )
  call s:put  (   "if exists('syntax_on')"                                                            )
  call s:put  (   '  syntax reset'                                                                    )
  call s:put  (   'endif'                                                                             )
  call s:put  (   ''                                                                                  )
  call s:put  (   "let g:colors_name = '" . s:shortname() . "'"                                       )
  call s:put  (   ''                                                                                  )
endf

if has('nvim')
  fun! s:isnan(x)
    return printf("%f", a:x) ==# 'nan'
  endf
else
  fun! s:isnan(x)
    return isnan(a:x)
  endf
endif

" Print details about the color palette for the specified background as comments
fun! s:print_similarity_table(bg)
  call s:put('{{{ Color Similarity Table (' . a:bg . ' background)')
  let l:palette = s:palette(a:bg)
  " Find maximum length of color names (used for formatting)
  let l:len = max(map(copy(l:palette), { k,_ -> len(k)}))
  " Sort colors by increasing delta
  let l:color_names = keys(l:palette)
  call sort(l:color_names, { c1,c2 ->
        \ s:isnan(l:palette[c1][3])
        \      ? (s:isnan(l:palette[c2][3]) ? 0 : 1)
        \      : (s:isnan(l:palette[c2][3]) ? -1 : (l:palette[c1][3] < l:palette[c2][3] ? -1 : (l:palette[c1][3] > l:palette[c2][3] ? 1 : 0)))
        \ })
  for l:color in l:color_names
    if l:color =~? '\m^\%(fg\|bg\|none\)$'
      continue
    endif
    let l:colgui = s:rgbname2hex(l:palette[l:color][0])
    let l:col256 = l:palette[l:color][1]
    let l:delta  = l:palette[l:color][3]
    let l:rgbgui = colortemplate#colorspace#hex2rgb(l:colgui)
    if l:col256 > 15 && l:col256 < 256
      let l:hex256 = g:colortemplate#colorspace#xterm256[l:col256 - 16]
      let l:rgb256 = colortemplate#colorspace#hex2rgb(l:hex256)
      let l:def256 = l:hex256 . printf('/rgb(%3d,%3d,%3d)', l:rgb256[0], l:rgb256[1], l:rgb256[2])
    else
      let l:def256 = repeat(' ', 24)
    endif
    let l:fmt = '%'.l:len.'s: GUI=%s/rgb(%3d,%3d,%3d)  Term=%3d %s  [delta=%f]'
    call s:put(printf(l:fmt, l:color, l:colgui, l:rgbgui[0], l:rgbgui[1], l:rgbgui[2], l:col256, l:def256, l:delta))
  endfor
  call s:put('}}} Color Similarity Table')
endf

" Adds the contrast matrix for the specified background to the current buffer.
fun! s:print_contrast_matrix(bg)
  let [l:colors, l:labels] = [{'gui': [], 'term': []}, []]
  for l:key in sort(keys(s:palette(a:bg)))
    if l:key != 'fg' && l:key != 'bg' && l:key != 'none'
      let l:val = s:palette(a:bg)[l:key]
      call add(l:labels, l:key)
      call add(l:colors['gui'], l:val[0])
      call add(l:colors['term'], colortemplate#colorspace#xterm256_hexvalue(l:val[1]))
    endif
  endfor
  call s:put('{{{ Contrast Ratio Matrix (' . a:bg . ' background)')
  call s:put('')
  call s:put('Pairs of colors with contrast ≥4.5 can be safely used as a fg/bg combo')
  call s:put('')
  call s:put("█ Not W3C conforming   █ Not ISO-9241-3 conforming")
  call s:put('')
  for l:type in ['gui', 'term']
    let l:M = colortemplate#colorspace#contrast_matrix(l:colors[l:type])
    call s:put('{{{ '.(l:type ==# 'gui' ? 'GUI (exact)' : 'Terminal (approximate)'))
    call s:put("\t".join(l:labels, "\t"))
    for l:i in range(len(l:M))
      call s:put(l:labels[l:i]."\t".join(map(l:M[l:i], { j,v -> j ==# l:i ? '' : printf("%5.02f", v) }), "\t")."\t".l:labels[l:i])
    endfor
    call s:put("\t".join(l:labels, "\t"))
    call s:put('}}}')
  endfor
  call s:put('}}} Contrast Ratio Matrix')
endf

fun! s:print_color_difference_matrix(bg)
  let [l:colors, l:labels] = [{'gui': [], 'term': []}, []]
  for l:key in sort(keys(s:palette(a:bg)))
    if l:key != 'fg' && l:key != 'bg' && l:key != 'none'
      let l:val = s:palette(a:bg)[l:key]
      call add(l:labels, l:key)
      call add(l:colors['gui'], l:val[0])
      call add(l:colors['term'], colortemplate#colorspace#xterm256_hexvalue(l:val[1]))
    endif
  endfor
  call s:put('{{{ Color Difference Matrix (' . a:bg . ' background)')
  call s:put('')
  call s:put('Pairs of colors whose color difference is ≥500 can be safely used as a fg/bg combo')
  call s:put('')
  for l:type in ['gui', 'term']
    let l:M = colortemplate#colorspace#coldiff_matrix(l:colors[l:type])
    call s:put('{{{ '.(l:type ==# 'gui' ? 'GUI (exact)' : 'Terminal (approximate)'))
    call s:put("\t".join(l:labels, "\t"))
    for l:i in range(len(l:M))
      call s:put(l:labels[l:i]."\t".join(map(l:M[l:i], { j,v -> j ==# l:i ? '' : printf("%5.01f", v) }), "\t")."\t".l:labels[l:i])
    endfor
    call s:put("\t".join(l:labels, "\t"))
    call s:put('}}}')
  endfor
  call s:put('}}} Color Difference Matrix')
endf

fun! s:print_brightness_difference_matrix(bg)
  let [l:colors, l:labels] = [{'gui': [], 'term': []}, []]
  for l:key in sort(keys(s:palette(a:bg)))
    if l:key != 'fg' && l:key != 'bg' && l:key != 'none'
      let l:val = s:palette(a:bg)[l:key]
      call add(l:labels, l:key)
      call add(l:colors['gui'], l:val[0])
      call add(l:colors['term'], colortemplate#colorspace#xterm256_hexvalue(l:val[1]))
    endif
  endfor
  call s:put('{{{ Brightness Difference Matrix (' . a:bg . ' background)')
  call s:put('')
  call s:put('Pairs of colors whose brightness difference is ≥125 can be safely used as a fg/bg combo')
  call s:put('')
  for l:type in ['gui', 'term']
    let l:M = colortemplate#colorspace#brightness_diff_matrix(l:colors[l:type])
    call s:put('{{{ '.(l:type ==# 'gui' ? 'GUI (exact)' : 'Terminal (approximate)'))
    call s:put("\t".join(l:labels, "\t"))
    for l:i in range(len(l:M))
      call s:put(l:labels[l:i]."\t".join(map(l:M[l:i], { j,v -> j ==# l:i ? '' : printf("%5.01f", v) }), "\t")."\t".l:labels[l:i])
    endfor
    call s:put("\t".join(l:labels, "\t"))
    call s:put('}}}')
  endfor
  call s:put('}}} Brightness Difference Matrix')
endf

fun! s:print_color_info()
  silent tabnew +setlocal\ buftype=nofile\ foldmethod=marker\ noet\ norl\ noswf\ nowrap
  set ft=colortemplate-info
  " Find maximum length of color names (used for formatting)
  let l:labels = keys(s:palette('dark')) + keys(s:palette('light'))
  let l:tw = 2 + max(map(l:labels, { _,v -> len(v)}))
  execute 'setlocal tabstop='.l:tw 'shiftwidth='.l:tw

  call append(0, 'Color information about ' . s:fullname())
  let l:backgrounds = s:has_dark_and_light() ? ['dark', 'light'] : [s:current_background()]
  for l:bg in l:backgrounds
    if s:has_dark_and_light()
      call s:put('{{{ '.l:bg.' background')
      call s:put('')
    endif
    call s:print_similarity_table(l:bg)
    call s:put('')
    call s:print_contrast_matrix(l:bg)
    call s:put('')
    call s:print_brightness_difference_matrix(l:bg)
    call s:put('')
    call s:print_color_difference_matrix(l:bg)
    call s:put('')
    if s:has_dark_and_light()
      call s:put('}}}')
    endif
  endfor
endf

fun! s:generate_colorscheme(outdir, overwrite)
  silent tabnew +setlocal\ ft=vim\ et\ ts=2\ sw=2\ norl\ nowrap
  call s:print_header()
  for l:numcol in s:terminalcolors()
    let l:use16colors = (l:numcol == 16)
    if s:has16and256colors() && l:numcol == s:preferred_number_of_colors()
      call s:put('" ' . l:numcol . '-color variant')
      let l:not = s:prefer16colors() ? '' : '!'
      let l:default = s:preferred_number_of_colors() == 256 ? '&t_Co < 256' : s:prefer16colors()
      call s:put("if " .l:not."get(g:, '" . s:use16option(0) . "', " . l:default .")")
    endif
    call s:print_colorscheme_preamble(l:use16colors)
    if s:has_dark_and_light()
      call s:put("if &background ==# 'dark'")
      call s:print_colorscheme('dark', l:use16colors)
      call s:put("finish")
      call s:put("endif")
      call s:put('')
      call s:print_colorscheme('light', l:use16colors)
    else " One background
      call s:print_colorscheme(s:current_background(), l:use16colors)
    end
    if s:has16and256colors() && l:numcol == s:preferred_number_of_colors()
      call s:put('finish')
      call s:put('endif')
      call s:put('')
      call s:put('" ' . s:secondary_number_of_colors() . '-color variant')
    endif
  endfor
  call s:put('finish')
  call s:put('')
  call s:print_source_as_comment()
  " Reindent
  norm gg=G
  if !empty(a:outdir)
    call s:write_buffer(
          \ a:outdir . s:slash() . 'colors' . s:slash() . s:shortname() . '.vim',
          \ { 'dir': a:outdir },
          \ a:overwrite)
  endif
  call s:postcheck()
endf
" }}}
" Parser {{{
fun! s:parse_verbatim_line()
  if s:template.getl() =~? '\m^\s*endverbatim'
    call s:stop_verbatim()
    if s:template.getl() !~? '\m^\s*endverbatim\s*$'
      throw "Extra characters after 'endverbatim'"
    endif
  else
    call s:add_verbatim_line(s:template.getl())
  endif
endf

fun! s:parse_help_line()
  if s:template.getl() =~? '\m^\s*enddocumentation'
    call s:stop_help_file()
    if s:template.getl() !~? '\m^\s*enddocumentation\s*$'
      throw "Extra characters after 'enddocumentation'"
    endif
  else
    call s:add_line_to_aux_file(s:template.getl())
  endif
endf

fun! s:parse_auxfile_line()
  if s:template.getl() =~? '\m^\s*endauxfile'
    call s:stop_aux_file()
    if s:template.getl() !~? '\m^\s*endauxfile\s*$'
      throw "Extra characters after 'endauxfile'"
    endif
  else
    call s:add_line_to_aux_file(s:template.getl())
  endif
endf

fun! s:parse_line()
  if s:token.next().kind ==# 'EOL' " Empty line
    return
  elseif s:token.kind ==# 'COMMENT'
    return s:parse_comment()
  elseif s:token.kind ==# 'WORD'
    if s:token.value ==? 'verbatim'
      call s:start_verbatim()
      if s:token.next().kind !=# 'EOL'
        throw "Extra characters after 'verbatim'"
      endif
    elseif s:token.value ==? 'auxfile'
      call s:start_aux_file(s:interpolate(matchstr(s:template.getl(), '^\s*auxfile\s\+\zs.*'), s:prefer16colors()))
    elseif s:token.value ==? 'documentation'
      call s:start_help_file()
    elseif s:template.getl() =~? '\m:' " Look ahead
      call s:parse_key_value_pair()
    else
      call s:parse_hi_group_def()
    endif
  else
    throw 'Unexpected token at start of line'
  endif
endf

fun! s:parse_comment()
  " Nothing to do here
endf

fun! s:parse_key_value_pair()
  if s:token.value ==? 'palette'
    call s:parse_palette_spec()
  elseif s:token.value ==? 'color'
    call s:add_source_line(s:template.getl())
    call s:parse_color_def()
  else " Generic key-value pair
    let l:key_tokens = [s:token.value]
    while s:token.next().kind !=# ':'
      if s:token.kind !=# 'WORD' || s:token.value !~? '\m^\a\+$'
        throw 'Only letters from a to z are allowed in keys'
      endif
      call add(l:key_tokens, s:token.value)
    endwhile
    let l:key = tolower(join(l:key_tokens, ''))
    let l:val = matchstr(s:template.getl(), '\s*\zs.*$', s:token.pos)
    if l:key ==# 'background'
      call s:add_source_line(s:template.getl())
      if l:val =~? '\m^dark\s*$'
        call s:set_current_background('dark')
      elseif l:val =~? '\m^light\s*$'
        call s:set_current_background('light')
      else
        throw 'Background can only be dark or light.'
      endif
    elseif l:key ==# 'terminalcolors'
      let l:numcol = uniq(map(split(l:val, '\s*,\s*'), { _,v -> string(str2nr(v)) }))
      if !empty(l:numcol)
        if len(l:numcol) > 2 || (l:numcol[0] != 16 && l:numcol[0] != 256) ||
              \ (len(l:numcol) == 2 && l:numcol[1] != 16 && l:numcol[1] != 256)
          throw 'Only 16 and/or 256 colors can be specified.'
        else
          call s:set_info('terminalcolors', l:numcol)
        endif
      endif
    elseif l:key ==# 'include'
      call s:template.include(l:val)
    else
      call s:set_info(l:key, l:val)
    endif
  endif
endf

fun! s:parse_palette_spec()
  if s:token.next().kind !=# ':'
    throw 'Expected colon after Palette keyword'
  endif
  if s:token.next().kind !=# 'WORD'
    throw 'Palette name expected'
  endif
  let l:palette_name = s:token.value
  let l:params = []
  while s:token.next().kind !=# 'EOL' && s:token.kind !=# 'COMMENT'
    if s:token.kind !=# 'WORD' && s:token.kind !=# 'NUM'
      throw 'Only number or word allowed here'
    endif
    call add(l:params, s:token.value)
  endwhile
  call s:template.include_palette(l:palette_name, l:params)
endf

fun! s:parse_color_def()
  if s:token.next().kind !=# ':'
    throw 'Expected colon after Color keyword'
  endif
  let l:colorname = s:parse_color_name()
  let l:col_gui   = s:parse_gui_value()
  let l:col_256   = s:parse_base_256_value(l:col_gui)
  let l:col_16    = s:parse_base_16_value()
  call s:add_color(l:colorname, l:col_gui, l:col_256, l:col_16)
endf

fun! s:parse_color_name()
  if s:token.next().kind !=# 'WORD'
    throw 'Invalid color name'
  endif
  call s:assert_valid_color_name(s:token.value)
  return s:token.value
endf

fun! s:parse_gui_value()
  if s:token.next().kind ==# 'HEX'
    return s:token.value
  elseif s:token.kind !=# 'WORD'
    throw 'Invalid GUI color value'
  elseif s:token.value ==? 'rgb'
    return s:parse_rgb_value()
  else " Assume RGB name from $VIMRUNTIME/rgb.txt
    let l:rgb_name = s:token.value
    while s:token.peek().kind ==# 'WORD'
      let l:rgb_name .= ' ' . s:token.next().value
    endwhile
    if !has_key(s:get_rgb_colors(), tolower(l:rgb_name))
      throw 'Unknown RGB color name'
    else
      return l:rgb_name
    endif
  endif
endf

fun! s:parse_rgb_value()
  if s:token.next().kind !=# '('
    throw 'Missing opening parenthesis'
  endif
  if s:token.next().kind !=# 'NUM'
    throw 'Expected number'
  endif
  let l:red = str2nr(s:token.value)
  if l:red > 255 || l:red < 0
    throw "RGB red component value is out of range"
  endif
  if s:token.next().kind !=# ','
    throw 'Missing comma'
  endif
  if s:token.next().kind !=# 'NUM'
    throw 'Expected number'
  endif
  let l:green = str2nr(s:token.value)
  if l:green > 255 || l:green < 0
    throw "RGB green component value is out of range"
  endif
  if s:token.next().kind !=# ','
    throw 'Missing comma'
  endif
  if s:token.next().kind !=# 'NUM'
    throw 'Expected number'
  endif
  let l:blue = str2nr(s:token.value)
  if l:blue > 255 || l:blue < 0
    throw "RGB blue component value is out of range"
  endif
  if s:token.next().kind !=# ')'
    throw 'Missing closing parenthesis'
  endif
  return colortemplate#colorspace#rgb2hex(l:red, l:green, l:blue)
endf

fun! s:parse_base_256_value(guicolor)
  if s:token.next().kind ==# '~' " Find best approximation automatically
    return -1
  elseif s:token.kind ==# 'NUM'
    let l:val = str2nr(s:token.value)
    if l:val > 255 || l:val < 0
      throw "Base-256 color value is out of range"
    endif
    return l:val
  endif
  throw 'Expected base-256 number or tilde'
endf

fun! s:parse_base_16_value()
  if s:token.next().kind ==# 'EOL' || s:token.kind ==# 'COMMENT'
    return 'Black' " Just a placeholder: we assume that base-16 colors are not used
  elseif s:token.kind ==# 'NUM'
    let l:val = str2nr(s:token.value)
    if l:val > 15 || l:val < 0
      throw 'Base-16 color value is out of range'
    endif
    return l:val
  elseif s:token.kind ==# 'WORD'
    return s:token.value
  else
    throw 'Expected base-16 number or color name'
  endif
endf

fun! s:parse_hi_group_def()
  call s:add_source_line(s:template.getl())

  if s:template.getl() =~# '\m->' " Look ahead
    return s:parse_linked_group_def()
  endif

  " Base highlight group definition
  let l:hg = s:new_hi_group(s:token.value)
  " Foreground color
  if s:token.next().kind !=# 'WORD'
    throw 'Foreground color name missing'
  endif
  call s:set_fg(l:hg, s:parse_color_value())
  " Background color
  if s:token.next().kind !=# 'WORD'
    throw 'Background color name missing'
  endif
  call s:set_bg(l:hg, s:parse_color_value())

  let l:hg = s:parse_attributes(l:hg)

  call s:add_highlight_group(l:hg)
endf

fun! s:parse_color_value()
  let l:color = s:token.value
  if !s:color_exists(l:color, s:current_background())
    throw 'Undefined color name: ' . l:color
  endif
  return l:color
endf

fun! s:parse_attributes(hg)
  while s:token.next().kind !=# 'EOL' && s:token.kind !=# 'COMMENT'
    if s:token.kind !=# 'WORD'
      throw 'Invalid attributes'
    endif

    if s:token.value ==? 't' || s:token.value ==? 'term'
      if s:token.next().kind !=# '='
        throw "Expected = symbol after 'term'"
      endif
      call s:token.next()
      call s:add_term_attr(a:hg, s:parse_attr_list())
    elseif s:token.value ==? 'g' || s:token.value ==? 'gui'
      if s:token.next().kind !=# '='
        throw "Expected = symbol after 'gui'"
      endif
      call s:token.next()
      call s:add_gui_attr(a:hg, s:parse_attr_list())
    elseif s:token.value ==? 's' || s:token.value ==? 'guisp'
      if s:token.next().kind !=# '='
        throw "Expected = symbol after 'guisp'"
      endif
      call s:token.next()
      call s:set_sp(a:hg, s:parse_color_value())
    else
      let l:attrlist = s:parse_attr_list()
      call s:add_term_attr(a:hg, l:attrlist)
      call s:add_gui_attr(a:hg, l:attrlist)
    endif
  endwhile

  return a:hg
endf

fun! s:parse_attr_list()
  if s:token.kind !=# 'WORD'
    throw 'Invalid attribute'
  endif
  let l:attrlist = [s:token.value]
  while s:token.peek().kind ==# ','
    if s:token.next().next().kind !=# 'WORD'
      throw 'Invalid attribute list'
    endif
    call add(l:attrlist, s:token.value)
  endwhile
  return l:attrlist
endf

fun! s:parse_linked_group_def()
  let l:source_group = s:token.value
  if s:token.next().kind !=# '-' || s:token.next().kind !=# '>'
    throw 'Expected ->'
  endif
  if s:token.next().kind !=# 'WORD'
    throw 'Expected highlight group name'
  endif
  call s:add_linked_group_def(l:source_group, s:token.value)
endf
" }}} Parser
" Public interface {{{
fun! colortemplate#parse(filename) abort
  call s:init(fnamemodify(a:filename, ":h"))
  call s:template.load(a:filename)
  while s:template.next_line()
    call s:token.reset()
    try
      if s:is_verbatim()
        call s:parse_verbatim_line()
      elseif s:is_aux_file()
        call s:parse_auxfile_line()
      elseif s:is_help_file()
        call s:parse_help_line()
      else
        call s:parse_line()
      endif
    catch /^FATAL/
      let [l:path, l:line] = s:template.curr_pos()
      call s:add_error(l:path, l:line, s:token.spos + 1, v:exception)
      throw 'Parse error'
    catch /.*/
      let [l:path, l:line] = s:template.curr_pos()
      call s:add_error(l:path, l:line, s:token.spos + 1, v:exception)
    endtry
  endwhile

  call s:assert_requirements()

  if !empty(getloclist(0))
    lopen
    if !empty(filter(getloclist(0), { i,v -> v['type'] !=# 'W' }))
      throw 'Parse error'
    endif
  else
    lclose
  endif
endf

" a:1 is the optional path to an output directory
" a:2 is ! when files should be overridden
fun! colortemplate#make(...)
  let l:outdir = (a:0 > 0 && !empty(a:1) ? simplify(fnamemodify(a:1, ':p')) : '')
  let l:overwrite = (a:0 > 1 ? (a:2 == '!') : 0)
  if !empty(l:outdir)
    if !isdirectory(l:outdir)
      call s:print_error_msg("Path is not a directory: " . l:outdir, 0)
      let g:colortemplate_exit_status = 1
      return
    elseif filewritable(l:outdir) != 2
      call s:print_error_msg("Directory is not writable: " . l:outdir, 0)
      let g:colortemplate_exit_status = 1
      return
    endif
  endif

  try
    call colortemplate#parse(expand('%:p'))
  catch /Parse error/
    let g:colortemplate_exit_status = 1
    lopen
    return
  catch /.*/
    echoerr '[Colortemplate] Unexpected error: ' v:exception
    let g:colortemplate_exit_status = 1
    return
  endtry

  try
    call s:generate_colorscheme(l:outdir, l:overwrite)
    call s:generate_aux_files(l:outdir, l:overwrite)
  catch /.*/
    call s:print_error_msg(v:exception, 0)
    return
  endtry

  " Stats tab
  if !get(g:, 'colortemplate_no_stat', 0)
    call s:print_color_info()
  endif

  redraw
  echo "\r"
  echomsg '[Colortemplate] Colorscheme successfully created!'
endf

" Format a dictionary of color name/value pairs in Colortemplate format
fun! colortemplate#format_palette(colors)
  let l:template = []
  for [l:name, l:value] in items(a:colors)
    call add(l:template, printf('Color: %s %s ~', l:name, l:value))
  endfor
  return l:template
endf
" }}} Public interface
