#!/bin/bash

# Script to make custom debian live ISO. Use at your own risk!

# Usage:
#   make_deb_live_iso.sh NAME
# It will make ${NAME}.mdli.iso in current dir

# Must be executed with root permissions

# Following packages must be installed in your system to make script works:
#   debootstrap			-- to make basic debian install.=
#   squashfs-tools		-- to save some space. Common practice
#   xorriso			-- this will make our ISO
#   isolinux			-- to boot our image
#   syslinux-efi		-- same
#   grub-pc-bin			-- to boot on legacy BIOS machines. Who still use them?
#   grub-efi-amd64-bin		-- to boot on modern (U)EFI machines, 64-bit
#   grub-efi-ia32-bin		-- same for 32-bit
#   mtools			-- to work with FAT boot partition
#   dosfstools			-- to make FAT boot partition
# Please, install them BEFORE

# Files which participate in process
#   ${NAME}.mdli.config		-- here you MUST place some config vars. It must be source-able. Nothing will happens if no file provided
#   ${NAME}.mdli.pckgs		-- here you COULD place list of additional packages to be installed in your live image. One per line in apt format
#   ${NAME}.mdli.files.tar.gz	-- here you COULD place some files which will be placed in your live image. Script will extract it in /
#   ${NAME}.mdli.script		-- here you COULD place any post-install scripts you want. Generate locales, create additional users, etc.	
#   ${NAME}.mdli.log		-- here you WILL find log. Or in mldi.log if something went wrong on early stages
#   ${NAME}.mdli.tmp		-- Working DIR where all happens. You WILL find it in case script didn't finish good. Otherwise it will delete it
#   ${NAME}.mdli.iso		-- it WILL be your ISO if all goes well

# Good luck!


#### This functions will help us to log events and errors

function log_it () {
	echo "$1" | tee -a ${LOG_FILE}
}


function check_err () {
	if [ ! $? -eq 0 ]; then
		log_it "ERR: Something went wrong:"
		cat ${ERR_LOG} | tee -a ${LOG_FILE}
		rm ${ERR_LOG}
		exit 1
	fi
}


function check_err_no_exit () {
	if [ ! $? -eq 0 ]; then
		log_it "ERR: Something went wrong:"
		cat ${ERR_LOG} | tee -a ${LOG_FILE}
		rm ${ERR_LOG}
	fi
}


#### Create clean temp log file, start logging

LOG_FILE="$(pwd)/mdli.log"
ERR_LOG="$(pwd)/err.log"
echo "=== BEGIN === $(date)" | tee ${LOG_FILE}


#### Check if only one parameter is given and if config file exists
# TBD: more intellectual checks, regexp and so son

log_it "III: Checking for mandatory parameter..."

if [ -z "$1" ]; then
	log_it "ERR: There is no mandatory parameter!"
	exit 1
fi

if [ ! -z "$2" ]; then
	log_it "ERR: Too many parameters! What are you trying to do?"
	exit 1
fi

log_it "III: Parameter seems to be OK"

# Once parameter is OK, then we can use well-named log file instead of temp
WORK_DIR=$(pwd)/${1}.mdli.tmp
mkdir "${WORK_DIR}"
LOG_FILE="${WORK_DIR}/../${1}.mdli.log"
mv $(pwd)/mdli.log ${LOG_FILE}
CONFIG_FILE="${WORK_DIR}/../${1}.mdli.config"

log_it "III: Checking config file..."

if [ ! -e "$CONFIG_FILE" ]; then
	log_it "ERR: Config file <$CONFIG_FILE> not found"
	exit 1
fi

#### Read data from config file. Source is fast and dirty solution. FIXME LATER
if ! source "$CONFIG_FILE"; then
	log_it "ERR: Config file <$CONFIG_FILE> contains unappropriate data, check it"
	exit 1
fi

