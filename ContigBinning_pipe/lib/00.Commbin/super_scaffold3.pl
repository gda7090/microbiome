#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use File::Basename;
use PerlIO::gzip;
use FindBin qw($Bin);
sub usage {
    die '
 Usage:perl super_scaffold.pl [OPTIONS]
 
      -f, --fsa=INPUT_FILE     input scafSeq file
      -s, --se=INPUT_FILE      SE file by soap or bwa
      
      -c, --cutoff[=INTEGER]   cutoff number,better to insert size(500)
      -i, --insert[=FILE]      set lib insertSize file to set -c,-L auto
      -x, --cutx[=INTERGER]    min support read-pair num for 2 scaffolds(0)
      -l, --cutl[=INTERGER]    min scaffold length to remain(0)
      -p, --cutpcr[=INTERGER]  cut length for pcr(100)
      -o, --outpre[=STRING]    prefix of output files(pre)
      -L, --large              for large insert size(unset)
      -B, --bwa                for se.out generated by bwa;default by soap(false)
      -a, --allreads           use all reads for scaffold relation, default only SE reads
      
      -C, --circos             don\'t remain circos config files(false)
      -P, --pcr                don\'t remain statistic datas(false)
      -D, --dot                don\'t remain dot file(false)
      -v, --verbose            output verbose information
      -?, --help               to show this message

EXAMPLE
  
  perl super_scaffold.pl -f 02.assemble/reformat.fsa -s 02.assemble/se.out -c 500 -x 10 -l 500 -p 100 -o 05.super_scaf/super -C
  perl super_scaffold.pl -f final.fa -s soap.se.gz -x 5 -c 475 -o Scafrelation
  perl super_scaffold.pl -f final.fa -s soap.lst -x 5 -i insertSize.lst -o Scafrelation
';
}
usage() unless @ARGV;
my $o_fsa = '';
#my $o_se = '';
my @o_se;                   # can input multi se file, or a file list
my $o_cutoff = 500;
my $o_cutx = 0;
my $o_cutl = 0;
my $o_cutp = 100;
my $o_outpre = 'out';
my $o_large = 0;
my $o_bwa = 0;
my $o_circos = 0;
my $o_pcr = 0;
my $o_dot = 0;
my $o_help = 0;
my $o_verbose = 0;
my $o_insert;                # Lib inserSize file: Lib_name insertSize
my $o_nobig = 0;
my $o_belist;
my $o_allreads;
Getopt::Long::Configure("no_ignore_case");
GetOptions("fsa|f=s"   =>\$o_fsa,
           "se|s=s"    =>\@o_se,
           "cutoff|c=i"=>\$o_cutoff,
           "cutx|x=i"  =>\$o_cutx,
           "cutl|l=i"  =>\$o_cutl,
           "cutpcr|p=i"=>\$o_cutp,
           "outpre|o=s"=>\$o_outpre,
           "large|L"   =>\$o_large,
           "bwa|B"     =>\$o_bwa,
           "circos|C"  =>\$o_circos,
           "pcr|P"     =>\$o_pcr,
           "dot|D"     =>\$o_dot,
           "verbose|v" =>\$o_verbose,
           "insert|i=s"=>\$o_insert,
           "nobig|N"   =>\$o_nobig,
           "belist"    =>\$o_belist,
           "allreads|a"=>\$o_allreads,
           "help|?"    =>\$o_help) or usage();

