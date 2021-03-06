#!/usr/bin/perl -w
use strict;
use Cwd qw(abs_path);
use Getopt::Long;
my ($prefix,$outfile,$rank_rank,$group,$outdir,$colour_g,$colour_tax);
my $abundant_limt=35;
GetOptions("top:i"=>\$abundant_limt,"level:s"=>\$prefix,"outprefix:s"=>\$outfile,"level_annotation:s"=>\$rank_rank,"group:s"=>\$group,"outdir:s"=>\$outdir,"group_col:s"=>\$colour_g,"tax_col:s"=>\$colour_tax,);
(@ARGV) || die "Usage: perl $0 <otu_table.txt> --level [sgfocp]__ --outprefix cluster.[sgfocp] --level_annotation s__p|g__p|f__p|o__p|c__p|s__c|g__c|f__c|o__c --group group.list --outdir .
    *input table <file>		    input otu_table.txt file which contains taxon_detail,must be set
    *--level <str> 		        set classified level prefix ,form: g__ ,must be set
    --outprefix <str>		    set outputfile prefix,the file is used to plot heatmap,default cluster
    --top <num>			        set top num species to plot heatmap
    --level_annotation <str>	add taxon annotation,default phlum level,format: g__[pcof]
    --group <str>		        add group annotation,format: sample\\tgroup
    --outdir <str>		        set output director,default ./
    --group_col <str>           set group label colour
    --tax_col <str>             set tax label colour

Example: 
perl $0 otu_table.g.relative.mat --level g__
perl $0 otu_table.g.relative.mat --level g__ --outprefix cluster.g --level_annotation g__p --group group.list \n";
#==================================================================================
my $R="System/R-3.1.0/R-3.1.0/bin/R";
#====================================
my $infile = shift @ARGV;
(-s $infile) || die $!;$infile= abs_path($infile);
$outfile ||= "cluster";
#if(!$rank_rank){
#    if($prefix){
#        $rank_rank = "${prefix}"."p";
#    }
#}
$group &&= abs_path($group);
$outdir ||= ".";
(-s $outdir) || mkdir($outdir);
$outdir &&= abs_path($outdir);
#====================================
open IN,  $infile || die "error: can't open $infile $! . Please Check input file .";
open OUT, ">$outdir/$outfile.txt" || die$!;
$rank_rank && (open LP, ">$outdir/$rank_rank.list" || die$!);
my $title = <IN>;
chomp $title;
my @sample_id = ($title =~/\t/) ? split /\t/,$title : split /\s+/,$title;
#pop @sample_id;
#the sampel num must >=3
my $sample_num=scalar(@sample_id);
if($sample_num<4){
	die "Can't run $0 command, due to the sample number is less than 3.\n ";
}
#====================================
my ($rank,@abundance,$fulltaxon,$taxon,%full_taxon,%phylum_genus,%line,%taxon_abundance,$ra);
$rank ||= "p";
my %taxon_num;
print OUT join("\t",@sample_id),"\n";;
if($rank_rank && $rank_rank=~/(\w)__(\w)/){
    $rank = $2;
}

