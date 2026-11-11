function fish_prompt -d "Write out the prompt"
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

if status is-interactive # Commands to run in interactive sessions can go here

    set fish_greeting

    starship init fish | source
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    alias pamcan pacman
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias q 'qs -c ii'
    alias ls 'eza --icons --long --header'
    alias ll 'eza --icons --long --level=2 --header --tree'
    alias la 'eza -a --icons --long'
    alias lg 'eza --git --icons --long --header'
    alias llg 'eza --git --icons --long --level=2 --header --tree'
    alias lag 'eza --git -a --icons --long'

end

function conf
    cd ~/.config
end

set -Ux fish_user_paths $HOME/.config/scripts/ $fish_user_paths
fastfetch -c ~/.config/fastfetch/config.jsonc -l arch
export PATH="$HOME/.local/bin:$PATH"
