#!/bin/sh
# (c) 2017,2018 Gautam Mani <execve@gmail.com>
# Backup all the key configuration of a system - both system and user specific
# and compress and encrypt using gpg. This could be then backed up off-site for
# safe-keeping. This could also be backed up automatically on a weekly or daily
# basis using the periodic configuration -- weekly_local or daily_local in
# /etc/periodic.conf or /etc/periodic.conf.local. Earlier versions were compatible
# with Ubuntu; but now this is only tested with FreeBSD
# 
# TODO:
#	+ configure disks from the user and create gpart disk backups
# 	+ Add some zfs details

MYUSER="gautam"
GPGKEY="0x679D8D13"

PATH=$PATH:/usr/sbin:/usr/local/bin:/usr/bin
# command to list installed packages
PKGVER_CMD="pkg info"
PARTSHOW_CMD="gpart show"
# gpg
GPG="gpg --homedir /root/.gnupg"
# configure system dirs to backup here
SYSFILES2BAK="/etc/resolv.conf /etc/hosts /etc/fstab  /etc/rc.conf /etc/periodic.conf /etc/periodic.conf.local /etc/crontab /boot/loader.conf /etc/sysctl.conf "
# configure system files to backup here
SYSDIRS2BAK="/etc /usr/local/etc /var/cron/tabs "
# users who should be backed up
USERS2BAK="root $MYUSER"
# directories of users which should be backed up
USERDIRS2BAK=".ssh .gnupg .mutt .vim .scid bin .tarsnap "
# files of users which should be backed up
USERFILES2BAK=".bashrc .bash_profile .bash_logout .profile .cshrc .vimrc .gitconfig .mail_aliases .bash_aliases .tmux.conf .muttrc .screenrc .xscreensaver .zshrc .zprofile "
TMPBACKUP=`mktemp -d /tmp/mkbackup_XXXXXXXX`
FINALBAKDIR=/var/backups
BAKFNAME=mkbackup
DEBUG=0
MKBACKUPVER="0.2a"

umask 077

log()
{ 
if [ $DEBUG -eq 1 ]; then
	echo $*
fi
}

cleanup()
{
	log cleaning up temp dir
	# cleanup
	umount $TMPBACKUP
	rm -rf $TMPBACKUP	
	exit 1
}

echo "Backup (v$MKBACKUPVER) started: " `date`
mkdir -p "$TMPBACKUP"
if [ "$?" -ne "0" ]; then
	logger -- "$0: Unable to create $TMPBACKUP"
	exit 1;
fi

log mounting $TMPBACKUP on tmpfs

mount -t tmpfs tmpfs "$TMPBACKUP" 
if [ "$?" -ne "0" ]; then
	logger -- "$0: Unable to mount tmpfs $TMPBACKUP"
	exit 2;
fi

trap "cleanup" INT TERM EXIT QUIT
##trap "umount $TMPBACKUP; rm -rf $TMPBACKUP" INT TERM EXIT QUIT

# copy the backup script itself!
cp -f $0 "$TMPBACKUP"/.

# df
log running df
df -h > "$TMPBACKUP"/dfs

# mount
log running mount
mount > "$TMPBACKUP"/mounts

mkdir -p "$TMPBACKUP"/sys "$TMPBACKUP"/users

log running pkg and gpart info 
${PKGVER_CMD} > "$TMPBACKUP"/pkg.lst
# only for FreeBSD
pkg query -a '%n:%v:%a' | grep 0$ > "$TMPBACKUP"/pkgauto-FBSD.lst
${PARTSHOW_CMD} > "$TMPBACKUP"/parted.lst

log "sysfiles..."
# now sysfiles to backup/sys
for i in $SYSFILES2BAK; do
	if [ -f "$i" ]; then
		cp "$i" "$TMPBACKUP"/sys/.
	fi
done

log "sysdirs..."
# now sysdirs to backup/sys
for i in $SYSDIRS2BAK; do
	log "checking $i"
	if [ -d "$i" ]; then
		mkdir -p "$TMPBACKUP"/sys/"$i"
		cp -R "$i/." "$TMPBACKUP"/sys/"$i"/.
	fi
done

log "userdirs..."
# now user dirs to backup/sys
for i in $USERS2BAK; do
	USERHOMEDIR=`grep ^$i /etc/passwd | cut -d: -f 6`
	cd $USERHOMEDIR
	USERDIR="$TMPBACKUP"/users/"$USERHOMEDIR"
	mkdir -p "$USERDIR"
	for j in $USERDIRS2BAK; do
		if [ -d "$j" ]; then
			mkdir -p "$USERDIR"/"$j"
			cp -R "$j/." "$USERDIR"/"$j"/.
		fi
	done
	for j in $USERFILES2BAK; do
		if [ -f "$j" ]; then
			cp "$j" "$USERDIR"/.
		fi
	done
done

cd "$FINALBAKDIR"

# Rotation - 5 is the hard-coded limit
if [ -f $FINALBAKDIR/$BAKFNAME".bz2".4 ]; then
	mv -f $FINALBAKDIR/$BAKFNAME".bz2".4 $FINALBAKDIR/$BAKFNAME".bz2".5 
fi
if [ -f $FINALBAKDIR/$BAKFNAME".bz2".3 ]; then
	mv -f $FINALBAKDIR/$BAKFNAME".bz2".3 $FINALBAKDIR/$BAKFNAME".bz2".4 
fi
if [ -f $FINALBAKDIR/$BAKFNAME".bz2".2 ]; then
	mv -f $FINALBAKDIR/$BAKFNAME".bz2".2 $FINALBAKDIR/$BAKFNAME".bz2".3 
fi
if [ -f $FINALBAKDIR/$BAKFNAME".bz2".1 ]; then
	mv -f $FINALBAKDIR/$BAKFNAME".bz2".1 $FINALBAKDIR/$BAKFNAME".bz2".2 
fi
if [ -f $FINALBAKDIR/$BAKFNAME".bz2" ]; then
	mv -f $FINALBAKDIR/$BAKFNAME".bz2"   $FINALBAKDIR/$BAKFNAME".bz2".1 
fi

tar -C "$TMPBACKUP" -cf - . | $GPG -e -r $GPGKEY | bzip2 > "$FINALBAKDIR"/$BAKFNAME".bz2"

#cleanup the tmp backup dir
echo "Backup finished: " `date`