while (<IN>) {
    chomp;
    @abundance = split /\t/, $_;
    $fulltaxon = $abundance[-1];
    pop @abundance;
    $taxon = $fulltaxon;
    if ( $taxon =~ /$prefix[\-\s\w\[\]]+/ ) {
        my $phylum = $1 if($taxon =~ /${rank}__([\-\s\w\[\]]+)/);
        $taxon =~ s/(.)*$prefix//;
#        $taxon =~ s/;//;
#	    $taxon =~ s/\s+/_/;
        if( length($taxon) > 100 || $taxon eq 'Others'){
            next;
        }
        $taxon_num{$taxon}++;
        if($taxon_num{$taxon}<2){
            $full_taxon{$fulltaxon} = $taxon;
        }else{
            my @level=split /;/,$fulltaxon;
            $taxon = pop @level;
            foreach (1..$#level){
                ($level[-1]=~ /unidentified/ && pop @level) || last;
            }
            $full_taxon{$fulltaxon} = "$level[-1];$taxon";
        }
        $phylum_genus{$fulltaxon} = $phylum;
	$line{$fulltaxon} = join("\t",@abundance[1..$#abundance]);
	for ( my $i = 1 ; $i <= $#sample_id ; $i++ ) {
            $ra = $abundance[$i];
            $ra = sprintf "%.15f", $1 / ( 10**$2 ) if ( $ra =~ /(.*)e-(\d+)/ );
	    #$inf{ $sample_id[$i] } .= $sample_id[$i] . "\t" . $ra . "\t" . $taxon . "\n";
	    if ( exists $taxon_abundance{$fulltaxon} ) {
		$taxon_abundance{$fulltaxon} = $ra if ( $taxon_abundance{$fulltaxon} < $ra );
	    }else{
		$taxon_abundance{$fulltaxon} = $ra;
            }
	}
    }
}
close IN;
#=============================
my %top_abundant;
my $abundant_num  = 0;
foreach my $tmp_abundant ( sort { $taxon_abundance{$b} <=> $taxon_abundance{$a} } keys %taxon_abundance ) {
    $abundant_num += 1;
    $top_abundant{$tmp_abundant} = $taxon_abundance{$tmp_abundant} if ( $abundant_num <= $abundant_limt );
}
foreach my $key ( keys %top_abundant ) {
    print OUT $full_taxon{$key}. "\t" . $line{$key} . "\n";
    $rank_rank && (print LP "$full_taxon{$key}\t$phylum_genus{$key}\n");
}

close OUT;
$rank_rank && close LP;
#============================================================================
#colour set
my @group_col;
if($colour_g){
    @group_col = split /\,/, $colour_g;
    for(0..$#group_col){
        $group_col[$_] = "\"".$group_col[$_]."\"";
    }
}else{
    @group_col=('"#439dee"','"#FF6666"','"#00CC00"','"#ee439d"','"#cb4154"','"#1dacd6"','"#66ff00"','"#bf94e4"','"#ff007f"','"#08e8de"','"#004225"','"#480607"');
}
my @tax_col;
if($colour_tax){
    @tax_col = split /\,/, $colour_tax;
    for(0..$#tax_col){
        $tax_col[$_] = "\"".$tax_col[$_]."\"";
    }
}else{
    @tax_col=('"#cb4154"','"#1dacd6"','"#66ff00"','"#bf94e4"','"#ff007f"','"#08e8de"','"#f4bbff"','"#ff55a3"','"#fb607f"','"#004225"','"#cd7f32"','"#a52a2a"','"#ffc1cc"','"#e7feff"','"#f0dc82"','"#480607"','"#800020"','"#deb887"','"#cc5500"','"#e97451"','"#8a3324"','"#bd33a4"','"#702963"','"#cc0000"','"#006a4e"','"#873260"','"#0070ff"','"#b5a642"','"#439dee"','"#FF6666"','"#00CC00"','"#ee439d"','"#9dee43"');
}
my($group_col,$tax_col);
if($group){
    my (%count,@group,@uniq_group);
    for(`less $group`){
        chomp;
        my @line = (/\t/) ? split /\t/ : split;
        push @group,$line[1];
    }
    @uniq_group=grep { ++$count{$_} < 2 } @group;
    if(@uniq_group <= $#group_col+1){
        for my $i(0..$#uniq_group){
            $group_col .= "$uniq_group[$i]"."="."$group_col[$i],";
        }
    }else{
        my $j=0;
        for my $i(0..$#group_col){
            $group_col .= "$uniq_group[$i]"."="."$group_col[$i],";
        }
        for my $i($#group_col+1..$#uniq_group){
            $group_col .= "$uniq_group[$i]"."="."$group_col[$j],";
            $j++;
        }
    }
    $group_col = substr($group_col,0,-1);
}
if($rank_rank){
    my (%hash,@tax,@uniq_tax);
    for(`less $outdir/$rank_rank.list`){
        chomp;
        my @line = (/\t/) ? split /\t/ : split;
        push @tax,$line[1];
    }
    @uniq_tax=grep { ++$hash{$_} < 2 } @tax;
    if(@uniq_tax <= @tax_col){
        for my $i(0..$#uniq_tax){
            $tax_col .= "\"$uniq_tax[$i]\""."="."$tax_col[$i],";
        }
    }else{
        my $j=0;
        for my $i(0..$#tax_col){
            $tax_col .= "\"$uniq_tax[$i]\""."="."$tax_col[$i],";
        }
        for my $i($#tax_col+1..$#uniq_tax){
            $tax_col .= "\"$uniq_tax[$i]\""."="."$tax_col[$j],";
            $j++;
        }
    }
    $tax_col = substr($tax_col,0,-1);
}
#============================================================================
#R scripts
my $pdf_w =$sample_num*105/155+16;
my $pdf_h =$abundant_num*18/35+6;
my %rank_name=("p"=>"Phylum","c"=>"Class","o"=>"Order","f"=>"Family");

open R, ">$outdir/$outfile.R";
if($group){ #### add cellheight =20,cellwidth=20 by zhanghao 20180118
    if(!$rank_rank || $outfile=~/cluster\.p/){
        print R "library(pheatmap)
        setwd(\"$outdir\")
        x<-read.table(\"$outfile.txt\",sep=\"\\t\",header=T,row.names=1)
        group<-read.table(\"$group\",sep=\"\\t\",header=F)
        annotation_col = data.frame(Group=factor(group\$V2))
        rownames(annotation_col) = group\$V1
        ann_colors = list(Group = c($group_col))
        pheatmap(x,scale=\"row\",color = colorRampPalette(c(\"royalblue1\", \"white\",\"salmon\"))(100),annotation_col = annotation_col,filename=\"$outfile.pdf\",height=ceiling($pdf_h),width=ceiling($pdf_w),cellheight =20,cellwidth=20,fontsize=20,cluster_cols=FALSE,annotation_colors=ann_colors)    
        dev.off()";
    }else{ 
        print R "library(pheatmap)
        setwd(\"$outdir\")
        x<-read.table(\"$outfile.txt\",sep=\"\\t\",header=T,row.names=1)
        group<-read.table(\"$group\",sep=\"\\t\",header=F)
        tax<-read.table(\"$rank_rank.list\",sep=\"\\t\",header=F)
        annotation_col = data.frame(Group=factor(group\$V2))
        rownames(annotation_col) = group\$V1
        annotation_row = data.frame($rank_name{$rank}=factor(tax\$V2))
        rownames(annotation_row) = tax\$V1
        ann_colors = list(Group = c($group_col),Phylum=c($tax_col))
        pheatmap(x,scale=\"row\",color = colorRampPalette(c(\"royalblue1\", \"white\",\"salmon\"))(100),annotation_col = annotation_col, annotation_row = annotation_row,filename=\"$outfile.pdf\",height=ceiling($pdf_h),width=ceiling($pdf_w),cellheight =20,cellwidth=20,fontsize=20,cluster_cols=FALSE,annotation_colors=ann_colors)
        dev.off()";
    }
}else{
    if(!$rank_rank || $outfile=~/cluster\.p/){
        print R "library(pheatmap)
        setwd(\"$outdir\")
        x<-read.table(\"$outfile.txt\",sep=\"\\t\",header=T,row.names=1)
        pheatmap(x,scale=\"row\",color = colorRampPalette(c(c(\"royalblue1\", \"white\",\"salmon\"))(100),filename=\"$outfile.pdf\",height=ceiling($pdf_h),width=ceiling($pdf_w),cellheight =20,cellwidth=20,fontsize=20,cluster_cols=FALSE)
        dev.off()";
    }else{
        print R "library(pheatmap)
        setwd(\"$outdir\")
        x<-read.table(\"$outfile.txt\",sep=\"\\t\",header=T,row.names=1)
        tax<-read.table(\"$rank_rank.list\",sep=\"\\t\",header=F)
        annotation_row = data.frame($rank_name{$rank}=factor(tax\$V2))
        rownames(annotation_row) = tax\$V1
        ann_colors = list(Group = c(Phylum=c($tax_col))
        pheatmap(x,scale=\"row\",color = colorRampPalette(c(\"royalblue1\", \"white\",\"salmon\"))(100),annotation_row = annotation_row,filename=\"$outfile.pdf\",,height=ceiling($pdf_h),width=ceiling($pdf_w),cellheight =20,cellwidth=20,fontsize=20,cluster_cols=FALSE,annotation_colors=ann_colors)
        dev.off()";
    }
}
close R;

`$R -f $outdir/$outfile.R`;
`/usr/bin/convert -density 200 $outdir/$outfile.pdf $outdir/$outfile.png`;
#$rank_rank && `rm -r $rank_rank.list`;
(-s "$outdir/Rplots.pdf")&&(`rm -r $outdir/Rplots.pdf`);
