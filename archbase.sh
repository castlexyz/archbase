#!/bin/bash
###################################################################
#      _                           _                 _            #
#   __| | ___ _ __   ___ _ __   __| | ___ _ __   ___(_) ___  ___  #
#  / _` |/ _ \ '_ \ / _ \ '_ \ / _` |/ _ \ '_ \ / __| |/ _ \/ __| #
# | (_| |  __/ |_) |  __/ | | | (_| |  __/ | | | (__| |  __/\__ \ #
#  \__,_|\___| .__/ \___|_| |_|\__,_|\___|_| |_|\___|_|\___||___/ #
#            |_|                                                  #
###################################################################
platform_size="$(cat /sys/firmware/efi/fw_platform_size)"
if [[ "${platform_size}" != "64" ]] && [[ "${platform_size}" != "32" ]]; then
    echo "[ This script requires the UEFI boot mode. ]"
    exit 0
fi
if ! ping -c 1 archlinux.org > /dev/null; then
    echo "[ This script requires the internet. Use 'iwd' for Wifi. ]"
    exit 0
fi
if [[ $(timedatectl show -p NTPSynchronized --value) != "yes" ]]; then
    echo "Setting NTP sync to true..."
    if ! timedatectl set-ntp true; then
        echo "[ Failed to set NTP sync to true (Sync clock). ]"
        exit 1
    fi
fi
if ! command -v fzf > /dev/null; then
    echo "Installing 'fzf'..."
    if ! sudo pacman -Sy fzf --noconfirm > /dev/null; then
        echo "[ Failed to install 'fzf'. ]"
        exit 1
    fi
fi
# drive - re order to arch wiki in order of "first needed"
working_drive="$(lsblk -ndo path,size | fzf --prompt "Select drive: " | awk '{print $1}')"
if [[ "${working_drive}" =~ "nvme" ]]; then
    working_drive_suffix="p"
else
    working_drive_suffix=""
fi
# username
while true; do
    read -p "Enter username: " username_var
    case "${username_var}" in
        "" )
            echo "Can not be blank."
            ;;
        *[!a-zA-Z0-9]* )
            echo "No special characters."
            ;;
        *[a-zA-Z0-9]* )
            break
            ;;
    esac
done
# password
while true; do
    read -s -p "Enter password: " password_var && echo
    read -s -p "Enter password: " password_var_confirm && echo
    case "${password_var}" in
        "" )
            echo "Can not be blank."
            ;;
        "${password_var_confirm}" )
            break
            ;;
        * )
            echo "Passwords do not match."
            ;;
    esac
done
# timezone
timezone_var="$(timedatectl list-timezones | fzf --prompt "Select timezone: " --query "$(timedatectl show -p Timezone --value)")"
cpu_vendor="$(grep /proc/cpuinfo -e "vendor_id" | head --line 1 | awk '{print $3}')"
#hostname
while true; do
    read -p "Enter hostname: " hostname_var
    case "${hostname_var}" in
        "" )
            echo "Can not be blank."
            ;;
        *[!a-zA-Z0-9]* )
            echo "No special characters."
            ;;
        *[a-zA-Z0-9]* )
            break
            ;;
    esac
done


##############################################
#                   _   _ _   _              #
#  _ __   __ _ _ __| |_(_) |_(_) ___  _ __   #
# | '_ \ / _` | '__| __| | __| |/ _ \| '_ \  #
# | |_) | (_| | |  | |_| | |_| | (_) | | | | #
# | .__/ \__,_|_|   \__|_|\__|_|\___/|_| |_| #
# |_|                                        #
##############################################
while true; do
    read -p "This will IRREVERSIBLY wipe ${working_drive}. Continue (y/N)?" response
    case "${response}" in
        [Yy]* )
            break
            ;;
        [Nn]* )
            exit 0
            ;;
        * )
            exit 0
            ;;
    esac