usage() if($o_help || !$o_fsa || !@o_se);
#modify by liuwenbin at 2012-7-17
#my $circos = "perl $Bin/circos-0.52/bin/circos";
my $circos = "perl /PUBLIC/software/public/Graphics/circos-0.64/bin/circos"; #modify by lsq at 20140529
my $dot = "/usr/bin/dot";
if(-s $dot){
    my $change_svg = 'perl -ne \'/<svg width=\S+\s+height=\S+/ && ($_="<svg width=\"37in\" height=\"24in\"\n");print;\'';
    $dot .= " -Tsvg $o_outpre.dot | $change_svg > $o_outpre.dot.svg
`convert $o_outpre.dot.svg $o_outpre.dot.png`";
}else{
    $dot = "/opt/rocks/bin/dot -Tpng $o_outpre.dot > $o_outpre.dot.png";
}
my %scaf;
#################### Parse Fsa File ######################################
###### Get Length and Sequence from each Scaffold or Contig ##############
$o_verbose && (print 'Parsing Fsa File...',"\n");
open FSA,$o_fsa or die $!,"\n";
!$o_large && ($o_cutoff > 1000) && ($o_large = 1);
$/ = "\>";
<FSA>;
$/ = "\n";
while(my $scaf_id = <FSA>){
    chomp $scaf_id;
	$/ = "\>";
    chomp (my $seq = <FSA>);
	$/ = "\n";
    ($scaf_id) = ($scaf_id =~ /^(\S+)/);
    $seq =~ s/\s+//g;
    my $len = length($seq);
    $scaf{$scaf_id}{len} = $len;
    $scaf{$scaf_id}{seq} = $seq;
}
$/ = "\n";
close FSA;

unless($o_circos) {
	open (IDEO,'>',$o_outpre.'.ideo') or die $!,"\n";
	print IDEO ("chr - $_ $_ 0 ",$scaf{$_}{len}-1," green\n") foreach sort keys %scaf;
	close IDEO;
}
##########################################################################

my %readpair;
my @relations;
my (%get_ins,%ins_cut);
my $fn = -1;
#################### Construct read-pair Info ############################

