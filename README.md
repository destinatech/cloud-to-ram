# cloud-to-ram

Sometimes when deploying an instance to clouds like AWS, Azure, Google Cloud Platform etc., it's
required that the instance have a more advanced partition table layout instead of just a single
partition for the root filesystem and nothing more.

Perhaps it's desired that the root filesystem be btrfs instead of ext4 (the default in many cases).
Or maybe said instance is configured with fast local SSD storage and a few gigabytes of swap would
be handy.

Whatever the reason, a re-installation of the instance is usually required which can be tricky
because while e.g. ext4 filesystems can be expanded online, they cannot be shrunk whilst mounted
read/write.  And that necessitates the creation of cloud-to-ram.

cloud-to-ram migrates a running, systemd-based system to RAM.  Specifically, it harnesses the ZRAM
Linux kernel module to create a compressed RAM-backed block device, creates an ext4 filesystem on the
device and then copies the entire root filesystem there.

Once finished, the old root filesystem (/oldroot) can safely be unmounted and the instance can be
re-installed using one's Linux distro-bootstrapping tool(s) of choice.

## Installation

A simple "make install" will install the script to /usr/bin.  To change the installation prefix,
to say /usr/local, simply execute "make install PREFIX=/usr/local". 

## Limitations

To migrate an instance to RAM, you'll need a trimmed-down root filesystem and enough RAM in which
to store it.  There is presently a 1.5G size limit on the ZRAM device.  This allows migrating a
root filesystem which is 1G in size on an instance with only 1G of RAM, allowing a very small
amount of wiggle room.

<!--
vim: ts=2 sw=2 et fdm=marker :
-->
