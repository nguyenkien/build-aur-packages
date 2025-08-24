#!/usr/bin/env bash

# Fail if anything goes wrong.
set -e
# Print each line before executing.
set -x

sudo --user builder repo-add /local_repository/$INPUT_NAME.db.tar.gz /local_repository/aurutils-*.pkg.tar.zst
sudo --user builder repo-remove /local_repository/$INPUT_NAME.db.tar.gz aurutils

# Register the local repository with pacman.
echo "# local repository (required by aur tools to be set up)" >> /etc/pacman.conf
echo "[$INPUT_NAME]" >> /etc/pacman.conf
echo "SigLevel = Optional TrustAll" >> /etc/pacman.conf
echo "Server = file:///local_repository" >> /etc/pacman.conf

# Get list of all packages with dependencies to install.
packages_with_aur_dependencies="$(aur depends --pkgname $INPUT_PACKAGES $INPUT_MISSING_AUR_DEPENDENCIES)"
echo "AUR Packages requested to install: $INPUT_PACKAGES"
echo "AUR Packages to fix missing dependencies: $INPUT_MISSING_AUR_DEPENDENCIES"
echo "AUR Packages to install (including dependencies): $packages_with_aur_dependencies"

# Sync repositories.
pacman -Sy

# Check for optional missing pacman dependencies to install.
if [ -n "$INPUT_MISSING_PACMAN_DEPENDENCIES" ]
then
    echo "Additional Pacman packages to install: $INPUT_MISSING_PACMAN_DEPENDENCIES"
    pacman --noconfirm -S $INPUT_MISSING_PACMAN_DEPENDENCIES
fi

# Add the packages to the local repository.
sudo --user builder \
    aur sync \
    --noconfirm --noview \
    --database $INPUT_NAME --root /local_repository \
    $packages_with_aur_dependencies

# Move the local repository to the workspace.
if [ -n "$GITHUB_WORKSPACE" ]
then
    rm -f /local_repository/*.old
    rm -f /local_repository/*debug-*.pkg.tar.zst

    echo "Moving repository to github workspace"
    mv /local_repository/* $GITHUB_WORKSPACE/
    # make sure that the .db/.files files are in place
    # Note: Symlinks fail to upload, so copy those files
    cd $GITHUB_WORKSPACE
    rm $INPUT_NAME.db $INPUT_NAME.files
    cp $INPUT_NAME.db.tar.gz $INPUT_NAME.db
    cp $INPUT_NAME.files.tar.gz $INPUT_NAME.files
else
    echo "No github workspace known (GITHUB_WORKSPACE is unset)."
fi