$o_verbose && (print 'Parsing Input SE File...',"\n");
unless($o_circos) {
    open (LINK,'>',$o_outpre.'.link') or die $!,"\n";
}
my %inserth = ($o_insert && -s $o_insert) ? split/\s+/,`awk '{print \$1,\$2}' $o_insert` : ();
if($o_belist || (@o_se == 1 && $o_se[0] !~/\.gz$/ && `perl -ne 'chomp;print ((-s \$_ || -s \"\$_.gz\") ? 1 : 0);exit;' $o_se[0]`)){
    my @new_se;
    foreach(`less $o_se[0]`){
        my @l = split;
        !(-s $l[0]) && (-s "$l[0].gz") && ($l[0] .= '.gz');
        push @new_se,$l[0];
        $l[1] && ($inserth{$l[0]} = $l[1]);
    }
    @o_se = @new_se;
}
my $org_cutoff = $o_cutoff;
my $org_large = $o_large ? 1 : 0;
my @colors = qw(blue red green orange);
foreach my $o_se (@o_se){   ###   =====>>> 
    ($o_se =~ /\.PE\./ && !$o_allreads) && next;
	($o_se =~ /\.extendedFrags\./) && next;
    $o_large = $org_large;
    $o_cutoff = $org_cutoff;
    my $bn = (split/\//,$o_se)[-1];
    if(($bn =~ /L\d+_([^_]+)\.notCombined/ || $bn =~ /L\d+_([^_]+)/) && $inserth{$1}){
        $o_cutoff = $inserth{$1};
        ($o_cutoff > 1000) && ($o_large = 1);
    }elsif($inserth{$o_se}){
        $o_cutoff = $inserth{$o_se};
        ($o_cutoff > 1000) && ($o_large = 1);
    }
    $o_nobig && $o_large && next;
    if(!$get_ins{$o_cutoff}){
        $fn++;
        $get_ins{$o_cutoff} = 1;
        $ins_cut{$fn} = $o_cutoff;
    }
($o_se =~ /\.gz$/) ? (open SE,"<:gzip",$o_se || die$!) : (open (SE,$o_se) or die $!,"\n");
my($pid,$sid,$start,$len,$stran);
my @relation;
while(<SE>) {
    if($o_bwa){   
        next if /^@/;
        my ($bit,$pos,$seq);
        ($pid,$bit,$sid,$start,$pos,$seq) = (split)[0,1,2,3,6,9];
        next if($pos eq '=' || $pos eq '*');
        next if($bit & 0x0c);
        ($len,$stran) = (length($seq),$bit & 0x0010 ? '-' : '+');
    }else {
        my $id;my $hits;
        my @line = split;
        (@line < 12) && next;
        ($id,$hits,$len,$stran,$sid,$start) = (@line)[0,3,5,6,7,8];
        next if($hits!=1);
        #($pid) = ($id =~ /(.*?)\/[12]/); #bgi soap result id.
		$pid = $id; #novogene
    }
    $scaf{$sid} || next;
#    die "can't find $sid in seq file!" unless $scaf{$sid};
    my $r = !$o_large && (($start>$scaf{$sid}{len}-$o_cutoff && $stran eq '+') || 
        ($start+$len-1<=$o_cutoff && $stran eq '-'));
    my $R = $o_large && (($start>$scaf{$sid}{len}-$o_cutoff && $stran eq '-') || 
        ($start+$len-1<=$o_cutoff && $stran eq '+'));
    unless($r || $R){
        $readpair{$pid} && (delete $readpair{$pid});
        next;
    }
    if(!$readpair{$pid}) {
        $readpair{$pid}{sid}=$sid;
        $readpair{$pid}{start}=$start;
        $readpair{$pid}{end}=$start+$len-1;
        $readpair{$pid}{strand}=$stran;
    }elsif($readpair{$pid}{sid} ne $sid || $o_allreads){ 
        unless($o_circos) {
            my $color = $readpair{$pid}{strand} eq $stran ? 0 : 1;
            $color = $colors[$color + 2*$o_large];
            print LINK "$pid $readpair{$pid}{sid} ",$readpair{$pid}{start}-1,
              ' ',$readpair{$pid}{end}-1," color=$color\n";
            print LINK "$pid $sid ",$start-1,' ',$start+$len-2," color=$color\n";
        }
        if($stran eq $readpair{$pid}{strand}) {
            my $end = $start+$len-1;
                ($sid,$start,$end,$readpair{$pid}{sid},$readpair{$pid}{start},$readpair{$pid}{end}) = 
                ($readpair{$pid}{sid},$readpair{$pid}{start},$readpair{$pid}{end},$sid,$start,$end)
            if(($sid cmp $readpair{$pid}{sid}) > 0);
                push @relation,[$sid,$readpair{$pid}{sid},'<-->',$end,
                $readpair{$pid}{end}] if(($stran eq '+' && $o_large)||($stran eq '-' && !$o_large));
                push @relation,[$sid,$readpair{$pid}{sid},'-><-',$scaf{$sid}{len}-$start+1,
                $scaf{$readpair{$pid}{sid}}{len}-$readpair{$pid}{start}+1] 
            if(($stran eq '-' && $o_large)||($stran eq '+' && !$o_large));
        } else {
            my $end = $start+$len-1;
                ($sid,$start,$end,$readpair{$pid}{sid},$readpair{$pid}{start},$readpair{$pid}{end}) = 
                ($readpair{$pid}{sid},$readpair{$pid}{start},$readpair{$pid}{end},$sid,$start,$end)
            if($stran eq '-');
                push @relation,[$sid,$readpair{$pid}{sid},'->->',$scaf{$sid}{len}-$start+1,
                 $readpair{$pid}{end}] unless($o_large);
                push @relation,[$readpair{$pid}{sid},$sid,'->->',
                 $scaf{$readpair{$pid}{sid}}{len}-$readpair{$pid}{start}+1,$end]
            if($o_large);
        }
        delete $readpair{$pid};
    }else{
        delete $readpair{$pid};
    }
}
close SE;
push @{$relations[$fn]},@relation;
}###   <<<=====
close LINK unless($o_circos);

$o_verbose && (print 'Parsing Input SE File Completed!',"\n");
#########################################################################################

######### finding out the most likely position of each scaffold #########################
my @stack;
$o_verbose && (print 'Generating Statistic Files',"\n");
foreach(@relations){
   @{$_} = sort{$a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] || $a->[2] cmp $b->[2]} @{$_};
}
unless($o_pcr) {
    open (LIST,'>',$o_outpre.'.list') or die $!,"\n";
    print LIST "#Scaffold_a\tScaffold_b\tStrand\ta_len\tb_len\n";
    foreach(0..$#relations){
        print LIST "#insertSize: $ins_cut{$_}\n";
        print LIST ($_->[0],"\t",$_->[1],"\t",$_->[2],"\t",$_->[3],"\t",$_->[4],"\n") foreach(@{$relations[$_]});
    }
    close LIST;
}
open (STAT,'>',$o_outpre.'.list.stat') or die $!,"\n";
open (STAT2,'>',$o_outpre.'.stat') or die $!,"\n";
print STAT "#Scaffold_a\tScaffold_b\tStrand\ta_min\ta_max\tb_min\tb_max\ta_avglen\tb_avglen\tnum\ta_seq\tb_seq\n";
print STAT2 "#Scaffold_a\tScaffold_b\tStrand\tnum\ta+b_avglen\n";
#print STAT join("\t",@{$_}[0..2,8..11,3..7])."\n"  foreach(@stack);
foreach my $i(0..$#relations){
    my @relation = @{$relations[$i]};
    if(!@relation){
        warn "no relations found for insertSize $ins_cut{$i} lib\n";
        next;
    }
$_ = shift @relation;
#die 'no relations found!program exit' unless $_;
my($fore,$back,$reverse,$sum1,$sum2,$num) = (@$_,1);
my($amin,$amax,$bmin,$bmax) = ($sum1,$sum1,$sum2,$sum2);
my @stack0; 
foreach(@relation) {
    if($fore eq $_->[0] && $back eq $_->[1] && $reverse eq $_->[2]) {
        $sum1+=$_->[3];$sum2+=$_->[4];++$num;
	    $amin = $_->[3] if($amin>$_->[3]);
	    $amax = $_->[3] if($amax<$_->[3]);
	    $bmin = $_->[4] if($bmin>$_->[4]);
	    $bmax = $_->[4] if($bmax<$_->[4]);
    } else {
        my($tail,$head) = ($scaf{$fore}{len} > $o_cutp ? (($reverse eq '->->' || $reverse eq '-><-') ?
            substr($scaf{$fore}{seq},$scaf{$fore}{len}-$o_cutp) :
            substr($scaf{$fore}{seq},0,$o_cutp)) : $scaf{$fore}{seq},
        $scaf{$back}{len} > $o_cutp ? ($reverse eq '-><-' ? substr($scaf{$back}{seq},$scaf{$back}{len}-$o_cutp):
            substr($scaf{$back}{seq},0,$o_cutp)) : $scaf{$back}{seq});
        push @stack0,[$fore,$back,$reverse,int(100*$sum1/$num+0.5)/100,int(100*$sum2/$num+0.5)/100,
             $num,$tail,$head,$amin,$amax,$bmin,$bmax];
        ($fore,$back,$reverse,$sum1,$sum2,$num) = (@$_,1);
	    ($amin,$amax,$bmin,$bmax) = ($sum1,$sum1,$sum2,$sum2);
    }
}
my($tail,$head) = ($scaf{$fore}{len} > $o_cutp ? ($reverse eq '->->' || $reverse eq '-><-' ?
    substr($scaf{$fore}{seq},$scaf{$fore}{len}-$o_cutp) :
    substr($scaf{$fore}{seq},0,$o_cutp)) : $scaf{$fore}{seq},
$scaf{$back}{len} > $o_cutp ? ($reverse eq '-><-' ? substr($scaf{$back}{seq},$scaf{$back}{len}-$o_cutp):
    substr($scaf{$back}{seq},0,$o_cutp)):$scaf{$back}{seq});
push @stack0,[$fore,$back,$reverse,int(100*$sum1/$num+0.5)/100,int(100*$sum2/$num+0.5)/100,
    $num,$tail,$head,$amin,$amax,$bmin,$bmax];
print STAT "#insertSize: $ins_cut{$i}\n";
print STAT2 "#insertSize: $ins_cut{$i}\n";
foreach(@stack0){
    print STAT join("\t",@{$_}[0..2,8..11,3..7])."\n";
    print STAT2 join("\t",@{$_}[0..2,5],int($_->[3]+$_->[4]+0.5))."\n";
}
push @stack,@stack0;
}
close STAT;
close STAT2;
########## Generate .dot file ############################################
unless($o_dot) {

$o_verbose && (print 'Generating .dot Files...',"\n");
my %forward;
my %bakward;
my @stack2;

for(my $i=0;$i<@stack;++$i) {
	next if(($o_cutx && $stack[$i][5]<$o_cutx)||
         ($o_cutl && $scaf{$stack[$i][0]}{len}<$o_cutl || $scaf{$stack[$i][1]}{len}<$o_cutl));
    my $strand = $stack[$i][2];
    $strand =~ s/->/+/g; $strand =~ s/<-/-/;
    my @data = ($stack[$i][0],$stack[$i][1],(split //,$strand),@{$stack[$i]}[5,3,4,8,9,10,11]);
    push @stack2,\@data;
    push @{$forward{$data[0]}},\@data;
    push @{$bakward{$data[1]}},\@data;

    $scaf{$data[0]}{occur}=1;
    $scaf{$data[1]}{occur}=1;
}

open (OUT,'>',$o_outpre.'.dot') or die;
print OUT "digraph G {\n\n";
print OUT '    graph [fontsize="9",rankdir="LR",pad=0];
    edge [arrowsize=.4];
';

foreach (keys %scaf) {
	print OUT subgraph($_) if($scaf{$_}{occur});
}

while(@stack2) {
    my $my = shift @stack2;
    iterate($my,0);
}

print OUT '}';
close OUT;
system"$dot";

sub iterate {
    my ($pair, $rev) = @_;
    #print $_."\t" foreach @$pair;
    #print "\n";
    return if $pair->[11];
    $pair->[11] = 1;

    my ($head, $tail);
    $head = $pair->[2] eq '+' ? 'tail' : 'head';
    $tail = $pair->[3] eq '+' ? 'head' : 'tail';
    $head = $pair->[0].$head;
    $tail = $pair->[1].$tail;
    ($head,$tail) = ($tail,$head) if $rev;
    print OUT "    $head -> $tail [label=\"$pair->[5],$pair->[7],$pair->[8],$pair->[4]X,$pair->[6],$pair->[9],$pair->[10]\",fontsize=9];\n";

    foreach(@{$forward{$pair->[0]}}) {
        next if $_->[11];
        my $reverse = $_->[2] eq $pair->[2] ? 0 : 1;
        $reverse = !$reverse if $rev;
        iterate($_,$reverse);
    }
    foreach(@{$forward{$pair->[1]}}) {
        next if $_->[11];
        my $reverse = $_->[2] eq $pair->[3] ? 0 : 1;
        $reverse = !$reverse if $rev;
        iterate($_,$reverse);
    }
    foreach(@{$bakward{$pair->[1]}}) {
        next if $_->[11];
        my $reverse = $_->[3] eq $pair->[3] ? 0 : 1;
        $reverse = !$reverse if $rev;
        iterate($_,$reverse);
    }
    foreach(@{$bakward{$pair->[0]}}) {
        next if $_->[11];
        my $reverse = $_->[3] eq $pair->[2] ? 0 : 1;
        $reverse = !$reverse if $rev;
        iterate($_,$reverse);
    }
}

sub subgraph {
    my ($scaf) = @_;
    '    subgraph cluster_'.$scaf.' {
        style=filled;
        color=grey;
        rank=same;
        node [fixedsize=true,height=.5,width=.5,fontsize=9,style=filled,color=white];
        '.$scaf.'head -> '.$scaf.'tail [color="red",label="'.$scaf."\\n".$scaf{$scaf}{len}.'bp",fontcolor="red",fontsize=9];
        '.$scaf.'head [label="5\'",fontsize=9,fontcolor="red"];
        '.$scaf.'tail [label="3\'",fontsize=9,fontcolor="red"];
    }
';
}

} ##END Unless($o_dot)

############ Generating circos config files##################################
unless($o_circos) {
$o_verbose && (print 'Generating Circos Config Files...',"\n");
my $base = basename($o_outpre);
my $break;
my $cutoff = 2*$o_cutoff;
foreach(keys %scaf) {
    $break .= "-$_:$o_cutoff-".($scaf{$_}{len}-$o_cutoff-1).";" if $scaf{$_}{len}>$cutoff;
}
open (IDEO,'>',"$o_outpre.ideo.conf") or die "can't open file\n";
print IDEO '
<ideogram>
<spacing>

default = 100u 
break   = 50u

axis_break         = yes
axis_break_style   = 2

<break_style 1>
stroke_color = black
fill_color   = blue
thickness    = 0.25r
stroke_thickness = 2
</break>

<break_style 2>
stroke_color     = black
stroke_thickness = 3
thickness        = 1.5r
</break>

</spacing>

# thickness (px) of chromosome ideogram
thickness        = 10p
stroke_thickness = 2
# ideogram border color
stroke_color     = black
fill             = yes
# the default chromosome color is set here and any value
# defined in the karyotype file overrides it
fill_color       = black

# fractional radius position of chromosome ideogram within image
radius         = 0.85r
show_label     = yes
label_with_tag = no
label_font     = condensedbold
label_radius   = dims(ideogram,radius) + 0.07r
label_size     = 20p

</ideogram>
';
close IDEO;
open (TICKS,'>',"$o_outpre.ticks.conf") or die "ticks.conf $!\n";
print TICKS '
show_ticks          = yes
show_tick_labels    = yes

<ticks>
    radius               = dims(ideogram,radius_outer)
    multiplier           = 1

    <tick>
    spacing        = ',int($o_cutoff/2),'u
    size           = 8p
    thickness      = 2p
    color          = black
    show_label     = yes
    label_size     = 15p
    label_offset   = 5p
    format         = %d
    </tick>

</ticks>
';
close TICKS; 
open (CONF,'>',$o_outpre.'.conf') or die "$o_outpre.conf $!\n";
#<colors>
#<<include etc/colors.conf>>
#</colors>
#<fonts>
#<<include etc/fonts.conf>>
#</fonts>

print CONF '
<<include etc/colors_fonts_patterns.conf>>
<<include etc/housekeeping.conf>>
<<include '.$base.'.ideo.conf>>
<<include '.$base.'.ticks.conf>>

karyotype   = '.$base.'.ideo 

<image>
dir = ./
file  = '.$base.'.png
png = yes
# radius of inscribed circle in image
radius         = 1500p
background     = white
angle_offset   = -90

24bit = yes
#auto_alpha_colors = yes
#auto_alpha_steps  = 5
</image>

chromosomes_units = 1
chromosomes_display_default = yes 

chromosomes_breaks = '.$break.' 

#chromosomes_radius = hs2:0.9r;hs3:0.8r

<links>
z      = 0
radius = 0.95r
bezier_radius = 0.1r

<link segdup>
show         = yes
color        = vvdgrey
thickness    = 2
file         = '.$base.'.link 
#record_limit = 2500
</link>
</links>';
#anglestep       = 0.5
#minslicestep    = 10
#beziersamples   = 40
#debug           = no
#warnings        = no
#imagemap        = no
## don'."'".'t touch!
#units_ok        = bupr
#units_nounit    = n';

close CONF;
system"$circos -conf $o_outpre.conf > $o_outpre.circos.log";
my $dir = ($o_outpre =~ /^(\/.+)\//) ? $1 : `pwd`;
chomp $dir;
$dir .= "/conf";
(-d $dir) ? `rm -r $dir/*` : mkdir($dir);
`mv $o_outpre.{conf,dot,ideo,ideo.conf,link,ticks.conf,circos.log} $dir`;
}