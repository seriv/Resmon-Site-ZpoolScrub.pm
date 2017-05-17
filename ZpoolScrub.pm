package Site::ZpoolScrub;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Site::ZpoolScrub - return scrub statistics

=head1 SYNOPSIS

 Site::ZpoolScrub {
     <zpoolname>: noop
 }

or 
 Site::ZpoolScrub {
     <spoolname>: <scrub_times_hash_file>
}

=head1 DESCRIPTION

This module gives statistics of scrupb of zpool

=head1 CONFIGURATION

=over

=item check_name

The check name is the name of zpool for which statistics of scrub is checked.

=item scrub_times_hash_file

The full path of file to store time which last successful scrub command took.
Defaults to "/var/run/.resmon-status-${zpoolname}.howlong"

=back

=head1 METRICS

=over

=item <when>

When last scrub ran

=item <togo>

Expected time to finish for current scrub

=item <howlong>

how long last scrub ran

=item <repaired>

how many errors last scrub repaired

=item <errors>

how many errors last scrub failed to repair

=item <canceled>

is '1' if last scrub was canceled and '0' if not

=back

=cut
my $DATE='/usr/gnu/bin/date';
sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $zpool = $self->{check_name};
    my $statusfile = $config->{scrub_times_hash_file} || "/var/run/.resmon-status-${zpool}.howlong";
    my $oldhowlong = ( ( -r $statusfile ) ? `cat $statusfile` : 0 );
    chomp $oldhowlong;
    $oldhowlong = 0 unless $oldhowlong =~ /^[\d]+$/;
=pod
  scan: scrub repaired 0 in 78h6m with 0 errors on Tue Mar 29 00:16:48 2016
 - or - 
  scan: scrub in progress since Tue Mar 29 19:09:47 2016
    14.3G scanned out of 47.0G at 172M/s, 0h3m to go
    0 repaired, 30.42% done
=cut
    my ($when,$h,$m,$howlong,$togo,$repaired,$errors,$canceled)=(0,0,0,0,0,0,0,0);
    my $STATUSCMD = "/usr/sbin/zpool status $zpool";
    open (my $status, "-|", $STATUSCMD)or die "can't run $STATUSCMD: $!";
    while (<$status>) {
      if (/^\s*scan:\s+scrub\s+canceled\s+on\s+(.+)$/){
        $when = $1;
        $when = `$DATE '+%s'` - `$DATE '+%s' -d "$when"`; 
        $when = int(($when+30)/60);
        $canceled = 1;
        $howlong = $oldhowlong;
        $togo = 0;
        $repaired = 0;
        $errors = 0;
        $canceled = 1;
      }
      elsif (/^\s*scan:\s+scrub\s+repaired\s+(\d*)\s+in\s+(\d*)h(\d*)m\s+with\s+(\d*)\s+errors\s+on\s+(.+)$/){
        ($repaired,$h,$m,$errors,$when) = ($1,$2,$3,$4,$5);
        $when = `$DATE '+%s'` - `$DATE '+%s' -d "$when"`; 
        $howlong = 60*$h+$m;
        $when += 60*$howlong;
        $when = int(($when+30)/60);
        $repaired += $errors if $repaired < $errors;
        $togo = 0;
        `/usr/gnu/bin/echo -n $howlong > $statusfile` unless $howlong == $oldhowlong && (-w $statusfile);
      }
      elsif (/^\s*scan:\s+scrub\s+in\s+progress\s+since\s+(.+)$/){
        $when = $1;
        $when = `$DATE '+%s'` - `$DATE '+%s' -d "$when"`; 
        $when += 30;
        $when /= 60;
        $when = int($when);
      } 
      elsif (/^\s*\S+\s+scanned\s+out\s+of\s+\S+\s+at\s+\S+,\s+(\d+)h(\d+)m\s+to\s+go\s*$/){
        $togo = $1*60 +$2;
        $howlong = $oldhowlong;
      }
      elsif (/^\s*(\d+)\s+repaired,/){
        $repaired = $1;
      }
    }
    return {
      "when"       => [$when, "i"],
      "howlong"    => [$howlong,  "i"],
      "togo"       => [$togo, "i"],
      "repaired"   => [$repaired,  "i"],
      "errors"     => [$errors,  "i"],
      "canceled"   => [$canceled,  "i"],
    }
}

1;
