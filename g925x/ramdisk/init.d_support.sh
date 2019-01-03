#!/system/bin/sh

on property:sys.boot_completed=1
    start init_d

service init_d /sbin/init_d.sh
    class late_start
    user root
    seclabel u:r:init:s0
    oneshot
    disabled
