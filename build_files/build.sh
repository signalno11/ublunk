#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Install Niri
dnf5 -y install niri niri-settings
# Enable Dux repo
dnf5 -y copr enable duxlabs/dms
# Install Dux dependencies
dnf5 -y install quickshell
dnf5 -y install qt6-qtmultimedia accountsservice qt6ct greetd
dnf5 -y install cava fira-code-fonts rsms-inter-fonts material-symbols-fonts
# Explicitly install desired Dux components
dnf5 -y install dux-gop dux-search dux-search dux-calendar matugen dux-greeter
# Install Dux
dnf5 -y install dms

# Install Dolphin
dnf5 -y install dolphin

# Install QWERTY-fr
dnf5 -y copr enable emixampp/qwerty-fr
dnf5 -y install qwerty-fr

# Add Terra repo (code from Bazzite repo)

dnf5 -y install \
    --nogpgcheck \
    --setopt=terra.skip_if_unavailable=False \
    --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
    terra-release{,-extras,-mesa}
dnf5 config-manager setopt '*terra*.skip_if_unavailable=False'


# Valve patched packages
curl -fsSL \
    https://raw.githubusercontent.com/ublue-os/bazzite/main/build_files/bazzite/05-valve-patches.sh \
    -o /tmp/05-valve-patches.sh \
    && bash /tmp/05-valve-patches.sh \
    && rm /tmp/05-valve-patches.sh

# Remove default packages
dnf5 -y remove firefox toolbox
# Add distrobox
dnf5 -y install distrobox

# Install Brave Origin
dnf5 -y config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
dnf -y install brave-origin

# Dev packages
dnf5 -y group install development-tools
dnf5 -y install vim-enhanced neovim git clang gcc zsh
dnf5 -y install --from-repo=terra ghostty

# Steam and Lutris
curl -fsSL \
    https://raw.githubusercontent.com/ublue-os/bazzite/refs/heads/main/build_files/bazzite/08-install-steam-lutris.sh \
    -o /tmp/08-install-steam-lutris.sh \
    && bash /tmp/08-install-steam-lutris.sh \
    && rm /tmp/08-install-steam-lutris.sh

# Brew
curl -fsSL \
    https://raw.githubusercontent.com/ublue-os/bazzite/908870373ffbf3a590edca261691012872d4b652/build_files/bazzite/01-copy-brew-files.sh \
    -o /tmp/01-copy-brew-files.sh \
    && bash /tmp/01-copy-brew-files.sh \
    && rm /tmp/01-copy-brew-files.sh


# Selective Finalize Steps from Bazzite
# -- Patch grub2-mkconfig --
# Fix grub_probe path for chroot compatibility.
echo "==> Patching grub2-mkconfig..."
# Match literal backticks in the GRUB script.
# shellcheck disable=SC2016
sed -i \
    's|grub_probe\} --target=device /`|grub_probe} --target=device /sysroot`|g' \
    /usr/bin/grub2-mkconfig

# -- Configure Flatpak --
echo "==> Configuring Flatpak..."
mkdir -p /etc/flatpak/remotes.d
curl --fail --retry 3 --retry-all-errors -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo \
    https://dl.flathub.org/repo/flathub.flatpakrepo


# Homebrew Setup

/usr/bin/systemctl preset brew-setup.service && \
/usr/bin/systemctl preset brew-update.timer && \
/usr/bin/systemctl preset brew-upgrade.timer

curl -fsSL \
    https://raw.githubusercontent.com/ublue-os/bazzite/refs/heads/main/build_files/bazzite-nvidia/01-remove-nvidia-conflicts.sh \
    -o /tmp/01-remove-nvidia-conflicts.sh \
    && bash /tmp/01-remove-nvidia-conflicts.sh \
    && rm /tmp/01-remove-nvidia-conflicts.sh

curl -fsSL \
    https://raw.githubusercontent.com/ublue-os/bazzite/refs/heads/main/build_files/bazzite-nvidia/02-install-nvidia-driver.sh \
    -o /tmp/02-install-nvidia-driver.sh \
    && sed -i '/Waydroid/Id' /tmp/02-install-nvidia-driver.sh \
    && bash /tmp/02-install-nvidia-driver.sh \
    && rm /tmp/02-install-nvidia-driver.sh

curl -fsSL \
    https://raw.githubusercontent.com/ublue-os/bazzite/refs/heads/main/build_files/bazzite-nvidia/03-finalize.sh \
    -o /tmp/03-finalize.sh \
    && sed -i '/justfile/Id' /tmp/03-finalize.sh \
    && bash /tmp/03-finalize.sh \
    && rm /tmp/03-finalize.sh

KERNEL_VERSION="$(rpm -q --queryformat='%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)"
export DRACUT_NO_XATTR=1
dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --add ostree \
    -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
chmod 0600 "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
