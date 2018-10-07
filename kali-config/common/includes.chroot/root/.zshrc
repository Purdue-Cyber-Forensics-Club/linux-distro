config_help=false
config_benchmark=false

zshrc_low_power=false

zshrc_benchmark_start() {
    if ( $config_benchmark ); then
        zmodload zsh/zprof
    fi
}

zshrc_benchmark_stop() {
    if ( $config_benchmark ); then
        zprof > "${HOME}/.zprof.log"
        echo "ZSH profiling log saved to ${HOME}/.zprof.log"
    fi
}

zshrc_detect_term_colors() {
    # Dynamically set term to the right prefix.
    case $TERM in
        *linux*)
            zshrc_low_power=true
            echo "Low power mode enabled."
            ;;
        *vt100*)
            zshrc_low_power=true
            echo "Low power mode enabled."
            ;;
    esac

    #case $TERM in
        #konsole|xterm|screen|tmux|rxvt-unicode)
            #export TERM="$TERM-256color";;
    #esac
}

zshrc_setup_completion() {
    zstyle ':completion:*' auto-description '\ %d'

    # Removed: _list
    # Was ruining menucomplete
    zstyle ':completion:*' completer _expand _complete _ignored _match _correct _approximate _prefix
    zstyle ':completion:*' format '> Completing %d ...'
    zstyle ':completion:*' insert-unambiguous true
    zstyle ":completion:*:default" list-colors ${(s.:.)LS_COLORS}
    zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
    zstyle ':completion:*' matcher-list '' 'm:{[:lower:]}={[:upper:]}' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'l:|=* r:|=*'
    zstyle ':completion:*' max-errors 4
    zstyle ':completion:*' menu select=1
    zstyle ':completion:*' original true
    zstyle ':completion:*' preserve-prefix '//[^/]##/'
    zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
    zstyle ':completion:*' squeeze-slashes true
    zstyle ':completion:*' verbose true
    zstyle ':completion:*' rehash true
    zstyle :compinstall filename '/home/max/.zshrc'
}

zshrc_autoload() {
    autoload -Uz compinit
    compinit

    autoload -Uz promptinit
    promptinit

    autoload -Uz edit-command-line

    if ( $config_help ); then
        autoload -Uz run-help
        alias help=run-help

        autoload -Uz run-help-git
        autoload -Uz run-help-ip
        autoload -Uz run-help-openssl
        autoload -Uz run-help-p4
        autoload -Uz run-help-sudo
        autoload -Uz run-help-svk
        autoload -Uz run-help-svn
    fi
}

