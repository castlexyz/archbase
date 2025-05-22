#!/bin/bash


sudo clear # for sudo


###################################################################
#      _                           _                 _            #
#   __| | ___ _ __   ___ _ __   __| | ___ _ __   ___(_) ___  ___  #
#  / _` |/ _ \ '_ \ / _ \ '_ \ / _` |/ _ \ '_ \ / __| |/ _ \/ __| #
# | (_| |  __/ |_) |  __/ | | | (_| |  __/ | | | (__| |  __/\__ \ #
#  \__,_|\___| .__/ \___|_| |_|\__,_|\___|_| |_|\___|_|\___||___/ #
#            |_|                                                  #
###################################################################
if ! command -v pacman; then
    echo "! This script must be ran on arch-linux"
    exit 1
fi


platform_size="$(cat /sys/firmware/efi/fw_platform_size)"
if [[ "${platform_size}" != "64" ]] && [[ "${platform_size}" != "32" ]]; then
    echo "! This script requires the UEFI boot mode"
    exit 1
fi


if ! ping -c 1 archlinux.org > /dev/null; then
    echo "! This script requires the internet (use 'iwd' for wifi)"
    exit 1
fi


if [[ "$(timedatectl show -p NTPSynchronized --value)" != "yes" ]]; then
    echo "> Setting 'NTP sync' to 'true'"
    timedatectl set-ntp true
    if [ "${?}" -ne 0 ]; then
        exit 1
    fi
fi


if ! command -v fzf > /dev/null; then
    echo "> Installing 'fzf'"
    sudo pacman -Sy fzf --noconfirm
    if [ "${?}" -ne 0 ]; then
        exit 1
    fi
fi


working_drive="$(lsblk -ndo path,size | fzf --reverse --prompt "Select drive: " | awk '{print $1}')"
wipe_drive_resonse=$(echo -e "Exit\nIRREVERSIBLY wipe '${working_drive}'" | fzf --reverse --prompt "Select option: ")
if [[ "${wipe_drive_resonse}" != "IRREVERSIBLY wipe '${working_drive}'" ]]; then
    exit 1
fi
if [[ "${working_drive}" =~ "nvme" ]]; then
    working_drive_suffix="p"
else
    working_drive_suffix=""
fi
if [ -z "${working_drive}" ]; then
    echo "! No drive selected"
    exit 1
fi
clear


while true; do
    read -p "Enter username: " username_var && echo
    clear
    case "${username_var}" in
        "")
            echo "! Can not be blank"
            ;;
        *[!a-zA-Z0-9]*)
            echo "! No special characters"
            ;;
        *[a-zA-Z0-9]*)
            break
            ;;
    esac
done
if [ -z "${username_var}" ]; then
    echo "! No username provided"
    exit 1
fi
clear


while true; do
    read -p "Enter password: " password_var
    clear
    read -p "Confirm password: " password_var_confirm
    clear
    case "${password_var}" in
        "")
            echo "! Can not be blank"
            ;;
        "${password_var_confirm}")
            break
            ;;
        *)
            echo "! Passwords do not match"
            ;;
    esac
done
if [ -z "${password_var}" ]; then
    echo "! No password provided"
    exit 1
fi
clear


while true; do
    read -p "Enter hostname: " hostname_var
    clear
    case "${hostname_var}" in
        "")
            echo "! Can not be blank"
            ;;
        *[!a-zA-Z0-9]*)
            echo "! No special characters"
            ;;
        *[a-zA-Z0-9]*)
            break
            ;;
    esac
done
if [ -z "${hostname_var}" ]; then
    echo "! No hostname provided"
    exit 1
fi
clear


timezone_var=$(echo -e "$(timedatectl show -p Timezone --value)\nOther" | fzf --reverse --prompt "Select timezone: ")
if [[ "${timezone_var}" == "Other" ]]; then
    timezone_var=$(timedatectl list-timezones | fzf --reverse --prompt "Select timezone: ")
fi
if [ -z "${timezone_var}" ]; then
    echo "! Could not determine timezone"
    exit 1
fi
clear


cpu_vendor="$(grep /proc/cpuinfo -e "vendor_id" | head --line 1 | awk '{print $3}')"
case "${cpu_vendor}" in
    "GenuineIntel")
        ucode_package="intel-ucode"
        ;;
    "AuthenticAMD")
        ucode_package="amd-ucode"
        ;;
    *)
        echo "! Could not determine microcode"
        exit 1
        ;;
esac
clear


working_drive_text="Working drive: ${working_drive}"
echo "${working_drive_text}"
printf "%${#working_drive_text}s\n" | tr " " "-"
echo "CPU Vendor: ${cpu_vendor}"
echo "Username: ${username_var}"
echo "Password: ${password_var}"
echo "Hostname: ${hostname_var}"
echo "Timezone: ${timezone_var}"


read -p "Is this correct (y/N)?: " confirm_info_response
case "${confirm_info_response}" in
    [Yy]*)
        # continue
        ;;
    *)
        exit 0
        ;;
esac


##############################################
#                   _   _ _   _              #
#  _ __   __ _ _ __| |_(_) |_(_) ___  _ __   #
# | '_ \ / _` | '__| __| | __| |/ _ \| '_ \  #
# | |_) | (_| | |  | |_| | |_| | (_) | | | | #
# | .__/ \__,_|_|   \__|_|\__|_|\___/|_| |_| #
# |_|                                        #
##############################################
sgdisk --zap-all "${working_drive}"
sgdisk --new=1:0:+1G --change-name=1:"boot" --typecode=1:ef00 "${working_drive}"
sgdisk --new=2:0:+2G --change-name=2:"swap" --typecode=2:8200 "${working_drive}"
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
echo "> Running 'reflector'"
reflector --latest 6 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacstrap -K /mnt \
base \
base-devel \
bash-completion \
efibootmgr \
grub \
linux-firmware \
linux-lts \
linux-lts-headers \
networkmanager \
vim \
"${ucode_package}"


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
sudo locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf


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
umount -R /mnt
reboot
