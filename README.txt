Script to make custom debian live ISO. Use at your own risk!

Usage:
  make_deb_live_iso.sh NAME
It will make ${NAME}.mdli.iso in current dir

Must be executed with root permissions

Following packages must be installed in your system to make script works:
   debootstrap                  -- to make basic debian install.=
   squashfs-tools               -- to save some space. Common practice
   xorriso                      -- this will make our ISO
   isolinux                     -- to boot our image
   syslinux-efi		        -- same
   grub-pc-bin		    	-- to boot on legacy BIOS machines. Who still use them?
   grub-efi-amd64-bin		-- to boot on modern (U)EFI machines, 64-bit
   grub-efi-ia32-bin		-- same for 32-bit
   mtools		        -- to work with FAT boot partition
   dosfstools		      	-- to make FAT boot partition
Please, install them BEFORE

Files which participate in process
   ${NAME}.mdli.config          -- here you MUST place some config vars. It must be source-able. Nothing will happens if no file provided
   ${NAME}.mdli.pckgs           -- here you COULD place list of additional packages to be installed in your live image. One per line in apt format. Blank line in the end
   ${NAME}.mdli.files.tar.gz    -- here you COULD place some files which will be placed in your live image. Script will extract it in /. So keep paths accordingly
   ${NAME}.mdli.script          -- here you COULD place any post-install scripts you want. Generate locales, create additional users, etc.	
   ${NAME}.mdli.log             -- here you WILL find log. Or in mldi.log if something went wrong on early stages
   ${NAME}.mdli.tmp             -- Working DIR where all happens. You WILL find it in case script didn't finish good. Otherwise it will delete it
   ${NAME}.mdli.iso             -- it WILL be your ISO if all goes well

See EXAMPLE dir for... example. There I will install some additional software, provide nice wllpaper in files/resources and config openbox to use it.

Good luck!
