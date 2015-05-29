# Horizontal
# by Nui Narongwet
# MIT License


_prompt_horizontal_remove_invisible_character() {
  readonly zero_length='%([BSUbfksu]|([FB]|){*})'
  print -n -- ${(S%%)1//$~zero_length/}
}


_prompt_horizontal_preprompt_length() {
  print -n -- "${#$(_prompt_horizontal_remove_invisible_character "$@")}"
}


_prompt_horizontal_set_prompt() {
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


_prompt_horizontal_generate_fill_string() {
  integer prompt_length=$(_prompt_horizontal_preprompt_length ${(j::)@})
  integer n=$((COLUMNS - prompt_length))
  ((n < 0)) && n=$((COLUMNS * 2 - prompt_length))
  ((n > 0)) && printf -- "${horizontal_fill_character:--}%.0s" {1..$n}
}


_prompt_horizontal_join_status_array() {
  local separator=$1
  local string
  for item in ${@[2,-1]}; do string+=$separator$item; done
  string=${string:${#separator}} # remove leading separator
  print -n -- $string
}


_prompt_horizontal_human_time() {
  # turns seconds into human readable time
  # e.g., 165392 => 1d 21h 56m 32s
  integer tmp=$1
  integer days=$((tmp / 60 / 60 / 24))
  integer hours=$((tmp / 60 / 60 % 24))
  integer minutes=$((tmp / 60 % 60))
  integer seconds=$((tmp % 60))
  (($days > 0)) && print -n -- "${days}d "
  (($hours > 0)) && print -n -- "${hours}h "
  (($minutes > 0)) && print -n -- "${minutes}m "
  print -n -- ${seconds}s
}


_prompt_horizontal_cmd_exec_time() {
  # displays the exec time of the last command if set threshold was exceeded
  local stop=$EPOCHSECONDS
  local start=${_horizontal_cmd_timestamp:-$stop}
  integer elapsed=$stop-$start
  (($elapsed > ${horizontal_cmd_max_exec_time:=5})) && _prompt_horizontal_human_time $elapsed
}


_prompt_horizontal_git_dirty() {
  local umode
  # check if we're in a git repo
  command git rev-parse --is-inside-work-tree &>/dev/null || return
  # check if it's dirty
  ((${horizontal_git_untracked_dirty:-1})) && umode='-unormal' || umode='-uno'
  [[ -n $(command git status --porcelain --ignore-submodules ${umode}) ]]

  (($? == 0)) && print -n -- '*'
}


_prompt_horizontal_userhost() {
  if [[ ${horizontal_show_userhost:-1} == 1 ]]; then
    print -n -- "%b%f%n|%B${horizontal_hostname:-%m}%b%f: "
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
  _prompt_horizontal_set_prompt
  # shows the hostname
  print -Pn -- '\e]0;%M\a'

  local preprompt
  local r_preprompt

  preprompt="%b%F{cyan}.-%B($(_prompt_horizontal_userhost)%B%F{yellow}%~%F{cyan}\)%b%F{cyan}-%f"

  ((${horizontal_show_status:-1})) && {

    local -a prompt_status
    local separator=${horizontal_status_separator:-"%F{cyan} | %f"}

    local exec_time
    local git_info

    ((${horizontal_show_git:-1})) && vcs_info

    # git branch and dirty status
    ((${horizontal_show_git:-1})) && {
      git_info="$vcs_info_msg_0_$(_prompt_horizontal_git_dirty)"
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
      exec_time=$(_prompt_horizontal_cmd_exec_time)
      [[ -n $exec_time ]] && prompt_status+="%F{yellow}${exec_time}%f"
    }

    # put status to preprompt line
    ((${#prompt_status} > 0)) && {
      preprompt+=' '$(_prompt_horizontal_join_status_array $separator $prompt_status)' '
    }
  }

  # fill preprompt line space
  ((${horizontal_fill_space:-1})) &&
    preprompt+="%F{cyan}$(_prompt_horizontal_generate_fill_string $preprompt $r_preprompt)%f$r_preprompt"

  # add a blank line before preprompt line
  ((${horizontal_cozy:-0})) && preprompt="\n$preprompt"

  ((${horizontal_no_color:-0})) && {
    preprompt=$(_prompt_horizontal_remove_invisible_character $preprompt)
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
    # horizontal_show_userhost=1
    # horizontal_status_separator="%F{cyan} | %f"

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

  # disable auto updating PS1 by python virtual environment
  VIRTUAL_ENV_DISABLE_PROMPT=1
}

prompt_horizontal_setup "$@"

# vim: ft=zsh sw=2 sts=2 ts=2