#### Check configuration variables taken from config file. TBD: RegExp
#   MDLI_ARCH			-- target arch: i386 or amd64
#   MDLI_BRANCH			-- type of Debian you want: stable, unstable, testing
#   MDLI_MIRROR			-- where from download packages. Use http://ftp.us.debian.org/debian/ if in doubt
#   MDLI_HOSTNAME		-- hostname for your live image
#   MDLI_ROOT_PASSWORD		-- root password, obviously

if [ -z "${MDLI_ARCH}" ]; then
	log_it "ERR: There is no mandatory MDLI_ARCH config variable!"
	exit 1
fi

if [ -z "${MDLI_BRANCH}" ]; then
	log_it "ERR: There is no mandatory DLI_BRANCH config variable!"
	exit 1
fi

if [ -z "${MDLI_MIRROR}" ]; then
	log_it "ERR: There is no mandatory MDLI_MIRROR config variable!"
	exit 1
fi

if [ -z "${MDLI_HOSTNAME}" ]; then
	log_it "ERR: There is no mandatory MDLI_HOSTNAME config variable!"
	exit 1
fi

if [ -z "${MDLI_ROOT_PASSWORD}" ]; then
	log_it "ERR: There is no mandatory DLI_ROOT_PASSWORD config variable!"
	exit 1
fi

log_it "III: Configuration file seems to be OK, but that's not for sure"


#### OK, basic checks passed, so let's proceed to the main stuff
#### First, let's make a working dir and put there basic Debian install
#### Basic Debian install is necessary and there nothing to do with it

log_it "III: Creating working dir and run debootstrap there..."

mkdir -p "$WORK_DIR"
debootstrap --arch="${MDLI_ARCH}" --variant=minbase "${MDLI_BRANCH}" \
	"${WORK_DIR}/chroot" "${MDLI_MIRROR}" \
	2>${ERR_LOG}

check_err
log_it "III: debootstrap done"


#### Set hostname

log_it "III: setting up hostname..."

echo "${MDLI_HOSTNAME}" > "${WORK_DIR}/chroot/etc/hostname" 2>${ERR_LOG}

check_err
log_it "III: Hostname was set as ${MDLI_HOSTNAME}"


#### Install some more necessities

log_it "III: Installing some more necessities..."

chroot "${WORK_DIR}/chroot" apt update 2>${ERR_LOG}

check_err

chroot "${WORK_DIR}/chroot" apt install -y --no-install-recommends \
	linux-image-${MDLI_ARCH} \
	live-boot \
	systemd-sysv \
	2>${ERR_LOG}

check_err
log_it "III: More necessities were installed sucessfully"


#### Now it's time to install your packages, one-by-one for better logging

log_it "III: Installing your packages..."

while read -r line; do
	log_it "III: Installing ${line}..."
	chroot "${WORK_DIR}/chroot" apt install -y --no-install-recommends ${line}
	check_err_no_exit
done < "${1}.mdli.pckgs"

check_err
log_it "III: Additional packages from your list installed"


#### Now it's time to put there your files/resources from ${NAME}.mdli.files.tar.gz

log_it "III: Copying your files/resources to the LIVE system..."

if [ -e "${WORK_DIR}/../${1}.mdli.files.tar.gz" ]; then
	log_it "III: Extracting your files/resources to the LIVE system..."
	cp "${WORK_DIR}/../${1}.mdli.files.tar.gz" "${WORK_DIR}/chroot"
	chroot "${WORK_DIR}/chroot" tar -xzvf "/${1}.mdli.files.tar.gz" 2>${ERR_LOG}
	check_err
	log_it "III: Extracting your files/resources to LIVE system complete"
	rm "${WORK_DIR}/chroot/${1}.mdli.files.tar.gz"
else
	log_it "III: Your files/resources file not found, scipping"
fi

check_err
log_it "III: Copying your files/resources complete"

#### Execute your config/control script ${NAME}.mdli.script inside the LIVE

log_it "III: Copying your config/control script to the LIVE system and run it..."

if [ -e "${WORK_DIR}/../${1}.mdli.script" ]; then
	log_it "III: Running your script inside live..."
	cp "${WORK_DIR}/../${1}.mdli.script" "${WORK_DIR}/chroot"
	chroot "${WORK_DIR}/chroot" bash "/${1}.mdli.script" 2>${ERR_LOG}
	check_err
	log_it "III: Script complete"
	rm "${WORK_DIR}/chroot/${1}.mdli.script"
