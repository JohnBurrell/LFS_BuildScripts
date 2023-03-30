Here is the recipe to use these scripts:

** NOTE ** The scripts are set up to install LFS with systemd. You can set SYSTEMD in the config menu to no in order to install the sysv version, but this has not been thoroughly tested so will probably fail.

First ensure you have these installed on your host:
vim, bison, patch, gawk, dialog, git, texinfo, libxml2, xsltproc, libxml2-utils, tidy, wget, python-beautifulsoup4, docbook-xml and docbook-xsl.
You can also customize the dialog menus by using a .dialogrc file in your root dir.
go to: bash.cyberciti.biz/guide/Dialog_customization_with_configuration_file
If you need the dialog source, it is here: ftp://invisible-island.net/dialog
- use the tar.gz version.

1. create your partitions. I suggest you do:
mkfs.ext4 -jv /dev/sda(x) for all of them - plus mkswap -v /dev/sda(x) or you can edit createFSparts.sh and run that. createFSparts.sh is useful if you have nvme ssd(s) on your machine.

2. Edit chapter02.sh to match your partitions and run the script
3. Same with chapter03.sh

4. Copy the file pkguser.tar.xz to $LFS/sources or edit chapter04.sh and run it.
If you don't want to use this name for the package user data, you can change the name in the config setup. It should be a compressed tarball of some description though containing all the files that are currently in pkguser.tar.xz.

5. Run lfsa from your host. Make sure you have already done: export LFS=/mnt/lfs 

6. Create a lfs user as per the book. Don't forget to set up the lfs environment too. Do: echo $LFS_TGT and make sure something sensible is returned.

7. Run lfsa as root.  Edit the config file to suit your requirements. If requested, the sources will be downloaded, the requested LFS book git cloned and you should create the following scripts in $LFS - chapter05.sh, chapter06.sh, chapter07-asroot.sh, chapter07-chroot.sh, chapter07.sh and chapter08.sh. I tried to get lfsa to make all the scripts in one go by setting WHICH_CHAPTER=all, but it's currently broken so you will have to create the scripts one at a time.

** NOTE ** The book is downloaded to /root/LFS_GIT/LFS/<BOOK_VERSION>. By default, <BOOK_VERSION> is trunk which is the development version on the LFS website. The next time you run lfsa, make sure the BOOK_VERSION is set to local so you don't waste resources by git cloning the book again.

** NOTE ** - as of 2020/09/01, when LFS-10.0 was released, the LFS build system is completely different from the past and so these scripts will not work with any older version of LFS. In particular, these scripts allow you to use the Matthias Benkmann package-user package management system, referred to in the book. However, because the new build system doesn't rely on the /tools directory to contain all the tools necessary to build LFS, but rather places some packages in their final location during chapter05 and 06, before chrooting in chapter07, the package-users have to start to be created from the outset in chapter05. This makes it different from the previous LFS where all the tools were built in chapter05 and the package-users were created in chroot in chapter06.

You can download all the source files before you begin if you wish, but if you have a high-speed web connection I suggest that you set SOURCES=atinstall. This will download each source file when it is being installed. At the end of Chapter06, openssl and wget are installed (wget is not in the LFS book but in BLFS) which allows you to download the source files in chapter07 and chapter08. You may need to edit /mnt/lfs/etc/resolv.conf to set your nameserver correctly for this to work (usually nameserver 192.168.1.1 is sufficient).

8. Chapter 9 in the book is done by the chapter09-systemd.sh script provided here. As you can see, this is the systemd version. if you're installing the sysv version you'll have to modify the chapter09 script to suit yourself. You should be aware that these scripts have not been tested on a sysv install, so there are likely to be a few problems with them.

9. chapter10.sh creates a placeholder to build the kernel. You can add your kernel .config file to $LFS/sources at the start and say 'yes' to the MAKE_KERNEL option in order to build your kernel without your intervention. You have to select this option in the lfsa config file when you run lfsa and you may need to delete .ch10kernel in the install directory in order for it to run because this was created if you ran chapter10 when MAKE_KERNEL was set to no.
Alternatively,  follow chapter 10 from the book to install the kernel. Do su kernel to enter the kernel dir. mkproper has already been run if you ran chapter10 with MAKE_KERNEL=no. Edit the .config file with make menuconfig and run make etc. Don't forget to install the files in /boot as root.

10. I've given you an option to install everything as root rather than a package user. You might prefer to use a script to do that rather that jhalfs, but I should emphasize that these scripts were designed to install each package as a package user.

11. Just to repeat, these scripts are designed to install LFS with systemd. Select SYSTEMD=yes in the lfsa config file. If you selected SOURCES=atinstall, this will download each source tarfile at the beginning of the package installation and will also download any additional required files, such as a patch file or a man-pages tarfile (e.g.systemd).
If you select SOURCES=download, all the required systemd source files will be downloaded to /sources/<BOOK_VERSION> and then copied from there to the installation dir (by default to /usr/src/core/<package-name>) at the time of package installation.

The package-user management system uses two main scripts:-

installpkg and listdelpkg.sh

To install a new package, do: installpkg PACKAGE-NAME. 
By default the package user directory is created under /usr/src/core. You can change it - just edit installpkg in /usr/sbin/. You can also do: 
installpkg PACKAGE-NAME INSTALL_DIR to override the default dir.

Additionally, you can do: installpkg PACKAGE-NAME INSTALL_DIR UID
to specify the user id number. By default the uid starts at 10000 and increments with each package added. You can override this by specifying the uid. This is useful for packages such as apache and avahi which have suggested uids in the blfs book, when you get to BLFS.

listdelpkg.sh will list all files belonging to a PACKAGE-USER and will allow you to delete all those files. Obviously, before you delete a package, list all the files first to see which ones will be removed.

To list files for a package do: listdelpkg.sh <PACKAGE_USER>
To delete files for a package do: listdelpkg.sh <PACKAGE_USER> <PACKAGE_USER> delete
Or to delete any install directories for a package do:
listdelpkg.sh <PACKAGE_USER> install delete

Finally, by default the tests are not run. If you wish to run them, set TESTS=yes in the lfsa config file. ** WARNING ** - running the tests has not been tested ;) so will probably be buggy.
