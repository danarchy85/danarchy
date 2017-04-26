#!/bin/bash
# Make and Make Modules_Install on current /usr/src/linux path,
# and install into /boot/ with grub-mkconfig
# added lines for Xen setup

path="/usr/src"
version=$(find $path -maxdepth 1 -type l -exec ls -l {} \; | awk -F- '{print$3}')
kernel="kernel-$version-danarchy_intel_xen_zfs"
config="config-$version-danarchy_intel_xen_zfs"

echo "Building kernel for linux-$version :: $kernel"

cd $path/linux
make -j9
make modules_install

echo "Copying files for linux-$version into /boot"
boot=$(mount|grep /boot)
if [[ -z $boot ]] ; then
    echo "Mounting /boot"
    mount /boot
fi

cp -v $path/linux/arch/x86_64/boot/bzImage /boot/$kernel
cp -v $path/linux/.config $path/$config
cp -v $path/linux/.config /boot/$config

echo "Backing up /boot/xen files."
mv -v /boot/xen.gz /boot/xen_backup/
mv -v /boot/xen-* /boot/xen_backup/
ls /boot/

echo "emerging xen & modules."
emerge xen
emerge @module-rebuild
grub-mkconfig -o /boot/grub/grub.cfg

echo "Installing $kernel into /xen/kernels/"
cp -v /boot/$kernel /xen/kernels/$kernel
echo -e "\nKernel installed into /xen/kernels/$kernel.\n"

# echo "Updating xen configs with new kernel version: $version"
new_kern="kernel = '\/xen\/kernels\/$kernel'"
echo -e "Updating configs...\n"
for config in $(find /xen/ -type f -name '*.conf'); do
    echo -e "Updating config for: $config"
    sed -i -e "/^kernel/s/.*/$new_kern/g" $config
done