else
	log_it "III: Your script file not found, scipping"
fi

check_err
log_it "III: Copying and running your script complete"


#### Set root password

log_it "III: Setting root password..."

chroot "${WORK_DIR}/chroot" /bin/sh -c "echo 'root:${MDLI_ROOT_PASSWORD}' | chpasswd" 2>${ERR_LOG}

check_err
log_it "III: Root password was set to ${MDLI_ROOT_PASSWORD} sucessfully"


#### Create some more dirs for boot process

log_it "III: Creating some more boot dirs..."

mkdir -p "${WORK_DIR}"/{staging/{EFI/BOOT,boot/grub/x86_64-efi,isolinux,live},tmp} 2>${ERR_LOG}

check_err
log_it "III: Some more dirs for boot process created"


#### SquashFS

log_it "III: Making Squashfs image..."

mksquashfs \
	"${WORK_DIR}/chroot" \
	"${WORK_DIR}/staging/live/filesystem.squashfs" \
	-e boot \
	2>${ERR_LOG}

check_err
log_it "III: SquashFS image done"


#### Copy kernel to live dir

log_it "III: Copying kernel to live..."

cp "${WORK_DIR}/chroot/boot"/vmlinuz-* "${WORK_DIR}/staging/live/vmlinuz"
check_err

cp "${WORK_DIR}/chroot/boot"/initrd.img-* "${WORK_DIR}/staging/live/initrd"
check_err

log_it "III: Copy kernel to live dir -- OK"


#### Make boot menu for legacy BIOS systems

log_it "III: Making boot menu for legacy BIOS systems"

cat <<'EOF' > "${WORK_DIR}/staging/isolinux/isolinux.cfg" 2>${ERR_LOG}
UI vesamenu.c32

DEFAULT linux
TIMEOUT 600

LABEL linux
  MENU LABEL Debian Live [BIOS/ISOLINUX]
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live

LABEL linux
  MENU LABEL Debian Live [BIOS/ISOLINUX] (nomodeset)
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live nomodeset
EOF

check_err
log_it "III: Make boot menu for legacy BIOS systems -- OK"


#### Make boot menu for modern UEFI systems and copy file to boot dir

log_it "III: Making boot menu for modern UEFI systems"

cat <<'EOF' > "${WORK_DIR}/staging/boot/grub/grub.cfg" 2>${ERR_LOG}
insmod part_gpt
insmod part_msdos
insmod fat
insmod iso9660

insmod all_video
insmod font

set default="0"
set timeout=30

# If X has issues finding screens, experiment with/without nomodeset.

menuentry "Debian Live [EFI/GRUB]" {
    search --no-floppy --set=root --label DEBLIVE
    linux ($root)/live/vmlinuz boot=live
    initrd ($root)/live/initrd
}

menuentry "Debian Live [EFI/GRUB] (nomodeset)" {
    search --no-floppy --set=root --label DEBLIVE
    linux ($root)/live/vmlinuz boot=live nomodeset
    initrd ($root)/live/initrd
}
EOF

check_err

cp "${WORK_DIR}/staging/boot/grub/grub.cfg" "${WORK_DIR}/staging/EFI/BOOT/" 2>${ERR_LOG}

check_err
log_it "III: Make boot menu for modern UEFI systems -- OK"


#### Some more tricks for boot process *MAGIC*

log_it "III: Some more tricks to be done..."

cat <<'EOF' > "${WORK_DIR}/tmp/grub-embed.cfg" 2>${ERR_LOG}
if ! [ -d "$cmdpath" ]; then
    # On some firmware, GRUB has a wrong cmdpath when booted from an optical disc.
    # https://gitlab.archlinux.org/archlinux/archiso/-/issues/183
    if regexp --set=1:isodevice '^(\([^)]+\))\/?[Ee][Ff][Ii]\/[Bb][Oo][Oo][Tt]\/?$' "$cmdpath"; then
        cmdpath="${isodevice}/EFI/BOOT"
    fi
