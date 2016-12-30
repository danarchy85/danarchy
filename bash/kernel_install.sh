#!/bin/bash
# Make and Make Modules_Install on current /usr/src/linux path,
# and install into /boot/ with grub-mkconfig

path="/usr/src"
version=$(stat /usr/src/linux | awk -F\' '/File/ {print$4}' | sed -e 's/linux-//g')
kernel="kernel-$version-$HOSTNAME"
config="config-$version-$HOSTNAME"

echo "Building kernel for linux-$version :: $kernel"

cd $path/linux
make
make modules_install

echo "Installing linux-$version into /boot"
boot=$(mount|grep /boot)

if [[ -z $boot ]] ; then
    echo "Mounting /boot"
    mount /boot
fi

cp -v $path/linux/.config $path/$config
cp -v $path/linux/arch/x86_64/boot/bzImage /boot/$kernel
cp -v $path/linux/.config /boot/$config

echo "reemerging modules."
emerge @module-rebuild
grub-mkconfig -o /boot/grub/grub.cfg