zshrc_source() {
    if [[ -d "$HOME/.neovim-studio/" ]] && [[ -z "${NEOVIM_STUDIO_PROFILE_SOURCED}" ]]; then
        source "$HOME/.profile"

        if [[ -z "${NEOVIM_STUDIO_PROFILE_SOURCED}" ]]; then
            # Doesn't exist within the profile.
            export NEOVIM_STUDIO_PROFILE_SOURCED=1
        fi
    fi

    if [ -f "${HOME}/.zplug/repos/junegunn/fzf/shell/key-bindings.zsh" ]; then
        # fzf searches for this, so leave it as it is.
        [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    fi
}

zshrc_set_options() {
    HISTFILE=~/.histfile
    HISTSIZE=1000
    SAVEHIST=10000

    # man zshoptions
    setopt correct
    #setopt correctall
    setopt clobber
    setopt interactivecomments
    setopt nomatch
    setopt extendedglob
    setopt listpacked
    setopt menucomplete
    setopt sharehistory
    setopt appendhistory
    setopt autocd
    setopt beep
    setopt notify

    # Vim Bindings
    bindkey -v
    bindkey '^a' beginning-of-line
    bindkey '^e' end-of-line

    bindkey '^P' up-history
    bindkey '^N' down-history
    bindkey '^h' backward-delete-char
    bindkey '^w' backward-kill-word
    bindkey '^r' history-incremental-search-backward
    bindkey '^[[Z' reverse-menu-complete

    zle-keymap-select () {
        zle reset-prompt
        zle -R
    }

    zle -N zle-keymap-select

    export KEYTIMEOUT=1
}

zshrc_powerlevel9k() {
    POWERLEVEL9K_MODE="nerdfont-complete"
    POWERLEVEL9K_PROMPT_ON_NEWLINE=false
    #POWERLEVEL9K_RPROMPT_ON_NEWLINE=false

    # Intriguing elements
    # detect_virt ssh vi_mode background_jobs load ram icons_test
    #
    POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(time context ip newline os_icon dir dir_writable)
    POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(background_jobs command_execution_time)

    POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=""
    POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX=""
    POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX=""

    POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=5
    POWERLEVEL9K_VI_INSERT_MODE_STRING="I"
    POWERLEVEL9K_VI_COMMAND_MODE_STRING="N"

    POWERLEVEL9K_SHORTEN_DIR_LENGTH=3
    POWERLEVEL9K_SHORTEN_DELIMITER=""
    POWERLEVEL9K_SHORTEN_STRATEGY="truncate_from_right"

    # Colors
    POWERLEVEL9K_COLOR_SCHEME="dark"
    PL9K_TEXT_COLOR="232"
    PL9K_TEXT_INVERSE_COLOR="255"
    PL9K_BLUE="033"
    PL9K_GREEN="046"
    PL9K_RED="196"
    PL9K_ORANGE="214"

    POWERLEVEL9K_TIME_BACKGROUND="255"
    POWERLEVEL9K_TIME_FOREGROUND="${PL9K_TEXT_COLOR}"

    POWERLEVEL9K_DETECT_VIRT_BACKGROUND="249"
    POWERLEVEL9K_DETECT_VIRT_FOREGROUND="${PL9K_TEXT_COLOR}"

    POWERLEVEL9K_CONTEXT_DEFAULT_BACKGROUND="246"
    POWERLEVEL9K_CONTEXT_DEFAULT_FOREGROUND="${PL9K_TEXT_COLOR}"
    POWERLEVEL9K_CONTEXT_SUDO_BACKGROUND="246"
    POWERLEVEL9K_CONTEXT_SUDO_FOREGROUND="${PL9K_TEXT_COLOR}"
    POWERLEVEL9K_CONTEXT_REMOTE_BACKGROUND="246"
    POWERLEVEL9K_CONTEXT_REMOTE_FOREGROUND="${PL9K_TEXT_COLOR}"
    POWERLEVEL9K_CONTEXT_REMOTE_SUDO_BACKGROUND="246"
    POWERLEVEL9K_CONTEXT_REMOTE_SUDO_FOREGROUND="${PL9K_TEXT_COLOR}"
    POWERLEVEL9K_CONTEXT_ROOT_BACKGROUND="246"
    POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND="${PL9K_RED}"

    POWERLEVEL9K_IP_BACKGROUND="243"
    POWERLEVEL9K_IP_FOREGROUND="${PL9K_TEXT_COLOR}"

    POWERLEVEL9K_LOAD_NORMAL_BACKGROUND="240"
    POWERLEVEL9K_LOAD_NORMAL_FOREGROUND="${PL9K_TEXT_COLOR}"
    POWERLEVEL9K_LOAD_WARNING_BACKGROUND="240"
    POWERLEVEL9K_LOAD_WARNING_FOREGROUND="${PL9K_ORANGE}"
    POWERLEVEL9K_LOAD_CRITICAL_BACKGROUND="240"
    POWERLEVEL9K_LOAD_CRITICAL_FOREGROUND="${PL9K_RED}"

    POWERLEVEL9K_RAM_BACKGROUND="240"
    POWERLEVEL9K_RAM_FOREGROUND="${PL9K_TEXT_COLOR}"

    POWERLEVEL9K_BATTERY_CHARGED_BACKGROUND="240"
    POWERLEVEL9K_BATTERY_CHARGED_FOREGROUND="${PL9K_TEXT_COLOR}"
    POWERLEVEL9K_BATTERY_DISCONNECTED_BACKGROUND="240"
    POWERLEVEL9K_BATTERY_DISCONNECTED_FOREGROUND="${PL9K_BLUE}"
    POWERLEVEL9K_BATTERY_CHARGING_BACKGROUND="240"
    POWERLEVEL9K_BATTERY_CHARGING_FOREGROUND="${PL9K_GREEN}"
    POWERLEVEL9K_BATTERY_LOW_BACKGROUND="240"
    POWERLEVEL9K_BATTERY_LOW_FOREGROUND="${PL9K_RED}"

    POWERLEVEL9K_VCS_CLEAN_BACKGROUND="237"
    POWERLEVEL9K_VCS_CLEAN_FOREGROUND="${PL9K_TEXT_INVERSE_COLOR}"
    POWERLEVEL9K_VCS_MODIFIED_BACKGROUND="237"
    POWERLEVEL9K_VCS_MODIFIED_FOREGROUND="${PL9K_BLUE}"
    POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND="237"
    POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND="${PL9K_GREEN}"

    POWERLEVEL9K_OS_ICON_BACKGROUND="252"
    POWERLEVEL9K_OS_ICON_FOREGROUND="${PL9K_TEXT_COLOR}"

    POWERLEVEL9K_SSH_BACKGROUND="243"
    POWERLEVEL9K_SSH_FOREGROUND="${PL9K_TEXT_COLOR}"

    POWERLEVEL9K_VI_MODE_NORMAL_BACKGROUND="237"
    POWERLEVEL9K_VI_MODE_NORMAL_FOREGROUND="${PL9K_BLUE}"
    POWERLEVEL9K_VI_MODE_INSERT_BACKGROUND="237"
    POWERLEVEL9K_VI_MODE_INSERT_FOREGROUND="${PL9K_TEXT_COLOR}"

    POWERLEVEL9K_DIR_DEFAULT_BACKGROUND="234"
    POWERLEVEL9K_DIR_DEFAULT_FOREGROUND="${PL9K_TEXT_INVERSE_COLOR}"
    POWERLEVEL9K_DIR_HOME_BACKGROUND="234"
    POWERLEVEL9K_DIR_HOME_FOREGROUND="${PL9K_TEXT_INVERSE_COLOR}"
    POWERLEVEL9K_DIR_HOME_SUBFOLDER_BACKGROUND="234"
    POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND="${PL9K_TEXT_INVERSE_COLOR}"

    POWERLEVEL9K_DIR_WRITABLE_FORBIDDEN_BACKGROUND="243"
    POWERLEVEL9K_DIR_WRITABLE_FORBIDDEN_FOREGROUND="${PL9K_RED}"

    POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND="240"
    POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND="${PL9K_TEXT_COLOR}"

    POWERLEVEL9K_BACKGROUND_JOBS_BACKGROUND="237"
    POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND="${PL9K_TEXT_COLOR}"

    if ($zshrc_low_power); then
        POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=$']'
        POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=$'['
    fi
}

zshrc_zplug() {
    if [[ ! -d "$HOME/.zplug" ]]; then
        curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
    fi

    if [[ -d "$HOME/.zplug" ]]; then
        source "$HOME/.zplug/init.zsh"

        zplug "zplug/zplug", hook-build: "zplug --self-manage"

        zplug "zsh-users/zsh-history-substring-search"
        zplug "zsh-users/zsh-autosuggestions"
        zplug "zsh-users/zsh-completions"
        zplug "mfaerevaag/wd", as:command, use:"wd.sh", \
            hook-load:"wd() { . $ZPLUG_REPOS/mfaerevaag/wd/wd.sh }"
        zplug "arzzen/calc.plugin.zsh"
        zplug "chrissicool/zsh-256color"
        zplug "hlissner/zsh-autopair", defer:2

        # Improved bash compatibility
        # zplug "chrissicool/zsh-bash"

        #zplug "stackexchange/blackbox"
        zplug "tarrasch/zsh-command-not-found"

        zplug "junegunn/fzf", as:command, rename-to:fzf, \
            hook-build:"rm ~/.fzf.zsh; ./install --all && source ${HOME}/.fzf.zsh"

        # Install fzf or fzy
        zplug "b4b4r07/enhancd", use:init.sh, hook-load:"ENHANCD_DISABLE_DOT=1"

        # git log = glo; git diff = gd; git add = ga; git ignore = gi
        zplug "wfxr/forgit", defer:1

        export NVM_LAZY_LOAD=true
        zplug "lukechilds/zsh-nvm"

        zplug "gko/ssh-connect", as:command

        zplug "bhilburn/powerlevel9k", use:powerlevel9k.zsh-theme

        #zplug "supercrabtree/k"

        zplug "psprint/zsh-navigation-tools"

        # Must load last.
        # zplug "zsh-users/zsh-syntax-highlighting"
        zplug "zdharma/fast-syntax-highlighting", defer:3

        if ! zplug check; then
            zplug install
        fi

        zplug load
    else
        echo "Failed to load zplug plugins."
    fi
}

zshrc_display_banner() {
    if [[ -x "$(command -v neofetch)" ]]; then
        neofetch --disable "packages"
    elif [[ -x "$(command -v screenfetch)" ]]; then
        screenfetch -d '-pkgs,wm,de,res,gtk;+disk' -E
        echo
    fi
}

zshrc_set_path() {
    add_path() {
        if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
            PATH="${PATH:+"$PATH:"}$1"
        fi
    }

    add_path "$HOME/bin/"
    add_path "/sbin/"
    add_path "/usr/sbin/"
}

zshrc_load_library() {
    wifi_signal() {
        local signal=$(nmcli -t device wifi | grep '^*' | awk -F':' '{print $6}')
        local color="yellow"
        [[ $signal -gt 75 ]] && color="green"
        [[ $signal -lt 50 ]] && color="red"
        echo -n "%F{$color}\uf1eb" # \uf1eb is 
    }

    # Join a telnet based movie theater.
    starwars() {
        telnet towel.blinkenlights.nl
    }

    # Download and run a curl based Party Parrot animation.
    parrot() {
        curl parrot.live
    }

    # Duplicate of parrot()
    party() {
        parrot
    }

    # Login and play/watch Nethack from anywhere.
    nethack() {
        telnet nethack.alt.org
    }

    # Aliases, functions, commands, etc.
    extract () {
        if [ -f $1 ] ; then
            case $1 in
                *.tar.bz2)   tar xvjf $1    ;;
                *.tar.gz)    tar xvzf $1    ;;
                *.bz2)       bunzip2 $1     ;;
                *.rar)       unrar x $1       ;;
                *.gz)        gunzip $1      ;;
                *.tar)       tar xvf $1     ;;
                *.tbz2)      tar xvjf $1    ;;
                *.tgz)       tar xvzf $1    ;;
                *.zip)       unzip $1       ;;
                *.Z)         uncompress $1  ;;
                *.7z)        7z x $1        ;;
                *)           echo "Unknown filetype for '$1'" ;;
            esac
        else
            echo "'$1' is not a valid file!"
        fi
    }

    # Host the current directory via HTTP
    hostdir() {
        if type "python3" > /dev/null 2>&1; then
            python3 -m http.server
        elif type "python" > /dev/null 2>&1; then
            python -m SimpleHTTPServer
        fi
    }

    # Type a string of text letter by letter.
    typewriter() {
        local message="$1"
        local i=0
        while [ "$i" -lt "${#message}" ]; do
            echo -n "${message:$i:1}"
            sleep 0.05
            i="$((i + 1))"
        done

        printf "\n"
    }

    translate() {
        gawk -f <(curl -Ls git.io/translate) -- -shell
    }

    mapscii() {
        telnet mapscii.me
    }
}