fi
configfile "${cmdpath}/grub.cfg"
EOF

check_err
log_it "III: Some more tricks for boot process done"


#### Prepare Boot Loader Files

log_it "III: Preparing boot loader files..."

cp /usr/lib/ISOLINUX/isolinux.bin "${WORK_DIR}/staging/isolinux/" 2>${ERR_LOG}
check_err

cp /usr/lib/syslinux/modules/bios/* "${WORK_DIR}/staging/isolinux/" 2>${ERR_LOG}
check_err

cp -r /usr/lib/grub/x86_64-efi/* "${WORK_DIR}/staging/boot/grub/x86_64-efi/" 2>${ERR_LOG}
check_err

log_it "III: Prepare Boot Loader Files done"


#### Generate an EFI bootable GRUB image for both i386 and x64

log_it "III: Generating an EFI bootable GRUB image..."

grub-mkstandalone -O i386-efi \
	--modules="part_gpt part_msdos fat iso9660" \
	--locales="" --themes="" --fonts="" \
	--output="${WORK_DIR}/staging/EFI/BOOT/BOOTIA32.EFI" \
	"boot/grub/grub.cfg=${WORK_DIR}/tmp/grub-embed.cfg" \
	2>${ERR_LOG}
	
check_err

grub-mkstandalone -O x86_64-efi \
	--modules="part_gpt part_msdos fat iso9660" \
	--locales="" --themes="" --fonts="" \
	--output="${WORK_DIR}/staging/EFI/BOOT/BOOTx64.EFI" \
	"boot/grub/grub.cfg=${WORK_DIR}/tmp/grub-embed.cfg" \
	2>${ERR_LOG}

check_err

log_it "III: Generate an EFI bootable GRUB image -- OK"


#### Create a FAT16 UEFI boot disk image containing the EFI bootloaders

log_it "III: Creating a FAT16 UEFI boot disk image containing the EFI bootloaders..."

cd "${WORK_DIR}/staging"
dd if=/dev/zero of=efiboot.img bs=1M count=20 2>${ERR_LOG}
check_err

mkfs.vfat efiboot.img 2>${ERR_LOG}
check_err

mmd -i efiboot.img ::/EFI ::/EFI/BOOT 2>${ERR_LOG}
check_err

mcopy -vi efiboot.img \
	"${WORK_DIR}/staging/EFI/BOOT/BOOTIA32.EFI" \
        "${WORK_DIR}/staging/EFI/BOOT/BOOTx64.EFI" \
        "${WORK_DIR}/staging/boot/grub/grub.cfg" \
        ::/EFI/BOOT/ \
	2>${ERR_LOG}
check_err

log_it "III: Create a FAT16 UEFI boot disk image containing the EFI bootloaders -- OK"


#### Now it's time to create our ISO! It's a kind of magic!

log_it "III: Making ISO..."
xorriso \
	-as mkisofs \
	-iso-level 3 \
	-o "${WORK_DIR}/../${1}.mdli.iso" \
	-full-iso9660-filenames \
	-volid "DEBLIVE" \
	--mbr-force-bootable -partition_offset 16 \
	-joliet -joliet-long -rational-rock \
	-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
	-eltorito-boot \
	isolinux/isolinux.bin \
	-no-emul-boot \
	-boot-load-size 4 \
	-boot-info-table \
	--eltorito-catalog isolinux/isolinux.cat \
	-eltorito-alt-boot \
	-e --interval:appended_partition_2:all:: \
	-no-emul-boot \
	-isohybrid-gpt-basdat \
	-append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B ${WORK_DIR}/staging/efiboot.img \
	"${WORK_DIR}/staging" \
	2>${ERR_LOG}

check_err
log_it "III: ${1}.iso is done!"

log_it "=== END === $(date)"


#### Clean up after work
rm -f "${ERR_LOG}"
rm -rf "${WORK_DIR}"
echo "III: All done. Hooray!"

