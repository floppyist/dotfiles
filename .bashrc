if [[ $- == *i* ]]; then
    PROMPT_DIRTRIM=3

    parse_git_status() {
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "INIT")
            local status=$(git status --porcelain 2> /dev/null)
            
            local color="\e[38;5;150m"
            local symbols=""

            if [ -n "$status" ]; then
                color="\e[38;5;216m" # Peach
                local s_mod="" s_staged="" s_untracked=""
                [[ "$status" =~ ^.[M] ]] && s_mod="*"
                [[ "$status" =~ ^[MADRC] ]] && s_staged="+"
                [[ "$status" =~ \?\? ]] && s_untracked="?"
                symbols="${s_mod}${s_staged}${s_untracked}"
            fi
            
            local git_info=" ${branch}"
            [[ -n "$symbols" ]] && git_info="${git_info} ${symbols}"

            echo -ne " \e[38;5;239m[\e[0m${color}${git_info}\e[38;5;239m]\e[0m"
        fi
    }

    bg_jobs() {
        local j=$(jobs -r | wc -l)
        if [ "$j" -gt 0 ]; then
            echo -ne " \e[38;5;147m ⚙ $j\e[0m"
        fi
    }

    set_prompt() {
        local exit_code=$?
        
        local err_msg=""
        if [[ $exit_code -ne 0 ]]; then
            if [[ $exit_code -eq 130 ]]; then
                err_msg="\[\e[38;5;244m\]󰈆 "
            elif [[ $exit_code -ne 1 || -n "$LAST_CMD_EXECUTED" ]]; then
                err_msg="\[\e[38;5;210m\]✘ $exit_code "
            fi
        fi

        LAST_CMD_EXECUTED=1

        local user_color="\[\e[1;38;5;176m\]"
        local user_name="\u"
        if [[ "$EUID" -eq 0 ]]; then
            user_color="\[\e[1;38;5;203m\]"
            user_name="ROOT"
        fi

        local host_part="\[\e[1;38;5;85m\]\h\[\e[0m\]"
        local accent="\[\e[38;5;250m\]"

        PS1="${user_color}${user_name}\[\e[0m\]@${host_part} ${accent}\w\$(parse_git_status)\$(bg_jobs)\n${err_msg}${accent}❯ \[\e[0m\]"
    }

    PROMPT_COMMAND=set_prompt

    alias ls='ls --color=auto'
    alias la='ls -la --color=auto'
    alias ll='ls -l --color=auto'
    alias grep='grep --color=auto'
    alias gs='git status'
fi

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
