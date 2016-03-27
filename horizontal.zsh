# Horizontal by Nui Narongwet
# MIT License

# Naming convension
# functions
#    - snake case
#    - use _horizontal_FUNCNAME style
#    - store result in _horizontal_FUNCNAME_result variable


# Set a plaintext of $1 without formatting
_horizontal_plaintext() {
    readonly zero_length='%([BSUbfksu]|([FB]|){*})'
    typeset -g _horizontal_plaintext_result=${(S%%)1//$~zero_length/}
}

_horizontal_reset_prompt() {
    # face color
    readonly happy='green'
    readonly sad='yellow'

    if ((${horizontal_no_color:-0})); then
        PROMPT=" '-->%(1j. %j!.) %(?.:%).:() "
        # backup prompt highlighting
        if ((${+_horizontal_orig_zsh_highlight_highlighters} == 0)); then
            _horizontal_orig_zsh_highlight_highlighters=($ZSH_HIGHLIGHT_HIGHLIGHTERS)
        fi
        # and disable it
        ZSH_HIGHLIGHT_HIGHLIGHTERS=()
    else
        # prompt face turn green if the previous command did exit with 0,
        # otherwise turn yellow
        PROMPT="%F{cyan} '--%f%B>%(1j. %F{red}%j!%f.) %(?.%F{$happy}:%).%F{$sad}:()%b%f "
        # restore prompt highlighting if needed
        if ((${#ZSH_HIGHLIGHT_HIGHLIGHTERS} == 0)); then
            ZSH_HIGHLIGHT_HIGHLIGHTERS=($_horizontal_orig_zsh_highlight_highlighters)
        fi
        unset _horizontal_orig_zsh_highlight_highlighters
    fi
}

# Set a string that when combine with $1
# its length is equal to
#   - $COLUMNS if length of $1 <= $COLUMNS
#   - $COLUMNS * 2 if length of $1 > $COLUMNS
_horizontal_gen_padding() {
    _horizontal_plaintext "${(j::)@}"
    integer prompt_length=$#_horizontal_plaintext_result
    integer n=$((COLUMNS - prompt_length))
    ((n < 0)) && n=$((COLUMNS * 2 - prompt_length))
    local IFS=${horizontal_fill_character:--}
    if ((n > 0)); then
        typeset -g _horizontal_gen_padding_result=${(l:$n:::)}
    else
        typeset -g _horizontal_gen_padding_result=
    fi
}

_horizontal_join_status() {
    local separator=${horizontal_status_separator:-"%F{cyan} | %f"}
    local string
    for item in ${@[1,-1]}; do string+=$separator$item; done
    string=${string:${#separator}} # remove leading separator
    typeset -g _horizontal_join_status_result=$string
}

# Turn number of seconds into human readable format
#   78555 => 21h 49m 15s
#    2781 => 46m 21s
_horizontal_human_time() {
    local human=""
    local total_seconds=$1
    local days=$(( total_seconds / 60 / 60 / 24 ))
    local hours=$(( total_seconds / 60 / 60 % 24 ))
    local minutes=$(( total_seconds / 60 % 60 ))
    local seconds=$(( total_seconds % 60 ))
    (( days > 0 )) && human+="${days}d "
    (( hours > 0 )) && human+="${hours}h "
    (( minutes > 0 )) && human+="${minutes}m "
    human+="${seconds}s"
    typeset -g _horizontal_human_time_result=$human
}

_horizontal_exec_seconds() {
    local stop=$EPOCHSECONDS
    local start=${_horizontal_cmd_timestamp:-$stop}
    typeset -g _horizontal_exec_seconds_result=$((stop-start))
}

_horizontal_git_dirty() {
    local umode
    # check if it's dirty
    ((${horizontal_git_untracked_dirty:-1})) && umode='-unormal' || umode='-uno'
    [[ -n $(command git status --porcelain --ignore-submodules ${umode}) ]]

    if (($? == 0)); then
        typeset -g _horizontal_git_dirty_result='*'
    else
        typeset -g _horizontal_git_dirty_result=
    fi
}

_horizontal_userhost() {
    if [[ ${horizontal_show_userhost:-1} == 1 ]]; then
        typeset -g _horizontal_userhost_result="%b%f%n|${horizontal_hostname:-%m}%f: "
    else
        typeset -g _horizontal_userhost_result=
    fi
}

prompt_horizontal_preexec() {
    typeset -g _horizontal_cmd_timestamp=$EPOCHSECONDS
    # shows the executed command in the title when a process is active
    print -n -P -- "\e]0;"
    print -n -r -- "$2"
    print -n -P -- "\a"
}

prompt_horizontal_precmd() {
    _horizontal_reset_prompt
    # shows the hostname
    print -Pn -- '\e]0;%M\a'

    local preprompt
    local rpreprompt

    _horizontal_userhost
    preprompt="%b%F{cyan}.-%B(${_horizontal_userhost_result}%B%F{yellow}%~%F{cyan})%b%F{cyan}-%f"

    ((${horizontal_show_status:-1})) && {

        local -a prompt_status
        local -a rprompt_status

        local git_info
        local timestamp

        ((${horizontal_show_git:-1})) && vcs_info

        # git branch and dirty status
        ((${horizontal_show_git:-1})) && [[ -n $vcs_info_msg_0_ ]] && {
            _horizontal_git_dirty
            git_info="${vcs_info_msg_0_}${_horizontal_git_dirty_result}"
            [[ -n $git_info ]] && prompt_status+=$git_info
        }

        # pyenv python version
        ((${horizontal_show_pyenv_python_version:-1})) && [[ -n $PYENV_VERSION ]] && {
            prompt_status+="PyEnv $PYENV_VERSION"
        }

        # python virtual environment
        ((${horizontal_show_pythonenv:-1})) && [[ -n $VIRTUAL_ENV ]] && {
            prompt_status+="(${VIRTUAL_ENV:t}%)"
        }

        # last command execute time
        ((${horizontal_show_exec_time:-1})) && {
            _horizontal_exec_seconds
            (( $_horizontal_exec_seconds_result > ${horizontal_cmd_max_exec_time:-5} )) && {
                _horizontal_human_time $_horizontal_exec_seconds_result
                prompt_status+="%F{yellow}$_horizontal_human_time_result%f"
            }
        }

        ((${horizontal_show_timestamp:-1})) && {
            _horizontal_exec_seconds
            (($_horizontal_exec_seconds_result - ${horizontal_timestamp_threshold_seconds:-180} >= 0)) && {
                strftime -s timestamp '%D %R' $EPOCHSECONDS
                rprompt_status+=$timestamp
            }
        }

        # put status to preprompt line
        ((${#prompt_status} > 0)) && {
            _horizontal_join_status $prompt_status
            preprompt+=" $_horizontal_join_status_result "
        }

        # put rstatus to right of preprompt line
        ((${#rprompt_status} > 0)) && {
            _horizontal_join_status $rprompt_status
            rpreprompt+=" $_horizontal_join_status_result %F{cyan}-%f"
        }
    }

    # make a horizontal line
    ((${horizontal_fill_space:-1})) && {
        _horizontal_gen_padding $preprompt $rpreprompt
        preprompt+="%F{cyan}${_horizontal_gen_padding_result}%f$rpreprompt"
    }

    # blank line before preprompt line
    ((${horizontal_cozy:-0})) && preprompt="\n$preprompt"

    ((${horizontal_no_color:-0})) && {
        _horizontal_plaintext $preprompt
        preprompt=$_horizontal_plaintext_result
    }

    # print preprompt line
    print -P -- $preprompt

    # reset value since `preexec` isn't always triggered
    unset _horizontal_cmd_timestamp
}

prompt_horizontal_setup() {
    # horizontal default settings
    # You can override below settings in .zshrc
        # horizontal_cmd_max_exec_time=5
        # horizontal_cozy=0
        # horizontal_fill_character=-
        # horizontal_fill_space=1
        # horizontal_git_branch_symbol=''
        # horizontal_git_untracked_dirty=1
        # horizontal_hostname=
        # horizontal_no_color=0
        # horizontal_show_exec_time=1
        # horizontal_show_git=1
        # horizontal_show_pyenv_python_version=1
        # horizontal_show_pythonenv=1
        # horizontal_show_status=1
        # horizontal_show_timestamp=1
        # horizontal_show_userhost=1
        # horizontal_status_separator="%F{cyan} | %f"
        # horizontal_timestamp_threshold_seconds=180

    # prevent percentage showing up
    # if output doesn't end with a newline
    export PROMPT_EOL_MARK=''

    prompt_opts=(cr percent)

    zmodload zsh/datetime
    autoload -Uz add-zsh-hook
    autoload -Uz vcs_info

    add-zsh-hook precmd prompt_horizontal_precmd
    add-zsh-hook preexec prompt_horizontal_preexec

    local git_branch_symbol
    if (($+horizontal_git_branch_symbol)); then
        git_branch_symbol=$horizontal_git_branch_symbol
    else
        git_branch_symbol=''
    fi
    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:git*' formats "$git_branch_symbol%b"
    zstyle ':vcs_info:git*' actionformats "$git_branch_symbol%b|%a"

    # disable auto updating PS1 by virtualenv
    VIRTUAL_ENV_DISABLE_PROMPT=1
}

prompt_horizontal_setup "$@"
# vim: ft=zsh sw=4 sts=4 ts=4
