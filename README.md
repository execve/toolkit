# toolkit
Toolkit - scripts. configuration etc. 

## scripts
My scripts 

Standard disclaimers apply! Use with caution - these scripts could cause your
computer to turn into a tin can!

### mkbackup.sh
Backup all the key configuration of a system - both system and user specific
and compress and encrypt using gpg. This could be then backed up off-site for
safe-keeping. This could also be backed up automatically on a weekly or daily
basis using the periodic configuration -- weekly_local or daily_local in
/etc/periodic.conf or /etc/periodic.conf.local. Earlier versions were compatible
with Ubuntu; but now this is only tested with FreeBSD
