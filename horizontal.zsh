# Horizontal by Nui Narongwet
# MIT License

# Naming convension
# functions
#    - avoid function keyword
#    - snake case
#    - prefix function name with _horizontal_
#    - store function result in FUNCNAME_result variable


# Set a plaintext of $1 without formatting
_horizontal_plaintext() {
    readonly zero_length='%([BSUbfksu]|([FB]|){*})'
    typeset -g _horizontal_plaintext_result=${(S%%)1//$~zero_length/}
}

_horizontal_reset_prompt() {
    # face color
    readonly happy='green'
    readonly sad='yellow'

    if ((${horizontal[color]})); then
        # prompt face turn green if the previous command did exit with 0,
        # otherwise turn yellow
        PROMPT="%F{${horizontal[base_color]}} '--%f%B>%(1j. %F{red}%j!%f.) %(?.%F{$happy}:%).%F{$sad}:()%b%f "
        # restore prompt highlighting if needed
        if ((${#ZSH_HIGHLIGHT_HIGHLIGHTERS} == 0)); then
            ZSH_HIGHLIGHT_HIGHLIGHTERS=($_horizontal_orig_zsh_highlight_highlighters)
        fi
        unset _horizontal_orig_zsh_highlight_highlighters
    else
        PROMPT=" '-->%(1j. %j!.) %(?.:%).:() "
        # backup prompt highlighting
        if ((${+_horizontal_orig_zsh_highlight_highlighters} == 0)); then
            _horizontal_orig_zsh_highlight_highlighters=($ZSH_HIGHLIGHT_HIGHLIGHTERS)
        fi
        # and disable it
        ZSH_HIGHLIGHT_HIGHLIGHTERS=()
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
    local IFS=${horizontal[fill_character]}
    if ((n > 0)); then
        typeset -g _horizontal_gen_padding_result=${(l:$n:::)}
    else
        typeset -g _horizontal_gen_padding_result=
    fi
}

_horizontal_join_status() {
    local separator=${horizontal_status_separator:-"%F{${horizontal[base_color]}} | %f"}
    local string
    for item in $@; do string+=$separator$item; done
    string=${string:${#separator}} # remove leading separator
    typeset -g _horizontal_join_status_result=$string
}

# Turn number of seconds into human readable format
#   78555 => 21h 49m 15s
#    2781 => 46m 21s
_horizontal_human_time() {
    local result=""
    local total_seconds=$1
    local days=$((total_seconds / 60 / 60 / 24))
    local hours=$((total_seconds / 60 / 60 % 24))
    local minutes=$((total_seconds / 60 % 60))
    local seconds=$((total_seconds % 60))
    ((days > 0)) && result+="${days}d "
    ((hours > 0)) && result+="${hours}h "
    ((minutes > 0)) && result+="${minutes}m "
    result+="${seconds}s"
    typeset -g _horizontal_human_time_result=$result
}

_horizontal_exec_seconds() {
    local stop=$EPOCHSECONDS
    local start=${_horizontal_cmd_timestamp:-$stop}
    typeset -g _horizontal_exec_seconds_result=$((stop-start))
}

_horizontal_git_dirty() {
    if ((${horizontal[git_untracked_dirty]})); then
        test -z "$(command git status --porcelain --ignore-submodules -unormal)"
    else
        command git diff --no-ext-diff --quiet --exit-code
    fi

    if (($? == 0)); then
        typeset -g _horizontal_git_dirty_result=
    else
        typeset -g _horizontal_git_dirty_result='*'
    fi
}

_horizontal_userhost() {
    if [[ ${horizontal[userhost]} == 1 ]]; then
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
    preprompt="%b%F{${horizontal[base_color]}}.-%B(${_horizontal_userhost_result}%B%F{yellow}%~%F{${horizontal[base_color]}})%b%F{${horizontal[base_color]}}-%f"

    ((${horizontal[status]})) && {

        local -a prompt_status
        local -a rprompt_status

        local git_info
        local timestamp

        ((${horizontal[git]})) && vcs_info

        # git branch and dirty status
        ((${horizontal[git]})) && [[ -n $vcs_info_msg_0_ ]] && {
            ((${horizontal[git_dirty]})) && _horizontal_git_dirty
            git_info="${vcs_info_msg_0_}${_horizontal_git_dirty_result}"
            [[ -n $git_info ]] && prompt_status+=$git_info
        }

        # python virtual environment
        ((${horizontal[virtualenv]})) && [[ -n $VIRTUAL_ENV ]] && {
            prompt_status+="(${VIRTUAL_ENV:t}%)"
        }

        # last command execute time
        ((${horizontal[exec_time]})) && {
            _horizontal_exec_seconds
            (($_horizontal_exec_seconds_result > ${horizontal[cmd_max_exec_time]})) && {
                _horizontal_human_time $_horizontal_exec_seconds_result
                prompt_status+="%F{yellow}$_horizontal_human_time_result%f"
            }
        }

        ((${horizontal[timestamp]})) && {
            _horizontal_exec_seconds
            (($_horizontal_exec_seconds_result - ${horizontal[timestamp_threshold_seconds]} >= 0)) && {
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
            rpreprompt+=" $_horizontal_join_status_result %F{${horizontal[base_color]}}-%f"
        }
    }

    # make a horizontal line
    ((${horizontal[hr]})) && {
        _horizontal_gen_padding $preprompt $rpreprompt
        preprompt+="%F{${horizontal[base_color]}}${_horizontal_gen_padding_result}%f$rpreprompt"
    }

    # blank line before preprompt line
    ((${horizontal[cozy]})) && preprompt="\n$preprompt"

    ((${horizontal[color]} == 0)) && {
        _horizontal_plaintext $preprompt
        preprompt=$_horizontal_plaintext_result
    }

    # print preprompt line
    print -P -- $preprompt

    # reset value since `preexec` isn't always triggered
    unset _horizontal_cmd_timestamp
}

prompt_horizontal_setup() {
    typeset -gA horizontal
    # Enable/Disable horizontal features
    : ${horizontal[base_color]:=cyan}
    : ${horizontal[color]:=1}
    : ${horizontal[cozy]:=0}
    : ${horizontal[exec_time]:=1}
    : ${horizontal[git]:=1}
    : ${horizontal[git_dirty]:=1}
    : ${horizontal[git_untracked_dirty]:=1}
    : ${horizontal[hr]:=1}
    : ${horizontal[status]:=1}
    : ${horizontal[timestamp]:=1}
    : ${horizontal[userhost]:=1}
    : ${horizontal[virtualenv]:=1}

    : ${horizontal[cmd_max_exec_time]:=5}
    : ${horizontal[fill_character]:=-}
    : ${horizontal[timestamp_threshold_seconds]:=180}
    # horizontal_branch_symbol=''
    # horizontal_hostname=
    # horizontal_status_separator="%F{${horizontal[base_color]}} | %f"

    # prevent percentage showing up
    # if output doesn't end with a newline
    export PROMPT_EOL_MARK=''

    prompt_opts=(cr percent)

    zmodload zsh/datetime
    autoload -Uz add-zsh-hook
    autoload -Uz vcs_info

    add-zsh-hook precmd prompt_horizontal_precmd
    add-zsh-hook preexec prompt_horizontal_preexec

    local branch_symbol=${horizontal_branch_symbol-''}
    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' use-simple true
    # only export two msg variables from vcs_info
    zstyle ':vcs_info:*' max-exports 2
    # vcs_info_msg_0_ = ' %b' (for branch)
    # vcs_info_msg_1_ = 'x%R' git top level (%R), x-prefix prevents creation of a named path (AUTO_NAME_DIRS)
    zstyle ':vcs_info:git*' formats "$branch_symbol%b" 'x%R'
    zstyle ':vcs_info:git*' actionformats "$branch_symbol%b|%a" 'x%R'

    # disable auto updating PS1 by virtualenv
    VIRTUAL_ENV_DISABLE_PROMPT=1
    export PYENV_VIRTUALENV_DISABLE_PROMPT=1
}

prompt_horizontal_setup "$@"
# vim: ft=zsh sw=4 sts=4 ts=4
