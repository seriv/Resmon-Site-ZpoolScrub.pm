# Resmon-Site-ZpoolScrub.pm
Site::ZpoolScrub - return scrub statistics

This is a perl module for resmon to query zpool scrub statistics.

```zpool status``` command gives current state of zpool scrub processes, but this data is usually pretty valuable for trending and notifying purposes. For example, not updated in timely manner DELL Perc controllers and disks firmware caused zfs to be practically unusable. Awful hardware, even in JBOD mode, tried to retry each failure until system IO operation failed, thus gererating zombie processes. We found the best predictor of such failure would be successful zpool scrub completion times. 

