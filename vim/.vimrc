"" Theme
syntax enable                             " Enable syntax processing
set background=dark                       " Dark background for the theme
let g:solarized_termcolors=256            " Degraded 256 colorscheme
colorscheme solarized                     " Solarized colorscheme

"" General
set number                                " Show line numbers
set linebreak                             " Break lines at word (requires Wrap lines)
set showbreak=+++                         " Wrap-broken line prefix
set textwidth=100                         " Line wrap (number of cols)
set showmatch                             " Highlight matching brace
set visualbell                            " Use visual bell (no beeping)

set hlsearch                              " Highlight all search results
set smartcase                             " Enable smart-case search
set ignorecase                            " Always case-insensitive
set incsearch                             " Searches for strings incrementally

set autoindent                            " Auto-indent new lines
set expandtab                             " Use spaces instead of tabs
set shiftwidth=4                          " Number of auto-indent spaces
set smartindent                           " Enable smart-indent
set smarttab                              " Enable smart-tabs
set tabstop=4                             " Number of spaces per Tab
set softtabstop=4                         " Number of spaces per Tab when editing
set showcmd                               " Show command in bottom bar
set cursorline                            " Highlight current line
set wildmenu                              " Visual autocomplete for command menu

"" Advanced
set ruler                                 " Show row and column ruler information
set undolevels=1000                       " Number of undo levels
set backspace=indent,eol,start            " Backspace behaviour


"" Key maps
inoremap jk <esc>l
