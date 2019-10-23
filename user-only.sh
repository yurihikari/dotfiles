#!/bin/bash

set -euo pipefail
set -x

script_dir=$(dirname $0)
pushd ${script_dir} > /dev/null

for dir in ~/code/ ~/code/tmp/ ; do
    [[ -d "${dir}" ]] || mkdir -p "${dir}"
done

# macOS Specific
if [[ "$OSTYPE" == "darwin"* ]]; then
    export PATH="~/.brew/bin/:$PATH"

    [[ -d ~/.brew ]] || git clone --depth=1 https://github.com/Homebrew/brew ~/.brew

    packages=(
        atool
        coreutils
        editorconfig
        emacs
        gnupg
        go
        mosh
        myrepos
        python3
        ripgrep
        stow
        syncthing
        tmux
        valgrind
    )

    for package in ${packages[@]} ; do
        [[ -d ~/.brew/opt/$package ]] || brew install $package
    done

    ### Tmux
    # Patch the formula to enable displaying unicode characters
    if ! grep with-utf8proc ~/.brew/Library/Taps/homebrew/homebrew-core/Formula/tmux.rb &>/dev/null ; then
        sed -i -e $'s/args = %W\\[/args = %W[\\\n      --with-utf8proc/' ~/.brew/Library/Taps/homebrew/homebrew-core/Formula/tmux.rb
        brew reinstall tmux
    fi

    ### coreutils
    # Replace some macOS's coreutils binaries with a GNU one
    for symlink in date dircolors ls rm sort ; do
        [[ -L ~/.usr/bin/$symlink ]] || ln -s g$symlink ~/.usr/bin/$symlink
    done

    # symlink only llvm's scan-build because we don't want this llvm to replace
    # macOS's one
    [[ -L ~/.brew/bin/scan-build ]] || ln -s ~/.brew/opt/lllvm/bin/scan-build ~/.brew/bin/

    ### terminfo
    # We need the terminfo capabilites of tmux-256color, however macOS doesn't
    # provide one.  The one that is in the homebrew's ncurses is incompatible
    # with macOS ncurses tools (tic/terminfo). So we export the terminfo
    # capabilities with homebrew's ncurses tools and compile them with macOS'
    # tic.
    [[ -d ~/.terminfo ]] || mkdir ~/.terminfo
    latest_ncurses=$(ls -t ~/.brew/Cellar/ncurses/ | head -n1)
    PATH="~/.brew/opt/ncurses/bin:$PATH" TERMINFO_DIRS=~/.brew/Cellar/ncurses/$latest_ncurses/share/terminfo/ infocmp -x tmux-256color > ~/.terminfo/tmux-256color
    tic -x ~/.terminfo/tmux-256color

    brew services list | grep syncthing > /dev/null || brew services start syncthing

    ### screensaver
    # Require a password immediately after enabling the screensaver
    defaults write com.apple.screensaver askForPassword -bool true
    defaults write com.apple.screensaver askForPasswordDelay -int 0

    ### iterm2
    # Specify the preferences directory
    defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "~/.dotfiles/iterm2"
    # Tell iTerm2 to use the custom preferences from this directory
    defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true

    ### Dock
    # Show only active apps
    defaults write com.apple.dock static-only -bool true
    # Auto hide
    defaults write com.apple.dock autohide -bool true
    # Reload
    killall Dock
fi

# mpd
if [[ ! -d ~/.mpd ]] ; then
    mkdir -p ~/.mpd/playlists
    touch ~/.mpd/{mpd.db,mpd.log,mpd.pid,mpdstate}
fi

# ssh
[[ -d ~/.ssh ]] || mkdir ~/.ssh && chmod 700 ~/.ssh
[[ -d ~/.ssh/tmp ]] || mkdir ~/.ssh/tmp && chmod 700 ~/.ssh/tmp

# stow the dotfiles
for dir in base docker emacs gnupg js karabiner mpd mpv ssh tmux valgrind X ; do
    stow --no-folding ${dir}
done
# hack for the freaking symlink removal
chmod 500 ~/.config/gtk-2.0/

# Stow *-hostname or *-domain
ls -d *-"$(hostname)" &>/dev/null && stow --no-folding *-"$(hostname)"
ls -d *-"$(hostname | cut -d. -f2-)" &>/dev/null && stow --no-folding *-"$(hostname | cut -d. -f2-)"

# Linux Specific
if [[ "$OSTYPE" == "linux-gnu" ]] ; then
    # Reload systemd because of systemd units
    systemctl --user daemon-reload

    # change file-chooser startup location in gtk 3 https://wiki.archlinux.org/index.php/GTK%2B#File-Chooser_Startup-Location
    gsettings set org.gtk.Settings.FileChooser startup-mode cwd
fi

# ssh config
cd ~/.ssh > /dev/null
./update

popd > /dev/null
