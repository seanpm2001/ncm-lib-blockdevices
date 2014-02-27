object template factory1;

# keep BlockDevices happy
"/system/network/hostname" = 'x';
"/system/network/domainname" = 'y';

"/hardware/harddisks/sdb" = nlist(
    "capacity", 4000, 
);

"/system/blockdevices" = nlist (
	"physical_devs", nlist (
		"sdb", nlist ("label", "gpt")
		),
	"partitions", nlist (
		"sdb1", nlist (
			"holding_dev", "sdb",
			"size", 100,
			"type", "primary", # no defaults !
			),
        "sdb2", nlist (
            "holding_dev", "sdb",
            "size", 100,
            "type", "primary", # no defaults !
            ),
        "sdb3", nlist (
            "holding_dev", "sdb",
            "size", 3500,
            "type", "extended",
            ),
        "sdb5", nlist (
            "holding_dev", "sdb",
            "type", "logical",
            "size", 1024,
            ),
        ),
	"volume_groups", nlist (
		"vg0", nlist (
			"device_list", list ("partitions/sdb1"),
			)
		),
	"md", nlist (
		"md0", nlist (
			"device_list", list ("partitions/sdb1"),
			"raid_level", "RAID0",
			"stripe_size", 64,
			)
		),
	"files", nlist (
		escape ("/home/mejias/kk.ext3"), nlist (
			"size", 400,
			"owner", "mejias",
			"group", "users",
			"permissions", 0600
			)
		),
	"logical_volumes", nlist (
		"lv0", nlist (
			"size", 800,
			"volume_group", "vg0"
			),
		)
	);
		
