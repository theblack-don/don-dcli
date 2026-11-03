fish_add_path -g $HOME/.local/bin

# # Nix setup
# if test -x /home/don/.local/bin/nix
#     fish_add_path -g /home/don/.local/bin
#     set -gx NIX_REMOTE daemon
#     set -gx NIX_SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt
#     set -gx NIX_PATH "nixpkgs=flake:/home/don/flake.nix#legacyPackages.x86_64-linux"
#     # NOTE: Do NOT set LD_LIBRARY_PATH to a nix store path globally here.
#     # It makes system tools (dnf5, etc.) load nix's libcurl/libssl against the
#     # system's older libcrypto -> "version `OPENSSL_3.6.0' not found" errors.
#     # if test -d /nix/store
#     #     set -gx LD_LIBRARY_PATH (ls -d /nix/store/*curl*/lib | head -1)
#     # end
#     if test -d $HOME/.nix-profile/bin
#         fish_add_path -g $HOME/.nix-profile/bin
#     end
#     if test -d $HOME/.nix-profile/share
#         set -gx XDG_DATA_DIRS "$HOME/.nix-profile/share:$XDG_DATA_DIRS"
#     end
# end

if status is-interactive
    # Commands to run in interactive sessions can go here

    # Initialize zoxide
    if type -q zoxide
        zoxide init fish | source
    end
end

# # Nix flake aliases
# alias nix-rebuild '/home/don/.local/bin/nix profile upgrade my-profile'
# alias nix-update '/home/don/.local/bin/nix flake update /home/don'

# # donzzite aliases
# alias donzzite-build='cd /var/home/don/donzzite && ./build.sh'
# alias donzzite-switch='sudo bootc upgrade'
# alias donzzite-force-switch='sudo bootc switch --transport containers-storage localhost/donzzite:latest'
# alias ds='dcli sync'

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

alias refresh='sudo dnf clean all && sudo dnf makecache'

# Set cursor theme for niri compositor
set -gx XCURSOR_THEME Bibata-Modern-Ice
set -gx XCURSOR_SIZE 24

# Add scripts directory to PATH
fish_add_path $HOME/.config/scripts

# Add Flutter to PATH
fish_add_path $HOME/development/flutter/bin

# Add opencode to PATH
fish_add_path $HOME/.opencode/bin

# Add niri-desktop scripts to PATH
fish_add_path $HOME/.config/dcli/modules/niri-desktop/dotfiles/niri/bin

# Add vm-curator to PATH
fish_add_path $HOME/vm-curator/target/release

# Set Chrome executable for Flutter web development
set -gx CHROME_EXECUTABLE /usr/bin/chromium

# Set default editor
set -gx EDITOR helix
# dcli theming
if test -f ~/.dcli/environment
    source ~/.dcli/environment
end

# Auto-update kitty theme based on desktop session
if test -n "$KITTY_PID"
    bash ~/.config/kitty/scripts/update-theme.sh &
end

# Override system fastfetch alias to use custom config (Bazzite only)
if test -f /usr/libexec/bazzite-bling-fastfetch
    function fastfetch --wraps='/usr/bin/fastfetch -c ~/.config/fastfetch/config.jsonc' --description 'fastfetch with custom config'
        /usr/bin/fastfetch -c ~/.config/fastfetch/config.jsonc $argv
    end
end

# kimi-code
fish_add_path -g "/home/don/.kimi-code/bin"

# kilo
fish_add_path /home/don/.kilo/bin

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