done
sgdisk --zap-all "${working_drive}"
sgdisk --new=1:0:+1G --change-name=1:"boot" --typecode=1:ef00 "${working_drive}"
sgdisk --new=2:0:+4G --change-name=2:"swap" --typecode=2:8200 "${working_drive}"
sgdisk --new=3:0:0 --change-name=3:"root" --typecode=3:8300 "${working_drive}"


########################################
#   __                            _    #
#  / _| ___  _ __ _ __ ___   __ _| |_  #
# | |_ / _ \| '__| '_ ` _ \ / _` | __| #
# |  _| (_) | |  | | | | | | (_| | |_  #
# |_|  \___/|_|  |_| |_| |_|\__,_|\__| #
#                                      #
########################################
mkfs.fat -F32 "${working_drive}${working_drive_suffix}1"
mkswap "${working_drive}${working_drive_suffix}2"
mkfs.ext4 "${working_drive}${working_drive_suffix}3"


#####################################
#                              _    #
#  _ __ ___   ___  _   _ _ __ | |_  #
# | '_ ` _ \ / _ \| | | | '_ \| __| #
# | | | | | | (_) | |_| | | | | |_  #
# |_| |_| |_|\___/ \__,_|_| |_|\__| #
#                                   #
#####################################
mount "${working_drive}${working_drive_suffix}3" /mnt
mount -m "${working_drive}${working_drive_suffix}1" /mnt/boot
swapon "${working_drive}${working_drive_suffix}2"


##############################################
#                       _                    #
#  _ __   __ _  ___ ___| |_ _ __ __ _ _ __   #
# | '_ \ / _` |/ __/ __| __| '__/ _` | '_ \  #
# | |_) | (_| | (__\__ \ |_| | | (_| | |_) | #
# | .__/ \__,_|\___|___/\__|_|  \__,_| .__/  #
# |_|                                |_|     #
##############################################
reflector --latest 6 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
case "${cpu_vendor}" in
    "GenuineIntel" )
        pacstrap -K /mnt intel-ucode
        ;;
    "AuthenticAMD" )
        pacstrap -K /mnt amd-ucode
        ;;
    * )
        echo "Could not determine microcode. Skipping."
        ;;
fi
pacstrap -K /mnt base linux-lts linux-firmware bash-completion base-devel vim networkmanager grub efibootmgr


############################
#   __     _        _      #
#  / _|___| |_ __ _| |__   #
# | |_/ __| __/ _` | '_ \  #
# |  _\__ \ || (_| | |_) | #
# |_| |___/\__\__,_|_.__/  #
#                          #
############################
genfstab -U /mnt >> /mnt/etc/fstab


####################################
#       _                     _    #
#   ___| |__  _ __ ___   ___ | |_  #
#  / __| '_ \| '__/ _ \ / _ \| __| #
# | (__| | | | | | (_) | (_) | |_  #
#  \___|_| |_|_|  \___/ \___/ \__| #
#                                  #
####################################
arch-chroot /mnt << EOF
# ---- time ----
ln -sf "/usr/share/zoneinfo/${timezone_var}" /etc/localtime
hwclock --systohc


# ---- localization ----
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen


# ---- network ----
echo "${hostname_var}" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 ${hostname_var}" >> /etc/hosts


# ---- user ----
groupadd libvirt
useradd -m -G wheel,libvirt -s /bin/bash "${username_var}"
echo "${username_var}:${password_var}" | chpasswd
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers


# ---- grub ----
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg


# ---- services ----
systemctl enable NetworkManager.service
EOF


############################
#      _                   #
#   __| | ___  _ __   ___  #
#  / _` |/ _ \| '_ \ / _ \ #
# | (_| | (_) | | | |  __/ #
#  \__,_|\___/|_| |_|\___| #
#                          #
############################
exit
umount -R /mnt
clear
read -p "Press enter to reboot..."
reboot


# EOF
