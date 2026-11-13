fish_add_path -g $HOME/.local/bin

if status is-interactive
    # Commands to run in interactive sessions can go here

    # Initialize zoxide
    if type -q zoxide
        zoxide init fish | source
    end
end

# Alias for opencode
alias op='opencode'

# Alias for Claude
alias cc='claude'

# Felix (TUI file manager from Terra) ships its binary as `fx`, not `felix`.
# Provide `felix` as a convenient alias for the real command.
alias felix='fx'

# Alias for yazi
alias y='yazi'

# Alias for neovim
alias nv='nvim'

# Set cursor theme for niri compositor
set -gx XCURSOR_THEME Bibata-Modern-Ice
set -gx XCURSOR_SIZE 24

# Add opencode to PATH
fish_add_path $HOME/.opencode/bin

# Set default editor
set -gx EDITOR helix

# Auto-update kitty theme based on desktop session
if test -n "$KITTY_PID"
    bash ~/.config/kitty/scripts/update-theme.sh &
end

# Use the file logo from ~/.config/fastfetch/config.jsonc.
# Hyde's conf.d sets `alias fastfetch='fastfetch --logo-type kitty'`, which overrides
# the config's logo type and makes fastfetch fall back to the built-in OS logo.
function fastfetch --wraps='fastfetch' --description 'fastfetch with custom config'
    command fastfetch $argv
end

# Drop duplicate PATH entries. Login/systemd environments can accumulate many
# copies of ~/.local/bin, and nested shells inherit the whole list. Keep the
# first occurrence so ~/.local/bin (dcli wrappers) still wins over
# ~/.nix-profile/bin for same-named binaries such as ghostty.
set -l clean_path
for path_entry in $PATH
    if not contains -- $path_entry $clean_path
        set -a clean_path $path_entry
    end
end
set -gx PATH $clean_path
