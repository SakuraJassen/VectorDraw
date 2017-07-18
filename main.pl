#!/usr/bin/perl
use strict;
use warnings;

use GD;
use GD::Image;
use Time::HiRes;
use Time::Stopwatch;
use Getopt::Long;
use Data::Dumper;

use constant RIGHT => 0;
use constant DOWN => 1;
use constant LEFT => 2;
use constant UP => 3;

#Console Params
my $filename = undef;
my $frameCnt = undef;
my $height = 500;
my $width = 500;
my $randomCnt = -1;
my $rainbow;
my $slurp;
GetOptions("f=s" => \$filename,
    "w=s" => \$width,
    "h=s" => \$height,
    "random=s" => \$randomCnt,
    "frame=s" => \$frameCnt,
    "r" => \$rainbow,
    "slurp" => \$slurp) or die("Error in arguments\n");

#stats
my $totalFrames = 0;
tie my $time, 'Time::Stopwatch';

#cursor
my $x = -1;
my $y = -1;

#logic
my $colorPalette = [] if($rainbow);
my $maxColor = int(rand(10))+10 if($rainbow);
my $offSetX = 0;
my $offSetY = 0;

#Rainbow setup
if($rainbow) {
    for (0..$maxColor) {
        push @$colorPalette, int(rand(5))+2;
    }
}

# create a new image
my $frame = new GD::Image($width, $height);

#Allocating Colors
$frame->colorAllocate(0,0,0);
my $r = $frame->colorAllocate(255,0,0);
my $g = $frame->colorAllocate(0,255,0);
my $b = $frame->colorAllocate(0,0,255);

#Begin Animation
my $gifdata = $frame->gifanimbegin(1,-1);

#Read Positions from Allfiles in 'sketch'
my $pos = [];
if(defined($slurp)) {
    $filename = readDir();
}

#Read Positions from File
if(defined($filename)) {
    foreach my $file (split(/ *, */, $filename)) {
        open(my $fh, '<:encoding(UTF-8)', './sketch/'.$file)
        or die "Could not open file '$file' $!";
        my $moveToNext = undef;
        while (my $row = <$fh>) {
            chomp $row;
            while($row =~ s/(#?)(\d+) *(\d+) *((?:=>)?)//){
                next if(defined($1) && $1 eq '#');
                next unless(defined($1) || defined($2) || defined($3) || defined($4));

                push @$pos, {option => defined($moveToNext) ? '' : 'm', x => $2, y => $3};

                $moveToNext = undef;
                $moveToNext = 1 if($4 eq '=>');
            }
        }
    }
}

#
#for (0..$randomCnt) {
#    push @$pos, {x => int(rand($width)), y => int(rand($height)), option => (int(rand(4)) == 1 ? 'm' : '')};
#}

#Loop through all Position and Draw
my $count = 0;
foreach my $x (@$pos) {
    moveTo(pos => $x, draw => 0);
    $gifdata .= $frame->gifanimadd(0, 0, 0, 2);
    $totalFrames++;
    $count++;
}

print "Toke $time seconds for $totalFrames frames\n";
print "Total run Time is ", ($totalFrames*20)/1000, " sec\n";

#Finish up the animation
$gifdata .= $frame->gifanimadd(0, 0, 0, 2);
$gifdata .= $frame->gifanimend;

#Save to file
open my $file, '>', './out/out.gif';
binmode $file;
print $file $gifdata;
close $file;

open $file, '>', './out/prev.png';
binmode $file;
print $file $frame->png();
close $file;

sub move {
    my %params  = (
        dir => undef,
        @_
    );

    if($params{dir} == 0){
        # RIGHT => 0;
        $x++;
    } elsif ($params{dir} == 1) {
        # DOWN => 1;
        $y++;
    } elsif ($params{dir} == 2) {
        # LEFT => 2;
        $x--;
    } elsif ($params{dir} == 3) {
        # UP => 3;
        $y--;
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

    if((defined($params{cycle}) && defined($frameCnt) && $params{cycle} % $frameCnt == 0 )) {
        $gifdata .= $frame->gifanimadd(0, 0, 0, 2);
        $totalFrames++;
    }
}

sub readDir {
     my %params  = (
        dir => 'sketch',
        @_
    );

    my $filename = "";
    my $first = undef;
    my $directory = './'.$params{dir};

    opendir (DIR, $directory) or die $!;
    while (my $file = readdir(DIR)) {
        next if ($file =~ m/^\./);

        $filename = $file unless(defined($first));
        $filename .= ", ".$file if(defined($first));
        $first = 1;
    }
    closedir(DIR);

    return $filename;
}