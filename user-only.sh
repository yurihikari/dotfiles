#!/bin/bash

set -euo pipefail

cd ~

for dir in ~/.usr/bin/ ~/.usr/opt ~/.usr/var/log ~/code/ ~/code/tmp ; do
    [[ -d "${dir}" ]] || mkdir -p "${dir}"
done

# mpd
if [[ ! -d ~/.mpd ]] ; then
    mkdir -p ~/.mpd/playlists
    pushd ~/.mpd &> /dev/null
    touch mpd.db mpd.log mpd.pid mpdstate
    popd &> /dev/null
fi

# ssh
[[ -d ~/.ssh ]] || mkdir ~/.ssh && chmod 700 ~/.ssh
[[ -d ~/.ssh/tmp ]] || mkdir ~/.ssh/tmp && chmod 700 ~/.ssh/tmp

# tpm (tmux-plugin-manager)
[[ -d ~/.tmux/plugins/tpm ]] || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# install plugins. buggy, better use prefix + I
~/.tmux/plugins/tpm/scripts/install_plugins.sh > /dev/null

# stow the dotfiles
pushd ~/.dotfiles/ &> /dev/null
for dir in backups base docker emacs gnupg js mpd mpv ssh tmux valgrind X ; do
    stow --no-folding ${dir}
done
# hack for the freaking symlink removal
chmod 500 ~/.config/gtk-2.0/

stow --no-folding *-"$(hostname)"
popd &> /dev/null

# Linux Specific
if [[ "$OSTYPE" == "linux-gnu" ]] ; then
    # Reload systemd because of systemd units
    systemctl --user daemon-reload

    # change file-chooser startup location in gtk 3 https://wiki.archlinux.org/index.php/GTK%2B#File-Chooser_Startup-Location
    gsettings set org.gtk.Settings.FileChooser startup-mode cwd
fi
# macOS Specific
if [[ "$OSTYPE" == "darwin"* ]]; then
    [[ -d ~/.brew ]] || git clone --depth=1 https://github.com/Homebrew/brew ~/.brew

    packages=(
        coreutils
        emacs
        gdb
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
        [[ -d ~/.brew/opt/$package ]] || ~/.brew/bin/brew install $package
    done

    latest_tmux=$(ls -t ~/.brew/Cellar/tmux/ | head -n1)
    grep with-utf8proc ~/.brew/Cellar/tmux/$latest_tmux/.brew/tmux.rb || sed -i -e $'s/args = %W\\[/args = %W[\\\n      --with-utf8proc/' ~/.brew/Cellar/tmux/$latest_tmux/.brew/tmux.rb
    brew reinstall tmux
    brew services start syncthing

    for symlink in date dircolors ls rm ; do
        [[ -L ~/.usr/bin/$symlink ]] || ln -s ~/.brew/bin/g$symlink ~/.usr/bin/$symlink
    done
fi

# ssh config
pushd ~/.ssh &> /dev/null
./update
popd &> /dev/null

# Clone repositories
chronic mr -j 5 up
