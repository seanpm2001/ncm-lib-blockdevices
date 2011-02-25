# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
################################################################################

=pod

=head1 Disk

This class describes a disk or a hardware RAID device. It is part of
the blockdevices framework.

The available fields on this class are:

=over 4

=item * devname : string

Name of the device.

=item * raid_level : string

RAID level. It only applies to hardware RAID devices.

=item * num_spares : integer

Number of hot spare drives on the RAID device. It only applies to
hardware RAID.

=item * stripe_size : integer

Size of the stripes on RAID devices. It doesn't apply to single disks.

=item * label : string

Label (type of partition table) to be used on the disk.

=cut

package NCM::Disk;

use strict;
use warnings;
use LC::Process qw (execute output);

our @ISA = qw (NCM::Blockdevices);

use constant {
	DD		=> "/bin/dd",
	PARTEDARGS	=> "-s",
	CREATE		=> "mklabel",
	GREP		=> "/bin/grep",
	GREPARGS	=> "-c",
	NOPART		=> "none",
	RCLOCAL		=> "/etc/rc.local"
};

use constant PARTED	=> qw (/sbin/parted -s --);
use constant PARTEDP	=> 'print';
use constant SETRA	=> qw (/sbin/blockdev --setra);
use constant DDARGS	=> qw (if=/dev/zero count=1);

=pod

=head2 %disks

Holds all the disk objects instantiated so far. It is indexed by Pan
path (i.e: /software/components/filesystems/blockdevices/disks/sda).

=cut

our %disks = ();

=pod

=head2 new ($path, $config)

Returns a Disk object. It receives as arguments the path in the
profile for the device and the configuration object.

Only one Disk instance per disk is created. If several partitions use
the same disk (they point to the same path) the same object is
returned.

=cut

sub new
{
	my ($class, $path, $config) = @_;
	# Only one instance per disk is allowed.
	return $disks{$path} if exists $disks{$path};
	return $class->SUPER::new ($path, $config);
}

=pod

=head2 _initialize

Where the object creation is actually done.

=cut

sub _initialize
{
	my ($self, $path, $config) = @_;
	my $st = $config->getElement($path)->getTree;
	$path =~ m(.*/([^/]+));
	$self->{devname} = $self->unescape ($1);
	$self->{raid_level} = $st->{raid_level};
	$self->{num_spares} = $st->{num_spares};
	$self->{stripe_size} = $st->{stripe_size};
	$self->{label} = $st->{label};
	$self->{readahead} = $st->{readahead};
	$disks{$path} = $self;
	return $self;
}

sub new_from_system
{
	my ($class, $dev, $cfg) = @_;

	$dev =~ m{/dev/(.*)};
	return $disks{$1} if exists $disks{$1};
	my $self = { devname	=> $1,
		     label	=> 'none'
		   };
	return bless ($self, $class);
}


# Returns the number of partitions $self holds.
sub partitions_in_disk
{
	my $self = shift;

	local $ENV{LANG} = 'C';

	my $line = output (PARTED, $self->devpath, PARTEDP);

	my @n = $line=~m/^\d\s/mg;
	$line =~ m/^Disk label type: (\w+)/m;
	return $1 eq 'loop'? 0:scalar (@n);
}

# Sets the readahead for the device.
sub set_readahead
{
	my $self = shift;

	open (FH, RCLOCAL);
	my @lines = <FH>;
	close (FH);
	chomp (@lines);
	my $re = join (" ", SETRA) . ".*", $self->devpath;
	my $f = 0;
	@lines = map {
		if (m/$re/) {
			$f = 1;
			join (" ", SETRA, $self->{readahead}, $self->devpath);
		} else {
			$_;
		}
	} @lines;
	push (@lines,
	      "# Readahead set by Disk.pm\n",
	      join (" ", SETRA, $self->{readahead}, $self->devpath))
	    unless $f;
	open (FH, ">".RCLOCAL);
	print FH join ("\n", @lines), "\n";
	close (FH);
}

=pod

=head1 Methods exposed to ncm-filesystems

=head2 create

If the disk has no partitions, it creates a new partition table in the
disk. Otherwise, it does nothing.

=cut

sub create
{
	my $self = shift;
	if ($self->partitions_in_disk == 0) {
		$self->set_readahead if $self->{readahead};
		if ($self->{label} ne NOPART) {
			execute ([PARTED, $self->devpath,
				  CREATE, $self->{label}]);
		} else {
			execute ([DD, DDARGS, "of=".$self->devpath]);
		}
		return $?;
	}
	return 0;
}

=pod

=head2 remove

If there are no partitions on $self, removes the disk instance and
allows the disk to be re-defined.

=cut

sub remove
{
	my $self = shift;
	$self->partitions_in_disk or delete $disks{"/software/components/filesystems/blockdevices/physical_devs/$self->{devname}"};
	return 0;
}

sub devpath
{
	my $self = shift;
	return "/dev/" . $self->{devname};
}

=pod

=head2 devexists

Returns true if the disk exists in the system.

=cut

sub devexists
{
	my $self = shift;
	return (-b $self->devpath);
}

=pod

=head1 Methods exposed to AII

The following methods are for AII use only. They control the
specification of the block device on the Kickstart file.

=head2 should_print_ks

Returns whether block devices on this disk should appear on the
Kickstart file. This is true if the disk has an 'msdos' label.

=cut

sub should_print_ks
{
	my $self = shift;
	return $self->{label} eq 'msdos';
}

=pod

=head2 print_ks

If the disk must be printed, it prints the related Kickstart commands.

=cut

sub print_ks
{}

=pod

=head2 clearpart_ks

Prints the Bash code to create a new msdos label on the disk

=cut

sub clearpart_ks
{
	my $self = shift;

	my $path = $self->devpath;

	print <<EOF;
fdisk $path <<end_of_fdisk
o
w
end_of_fdisk
EOF
}

sub del_pre_ks
{
}

1;
