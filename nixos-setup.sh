#!/usr/bin/env sh

set -eu

### Virtual machine setup:


### NixOS setup:
# Create partition tables
for device in vda vdb; do
    # EFI system partition
    sudo sgdisk \
        --new=1:256:+64M \
        --typecode 1:ef00 \
        --change-name 1:"EFI System Partition" \
        /dev/$device

    # OS root partition (Linux RAID)
    sudo sgdisk \
        --align-end \
        --largest-new=2 \
        --typecode 2:fd00 \
        --change-name 2:"root" \
        /dev/$device
done

# Format EFI system partition
# Skip creating this as an invisible RAID 1 array
sudo mkfs.vfat -F 32 -n "boot" /dev/vda1

# Create RAID array for OS root partition
sudo mdadm \
    --create /dev/md0 \
    --metadata=1.2 \
    --level=1 \
    --raid-devices=2 \
    /dev/vd[ab]2

# Format root partition
sudo mkfs.ext4 -L "root" /dev/md0
sudo udevadm settle

# Mount and install OS
sudo mount /dev/disk/by-label/root /mnt
sudo mkdir /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot

sudo nixos-generate-config --root /mnt
# Configure OS
sudo sed -i -e '/^}/d' /mnt/etc/nixos/configuration.nix
sudo tee -a /mnt/etc/nixos/configuration.nix >/dev/null <<-EOF
users.users.root.password = "password";
services.sshd.enable = true;
}
EOF

sudo nixos-install --no-root-passwd
sudo reboot now