zshrc_set_aliases() {
    # Add an "alert" alias for long running commands.  Use like so:
    #   sleep 10; alert
    alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

    # enable color support of ls and also add handy aliases
    if [ -x /usr/bin/dircolors ]; then
        test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
        alias ls='ls --color=auto'
        #alias dir='dir --color=auto'
        #alias vdir='vdir --color=auto'

        alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
        alias egrep='egrep --color=auto'
    fi

    # some more ls aliases
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'

    # Fix tmux 256 colors:
    alias tmux='tmux -2'

    # Clear color codes before clearing:
    alias clear='echo -e "\e[0m" && clear'

    # Typical rsync command
    alias relocate='rsync -avzh --info=progress2'
}

zshrc_set_default_programs() {
    export VISUAL="/usr/bin/nano"

    # For lightweight purposes.
    export EDITOR="$VISUAL"

    export PAGER="less"
    export MANPAGER="less"

    if [[ -x "$(command -v firefox)" ]]; then
        export BROWSER="firefox"
    elif [[ -x "$(command -v chromium)" ]]; then
        export BROWSER="chromium"
    elif [[ -x "$(command -v google-chrome-stable)" ]]; then
        export BROWSER="google-chrome-stable"
    fi

    if [[ -x "$(command -v urxvt-256color)" ]]; then
        export TERMINAL="$(which urxvt-256color)"
    elif [[ -x "$(command -v konsole)" ]]; then
        export TERMINAL="$(which konsole)"
    fi
}

zshrc_set_environment_variables() {
    if [[ -d "${HOME}/.anaconda2/bin" ]]; then
        export PATH="${PATH}:${HOME}/.anaconda2/bin"
    elif [[ -d "${HOME}/anaconda2/bin" ]]; then
        export PATH="${PATH}:${HOME}/anaconda2/bin"
    fi
}

zshrc_init() {
    zshrc_benchmark_start

    zshrc_detect_term_colors
    zshrc_display_banner

    zshrc_source
    zshrc_set_path
    zshrc_set_aliases
    zshrc_set_default_programs
    zshrc_set_environment_variables
    zshrc_load_library

    zshrc_setup_completion
    zshrc_set_options
    zshrc_autoload
    zshrc_powerlevel9k
    zshrc_zplug

    zshrc_benchmark_stop
}

zshrc_init

