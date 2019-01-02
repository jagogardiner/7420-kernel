#!/system/bin/sh

on property:sys.boot_completed=1
    start initd

service initd /sbin/initd.sh
    class late_start
    user root
    seclabel u:r:init:s0
    oneshot
    disabled
