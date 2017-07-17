#!/usr/bin/perl
use strict;
use warnings;

use lib q{/www/modules/};
use lib q{www/modules/};
use GD;
use GD::Image;
use Time::HiRes;
use Time::Stopwatch;
use Getopt::Long;
use Data::Dumper;
use Term::ProgressBar 2.00;

use constant RIGHT => 0;
use constant DOWN => 1;
use constant LEFT => 2;
use constant UP => 3;

#Console Params
my $filename;
my $d = undef;
my $ySize = 500;
my $xSize = 500;
my $t = -1;
my $rainbow;
GetOptions("f=s" => \$filename,
    "d=s" => \$d,
    "x=s" => \$xSize,
    "y=s" => \$ySize,
    "t=s" => \$t,
    "r" => \$rainbow) or die("Error in arguments\n");

#stats
my $prog = 1;
my $progress = Term::ProgressBar->new( { count => 0, silent => $prog } );
$progress->minor(0);
my $next_update = 0;
my $totalFrames = 0;
tie my $time, 'Time::Stopwatch';

#cursor
my $x = -1;
my $y = -1;

#logic
my $lastDir = -1;
my $drawNextFrame = 0;
my $colorPalette = [] if($rainbow);
my $maxColor = int(rand(10))+10 if($rainbow);
my $offSetX = 0;
my $offSetY = 0;


if($rainbow) {
    for (0..$maxColor) {
        push @$colorPalette, int(rand(5))+2;
    }
}

# create a new image
my $im = new GD::Image($xSize, $ySize);
my ($width,$height) = $im->getBounds();

$im->colorAllocate(0,0,0);
my $r = $im->colorAllocate(255,0,0);
my $g = $im->colorAllocate(0,255,0);
my $b = $im->colorAllocate(0,0,255);

my $gifdata = $im->gifanimbegin(1,-1);
my $frame  = $im->clone();

$frame->colorAllocate(0,0,0);
$frame->colorAllocate(255,0,0);
$frame->colorAllocate(0,255,0);
$frame->colorAllocate(0,0,255);


my $pos = [];

if(defined($filename)) {
    foreach my $file (split(/ *, */, $filename)) {
        open(my $fh, '<:encoding(UTF-8)', './sketch/'.$file)
        or die "Could not open file '$file' $!";

        while (my $row = <$fh>) {
            chomp $row;
            $row =~ /(#?) *([a-z]*) *(-*\d+)\s*(-*\d+)/;
            next if(defined($1) && $1 eq '#');
            next unless(defined($1) && defined($2) && defined($3) && defined($4));
            push @$pos, {option => $2, x => $3, y => $4};
        }
    }
}

if($t > 0) {
    $progress = Term::ProgressBar->new( { count => scalar @$pos, silent => 0 } ) if(scalar @$pos > 0);
}
for (0..$t) {
    push @$pos, {x => int(rand($xSize)), y => int(rand($ySize)), option => (int(rand(4)) == 1 ? 'm' : '')};

}

my $count = 0;
foreach my $x (@$pos) {
    moveTo(pos => $x, draw => 0);
    $gifdata .= $frame->gifanimadd(0, 0, 0, 2);
    $totalFrames++;
    $count++;
}

print "Toke $time seconds for $totalFrames frames\n";
print "Total run Time is ", ($totalFrames*20)/1000, " sec\n";

$gifdata .= $frame->gifanimadd(0, 0, 0, 2);
$gifdata .= $frame->gifanimend;


open my $file, '>', './out/out.gif';
binmode $file;
print $file $gifdata;
close $file;

open $file, '>', './out/prev.png';
binmode $file;
print $file $frame->png();

sub move {
    my %params  = (
        dir => undef,
        @_
    );

    if($params{dir} == 0){
        # RIGHT => 0;
        $x++;
        #$x = 0 if($x > $xSize);
    } elsif ($params{dir} == 1) {
        # DOWN => 1;
        $y++;
        #$y = 0 if($y > $ySize);
    } elsif ($params{dir} == 2) {
        # LEFT => 2;
        $x--;
        #$x = $xSize if($x < 0);
    } elsif ($params{dir} == 3) {
        # UP => 3;
        $y--;
        #$y = $ySize if($y < 0);
    }
}

sub moveTo {
    my %params  = (
        pos => undef,
        draw => undef,
        @_
    );
    my $cycle = 0;

    if($params{pos}->{option} eq 'os') {
        $offSetX = $params{pos}->{x};
        $offSetY = $params{pos}->{y};
        return;
    }

    if($x == -1 && $y == -1 || $params{pos}->{option} eq 'm') {
        $x = $params{pos}->{x};
        $y = $params{pos}->{y};
        return;
    }

    $params{pos}->{x} += $offSetX;
    $params{pos}->{y} += $offSetY;
    $frame->setPixel($params{pos}->{x}, $params{pos}->{y}, $r) if defined($params{draw}); # goal

    while ($params{pos}->{x} != $x || $params{pos}->{y} != $y) {
        $cycle++;
        draw(cycle => $cycle) if (defined($params{draw}));
        if ($params{pos}->{x} < $x && defined($params{pos}->{x})) {
            move(dir => LEFT);
        } elsif ($params{pos}->{x} > $x && defined($params{pos}->{x})) {
            move(dir => RIGHT);
        }
        if ($params{pos}->{y} < $y && defined($params{pos}->{y})) {
            move(dir => UP);
        } elsif ($params{pos}->{y} > $y && defined($params{pos}->{y})) {
            move(dir => DOWN);
        }
        draw(cycle => $cycle, color => $b) if (defined($params{draw}));
    }
    draw(cycle => $cycle);
}

sub draw {
    my %params  = (
        cycle => undef,
        color => $g,
        @_
    );

    if($rainbow){
        $frame->setPixel($x, $y, $colorPalette->[($params{cycle}+int(rand(4))) % $maxColor]/2);
    }else{
        $frame->setPixel($x, $y, $params{color});
    }

    if((defined($params{cycle}) && defined($d) && $params{cycle} % $d == 0 ) || defined($drawNextFrame)) {
        $gifdata .= $frame->gifanimadd(0, 0, 0, 2);
        $totalFrames++;
        $drawNextFrame = undef;
    }
}