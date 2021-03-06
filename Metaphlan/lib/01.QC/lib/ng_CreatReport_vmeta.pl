#!/usr/bin/perl -w 
#===============================================================================
=head1 Name

	ng_CreatReport_v1.0

=head1 Version

	Author:   Tian Shilin,tianshilin@novogene.cn
	Company:  NOVOGENE                                 
	Version:  1.0                                  
	Created:  05/08/2012 10:52:53 AM

=head1 Description
	
	l|lst|list (file) input Sample png list. eg:
		01.DataClean/t/t_300.base.png
        01.DataClean/t/t_300.qual.png
		t and s are Sample name;
	o|dir (str) output dir of report.(default : .)
	q  (file)  QCstat for all sample(Interior)
	qn (file)  QCstat for all sample(Outer)
	
=head1 Usage
	
	ng_CreatReport_v1.0 -l <png list> -q <qcstat.xls> -qn <qcstat_novo.xls> 

=cut

#===============================================================================
use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use List::Util qw(first max);

my ($help,$lst,$dir,$type,$qcstat,$falen,$qcstat_all);
GetOptions(
		"h|?|help"     => \$help,
		"l|lst|list=s" => \$lst,
		"q|qcstat=s"	=> \$qcstat,
		"qn=s"    => \$qcstat_all,
		"o|dir=s"      => \$dir,
);
die `pod2text $0` if $help;
#print STDERR "Begin at:\t".`date`."\n";
die `pod2text $0` unless $lst;
use FindBin qw($Bin);
#use lib "$Bin/../../00.Commbin";
#use PATHWAY;
#my $lib="$Bin/../../";
#(-s "$Bin/../../../bin/Pathway_cfg.txt") || die"error: can't find config at $Bin/../../../bin, $!\n";
#my($logo)=get_pathway("$Bin/../../../bin/Pathway_cfg.txt",[qw(LOGO)],$Bin,$lib);
my $logo = "$Bin/logo.png";
my $date = `date +"%Y"-"%m"-"%d"`;
$dir ||= ".";
$type ||= "raw";
open Lst,$lst || die $!;
my (%raw_read,%raw_base,%effective_rate,%q20,%q30,%gc,%png,%error,%Len);
my $qc_tab;
my $qc_tab_all;
my %sample2nohost;
(-s "$dir/QC\_$type\_report") || `mkdir -p $dir/QC\_$type\_report`;

if($qcstat_all && -s $qcstat_all){
#print $qcstat_all,"\n";
	open QCM," >$dir/QC\_$type\_report/monitor.xls";
	if($qcstat_all =~ /total\.\S+QCstat\.info\.xls/)
    {
       print QCM "#Sample\tInsertSize(bp)\tSeqStrategy\tRawData\tCleanData\tClean_Q20\tClean_Q30\tClean_GC(%)\tEffective(%)\tNonHostData\tNonHost_Effective(%)\n";
    }
    elsif($qcstat_all =~ /total\.QCstat\.info\.xls/)
    {
        print QCM "#Sample\tInsertSize(bp)\tSeqStrategy\tRawData\tCleanData\tClean_Q20\tClean_Q30\tClean_GC(%)\tEffective(%)\n";
    }
    my ($n,$m)=(0,0);
	for(`less $qcstat_all`){
		/^#/ && $_=~s/^#//;
		chomp;
		my @l = split/\t/;
		$sample2nohost{$l[0]}=$l[-1] if (!$sample2nohost{$l[0]});
		#print "$l[0]\n";
####for QC monitor###
        if($qcstat_all =~ /total\.\S+QCstat\.info\.xls/)
        {
		    if($l[0]  ne "Sample")
		    {
			    my $nohost =$l[-1];
			    my $raw=$l[3];
			    $nohost=~s/\,//g;
			    $raw=~s/\,//g;
    			#print "$raw,$nohost\n";
	    		my $noeffec= ($nohost/$raw)*100;
		    	if ($nohost < 6000 || $noeffec < 50 )
		    	{
			    	print QCM join ("\t",$l[0],$l[1],$l[2],$l[3],$l[10],$l[11],$l[12],$l[13],$l[14],$l[15]),"\t";
			    	printf QCM "%2.2f\n",$noeffec;
			    	$m++;
			    }
		
    		}
        }
        elsif($qcstat_all =~ /total\.QCstat\.info\.xls/)
        {
            if($l[0]  ne "Sample")
            {
                my $clean = $l[10];
                $clean =~ s/\,//g;
                if($clean < 6000 || $l[-1] < 50)
                {
                    print QCM join ("\t",$l[0],$l[1],$l[2],$l[3],$l[10],$l[11],$l[12],$l[13],$l[14]),"\n";
                    $m++;
                }
            }
        }
	
	######for novo.html###3
		if($qc_tab_all){
			$qc_tab_all .= "\t\t\t<tr><td class=\"center\">".join('</td><td class=\"center\">',@l)."</td></tr>\n";
			$n++;
		}
		else{
			$qc_tab_all = "\t\t<tr class=\"head\"><th>".join('</th><th>',@l)."</th></tr>\n";
		}
	}  
    if($qcstat_all =~ /total\.\S+QCstat\.info\.xls/)
    {
        print QCM "#######The number of samples (NonHostData < 6G or NonHost_Effective(%)<50) is $m\n#######The number of total samples is $n\n";
    	close QCM;
    }
    elsif($qcstat_all =~ /total\.QCstat\.info\.xls/)
    {
        print QCM "#######The number of samples (CleanData < 6G or Effective(%) < 50%) is $m\n#######The number of total samples is $n\n";
        close QCM;
	}
	
}
if($qcstat && -s $qcstat){####add monitor by zhanghao 20180102
	for(`less $qcstat`){
		/^#/ && $_=~s/^#//;
		chomp;
		my @l = split/\t/;
		if($qc_tab){
			if($qcstat_all && $qcstat_all =~ /total\.\S+QCstat\.info\.xls/)
			{
				$qc_tab .= "\t\t\t<tr><td class=\"center\">".join('</td><td class=\"center\">',@l,$sample2nohost{$l[0]})."</td></tr>\n";
			}else
			{
			$qc_tab .= "\t\t\t<tr><td class=\"center\">".join('</td><td class=\"center\">',@l)."</td></tr>\n";
			}
		}else{
			if($qcstat_all && $qcstat_all =~ /total\.\S+QCstat\.info\.xls/)
			{
			$qc_tab = "\t\t<tr class=\"head\"><th>".join('</th><th>',@l,"NonHostData")."</th></tr>\n";
			}else
			{
			$qc_tab = "\t\t<tr class=\"head\"><th>".join('</th><th>',@l)."</th></tr>\n";
			}
		}
	}
}

system("mkdir -p $dir/QC_$type\_report/image");
my %name;
while(<Lst>){
	chomp;
	my $or_png=$_;
	my $bname=$or_png;
	my $sam_name = basename($_);
	$bname =~ s/.*\///;
	$sam_name=~s/\.(base|qual)\.png$//;
	$name{$sam_name}=1;
    system"cp -f $or_png $dir/QC_raw_report/image";
    $bname=~/base\.png$/ && ($png{$sam_name}{"base"} = $bname);
	$bname=~/qual\.png$/ && ($png{$sam_name}{"qual"} = $bname);
}
my @name=sort keys %name;

system("cp $logo $dir/QC_$type\_report/image/logo.png");

open OUT,">$dir/QC_$type\_report/index.html" || die $!;

print OUT "<html>                                                    
<head>
<meta http-equiv=\"content-type\" content=\"text/html; charset=gb2312\">
<title>北京诺禾致源数据质控（QC）报告</title>
<style type=\"text/css\">
<!--
body {background-color: #fff; font-size: bigger; margin: 0px; border-left: 12px solid #00f;}
.title {font-size: 32px; font-weight: 900;}
.c1 {text-indent: 2em;}
.c2 {text-indent: 4em;}
.c3 {text-indent: 6em;}
.c4 {text-indent: 8em;}
.noul {text-decoration: none;}
h1 {font-size: 28px; font-weight: 900; padding-top: 10px; margin-left: -10px; padding-left: 10px; border-top: 5px solid #bbf;}
h2 {font-size: 24px; font-weight: 900; text-indent: 1em;}
h3 {font-size: 20px; font-weight: 900; text-indent: 2em;}
h4 {font-size: 16px; font-weight: 900; text-indent: 3em;}
p {text-indent: 2em;}
img {border: 0px; margin: 10px 0;}
table {width: 60%; text-align: center; border-top: solid #000 1px; border-bottom: solid #000 1px; margin: 15px auto 15px auto; border-collapse: collapse;}
caption, .fig {font-weight: 900;}
.center {text-align: center;}
tr.head {background-color: rgb(214, 227, 188); text-align: center;}
th, td {border: solid #000 1px;}
.noborder {border: none; }
.button, .buttonLast {border-bottom: 1px solid #f00; padding: 0 2em; display: table-cell; cursor: pointer; text-align: center;}
.button {border-right: 1px solid #f00;}
.note {color: #f00;}
-->
</style>
<script type=\"text/javascript\">
<!--
function genContent() {
	html = document.body.innerHTML;
	titles = html.match(/<h(\\d)>(.*)<\\/h\\1>/gi);
	content = \"<div id='content'><a name='content' /><h1>目录</h1>\";
	for (i = 0; i < titles.length; i++) {
		j = titles[i].replace(/<h(\\d)>(.*)<\\/h\\1>/i, \"\$1\");
		title = titles[i].replace(/<h(\\d)>(.*)<\\/h\\1>/i, \"\$2\");
		html = html.replace(titles[i], \"<h\" + j + \"><a name='content\" + i + \"' />\" + title + \"&nbsp;<a href='#content' title='back to content' class='noul'>^</a></h\" + j + \">\");
		content += \"<div class='c\" + j + \"'><a href='#content\" + i + \"' class='noul'>\" + title + \"</a></div>\";
	}
	content += \"</div>\";
	html = html.replace(/(<h\\d>)/i, content + \"\$1\");
	document.body.innerHTML = html;
}

function tabView(data, title, prefix) {
	var n = data.length;
	var tab = \"<div id='\" + prefix + \"'><center><div style='margin: 10px 0;'>\";
	var code = \"\";
	for (i = 0; i < n; i++) {
		tab += \"<span id='\" + prefix + \"_button_\" + i + \"' class='button' onclick='javascript: highlight(\\\"\" + prefix + \"_button\\\", \" + (n + 2) + \", \" + i + \"); display(\\\"\" + prefix + \"\\\", \" + n + \", \" + i + \");'>\" + title[i] + \"</span>\";
		code += \"<div id='\" + prefix + \"_\" + i + \"'>\" + data[i] + \"</div>\";
	}
	tab += \"<span style='background-color: #f00;' id='\" + prefix + \"_button_\" + i + \"' class='button' onclick='javascript: highlight(\\\"\" + prefix + \"_button\\\", \" + (n + 2) + \", \" + i + \"); display(\\\"\" + prefix + \"\\\", \" + n + \", \\\"all\\\");'>All</span><span id='\" + prefix + \"_button_\" + (i + 1) + \"' class='buttonLast' onclick='javascript: highlight(\\\"\" + prefix + \"_button\\\", \" + (n + 2) + \", \" + (i + 1) + \"); display(\\\"\" + prefix + \"\\\", \" + n + \", -1);'>None</span></div>\";
	code = tab + code + \"</center></div>\";
	return code;
}

function display(prefix, total, target) {
	for (var i = 0; i < total; i++) {
		var showFlag = (i == target || target == \"all\")? \"\" : \"none\";
		document.getElementById(prefix + \"_\" + i).style.display = showFlag;
	}
}

function highlight(prefix, total, target) {
	for (var i = 0; i < total; i++) {
		bgColor = (i == target)? \"#ff0\" : \"#fff\";
		document.getElementById(prefix + \"_\" + i).style.backgroundColor = bgColor;
	}
}
//-->
</script>
</head>
<body>
<div id=\"header\"><img src=\"./image/logo.png\" width=\"20%\" height=\"12%\" border=\"0\" alt=\"Data QC\" /></div>
<ol>
<h1>1.数据说明</h1>
<ol>
<p>测序数据的产生是经过了DNA提取、建库、测序多个步骤的，然而，这些步骤中产生的无效数据会对生物信息数据高级分析带来严重的干扰，比如建库阶段会出现建库长度的偏差，测序阶段会出现测序错误的情况。我们必须通过一些手段将这些无效数据过滤排除掉，以保证生物信息分析的正常进行。</p>
</ol>
<h2>1.1 原始测序数据 </h2>
<ol>
<p>测序得到的原始图像数据经 base calling 转化为序列数据，我们称之为 raw data 或 raw reads，结果以 fastq 文件格式存储 （文件名：*.fq），fastq 文件为用户得到的最原始文件，里面存储 reads 的序列以及 reads 的测序质量。在 fastq 格式文件中每个 read 由四行描述：</p>
		<pre>
		\@HWI-EAS80_4_4_1_554_126
		GTATGCCGTCTTCTGCTTGAAAAAAAAAAACATAAAACAA
		+HWI-EAS80_4_4_1_554_126
		hhhhhhhhhhhhhhhhhhh[hEhSJPLeLdCLEN>IXHAA
		</pre>
		<p><b>每个序列共有 4 行信息：</b></p>
		<ol>
			<p>第 1 行是序列名称，由测序仪产生，包含index序列及read1或read2标志；</p>
			<p>第 2 行是序列,由大写“ACGTN”组成；</p>
			<p>第 3 行是序列ID，也有省略了ID名称后直接用“+”表示；</p>
			<p>第 4 行是序列的测序质量，每个字符对应第 2 行每个碱基；</p>
		</ol>
		<p><b>Solexa测序碱基质量值的表示方法:</b></p>
		<ol>
			<p>碱基的质量都是以ASCII值表示的，根据测序时采用的质量方案的不同，计算十进制的质量值的方法也有所区别，常见的计算方法如下所示：</p>
			<ol>
				<p>（1）质量值 = 字符的ASCII值 - 64</p>
				<p>（2）质量值 = 字符的ASCII值 - 33</p>
			</ol>
			<p>Solexa测序碱基质量值的范围是[0,40]，即ASCII值表示为[B,h] 或 [#,I]。</p>
		</ol>
		<p>Solexa 测序错误率与测序质量值简明对应关系。具体地，如果测序错误率用 E 表示，Solexa 碱基质量值用 Q 表示，则有如下关系 ： <b>Q =-10 log10(E)</b></p>
</ol>
<h2>1.2 有效数据 </h2>
<ol>
<p>原始测序数据中会包含接头信息，低质量碱基，未测出的碱基（以N表示），这些信息会对后续的信息分析造成很大的干扰，通过精细的过滤方法将这些干扰信息去除掉，最终得到的数据即为有效数据，我们称之为clean data 或 clean reads，该文件的数据格式与Raw data完全一样。</p>
</ol>
<h1>2.数据过滤方法</h1>
<p>1)	去除质量值≤38的碱基达到一定数目（默认设置为40）的reads；</p>
<p>2)	去除含N的碱基达到一定数目（默认设置为10）的reads；</p>
<p>3)	去除Adapter污染（默认Adapter序列与reads序列有15 bp以上的overlap）；</p>
<p>4)	在有宿主污染可能性的前提下，需与宿主数据库进行比对，过滤掉可能是宿主污染的reads（默认设置比对一致性≥90%的reads为宿主污染）。</p>
<h1>3.质控结果报告</h1>
<h2>3.1 测序数据产量统计</h2>
<ol>
<p>对测序结果各部数据处理进行数据统计（以百万碱基为单位）；Sample ID表示样品名称；Raw Data表示下机原始数据(Raw Data)；Low_Quality表示低质量的碱基数据；N-num 表示含N碱基数据；Adapter 表示Adapter数据；Clean Data表示过滤得到的有效数据(Clean Data)；Q20,Q30表示Clean Data中测序错误率小于0.01(质量值大于20)和0.001(质量值大于30)的碱基数目的百分比；GC (%) 表示Clean Data中GC碱基含量的百分比；Effective Rate表示有效数据(Clean Data)与原始数据(Raw Data)的百分比。</p>
<p><b>统计结果见表1所示：</b></p>
</ol>
<ol>
		<div class=\"center\">
		<table>
			<caption>表 1&nbsp;&nbsp;数据产出统计信息</caption>\n";
			if($qc_tab){
				print OUT $qc_tab;
				$qc_tab = "";
			}
	print OUT "		</table>
		</div>
</ol>
	
</br><h2>3.2 碱基质量分布 & 碱基含量分布</h2>
<ol>
<p>测序数据的质量主要会分布在Q20以上，这样才能保证后续高级分析的正常进行。据测序技术的特点，测序片段末端的碱基质量一般会比前端的低。在碱基质量分布图中，横坐标为Reads上的位置，纵坐标为Reads该位置上的碱基质量分布。在碱基含量分布图中，横坐标为Reads上的位置，纵坐标为某种碱基在该位置的含量，五种颜色分别表示ATGC四种碱基及未测明的N的含量比例。</p>
<p><b>下图中，左图为测序碱基质量分布图，右图为测序碱基含量分布图</b></p>
</ol>
	<div class=\"center\">
		<table class=\"noborder\">\n";

for(my $i=0;$i<=$#name;$i++){
	print OUT "\t\t<tr class=\"noborder\"><td class=\"noborder\"><img src=\"./image/$png{$name[$i]}{\"qual\"}\" alt=\"qual\" width=\"540\"/></td><td class=\"noborder\"><img src=\"./image/$png{$name[$i]}{\"base\"}\" alt=\"base\" width=540\"/></td></tr>\n";
	print OUT "\t\t<tr class=\"noborder\"><td class=\"noborder\">$name[$i]（碱基质量分布）</td><td class=\"noborder\">$name[$i]（碱基含量分布）</td></tr>\n";
}

print OUT "		</table>
		<span class=\"fig\">图 1&nbsp;&nbsp;测序碱基质量分布 & 测序碱基含量分布</span>
	</div>

<h1>4.附录(联系信息)</h1>
<p><b>北京诺禾致源科技股份有限公司</b></p>
<ol>
<p>电话：010-82837801</p>
<p>传真：010-82837801</p>
<p>邮箱：novogene\@novogene.cn</p>
<p>技术支持：support\@novogene.cn</p>
<p>Website：<a href=\"http://www.novogene.cn\" target=\"_blank\">www.novogene.cn</a></p>
<p>地址：北京海淀区学清路38号金码大厦B座21层（100083）</p>
</ol>
</ol>
<div class=\"center\">
<font style=\"font-size:20px; width: 100%;\">
<p><b>Thanks!</b></p></font>
</dir>
<script type=\"text/javascript\">
<!--
genContent();
//-->
</script>
</body> 
<html> \n";
close OUT;

$qcstat_all || die;
open OUT,">$dir/QC_$type\_report/novo.html" || die $!;

print OUT "<html>                                                    
<head>
<meta http-equiv=\"content-type\" content=\"text/html; charset=gb2312\">
<title>北京诺禾致源数据质控（QC）报告</title>
<style type=\"text/css\">
<!--
body {background-color: #fff; font-size: bigger; margin: 0px; border-left: 12px solid #00f;}
.title {font-size: 32px; font-weight: 900;}
.c1 {text-indent: 2em;}
.c2 {text-indent: 4em;}
.c3 {text-indent: 6em;}
.c4 {text-indent: 8em;}
.noul {text-decoration: none;}
h1 {font-size: 28px; font-weight: 900; padding-top: 10px; margin-left: -10px; padding-left: 10px; border-top: 5px solid #bbf;}
h2 {font-size: 24px; font-weight: 900; text-indent: 1em;}
h3 {font-size: 20px; font-weight: 900; text-indent: 2em;}
h4 {font-size: 16px; font-weight: 900; text-indent: 3em;}
p {text-indent: 2em;}
img {border: 0px; margin: 10px 0;}
table {width: 60%; text-align: center; border-top: solid #000 1px; border-bottom: solid #000 1px; margin: 15px auto 15px auto; border-collapse: collapse;}
caption, .fig {font-weight: 900;}
.center {text-align: center;}
tr.head {background-color: rgb(214, 227, 188); text-align: center;}
th, td {border: solid #000 1px;}
.noborder {border: none; }
.button, .buttonLast {border-bottom: 1px solid #f00; padding: 0 2em; display: table-cell; cursor: pointer; text-align: center;}
.button {border-right: 1px solid #f00;}
.note {color: #f00;}
-->
</style>
<script type=\"text/javascript\">
<!--
function genContent() {
	html = document.body.innerHTML;
	titles = html.match(/<h(\\d)>(.*)<\\/h\\1>/gi);
	content = \"<div id='content'><a name='content' /><h1>目录</h1>\";
	for (i = 0; i < titles.length; i++) {
		j = titles[i].replace(/<h(\\d)>(.*)<\\/h\\1>/i, \"\$1\");
		title = titles[i].replace(/<h(\\d)>(.*)<\\/h\\1>/i, \"\$2\");
		html = html.replace(titles[i], \"<h\" + j + \"><a name='content\" + i + \"' />\" + title + \"&nbsp;<a href='#content' title='back to content' class='noul'>^</a></h\" + j + \">\");
		content += \"<div class='c\" + j + \"'><a href='#content\" + i + \"' class='noul'>\" + title + \"</a></div>\";
	}
	content += \"</div>\";
	html = html.replace(/(<h\\d>)/i, content + \"\$1\");
	document.body.innerHTML = html;
}

function tabView(data, title, prefix) {
	var n = data.length;
	var tab = \"<div id='\" + prefix + \"'><center><div style='margin: 10px 0;'>\";
	var code = \"\";
	for (i = 0; i < n; i++) {
		tab += \"<span id='\" + prefix + \"_button_\" + i + \"' class='button' onclick='javascript: highlight(\\\"\" + prefix + \"_button\\\", \" + (n + 2) + \", \" + i + \"); display(\\\"\" + prefix + \"\\\", \" + n + \", \" + i + \");'>\" + title[i] + \"</span>\";
		code += \"<div id='\" + prefix + \"_\" + i + \"'>\" + data[i] + \"</div>\";
	}
	tab += \"<span style='background-color: #f00;' id='\" + prefix + \"_button_\" + i + \"' class='button' onclick='javascript: highlight(\\\"\" + prefix + \"_button\\\", \" + (n + 2) + \", \" + i + \"); display(\\\"\" + prefix + \"\\\", \" + n + \", \\\"all\\\");'>All</span><span id='\" + prefix + \"_button_\" + (i + 1) + \"' class='buttonLast' onclick='javascript: highlight(\\\"\" + prefix + \"_button\\\", \" + (n + 2) + \", \" + (i + 1) + \"); display(\\\"\" + prefix + \"\\\", \" + n + \", -1);'>None</span></div>\";
	code = tab + code + \"</center></div>\";
	return code;
}

function display(prefix, total, target) {
	for (var i = 0; i < total; i++) {
		var showFlag = (i == target || target == \"all\")? \"\" : \"none\";
		document.getElementById(prefix + \"_\" + i).style.display = showFlag;
	}
}

function highlight(prefix, total, target) {
	for (var i = 0; i < total; i++) {
		bgColor = (i == target)? \"#ff0\" : \"#fff\";
		document.getElementById(prefix + \"_\" + i).style.backgroundColor = bgColor;
	}
}
//-->
</script>
</head>
<body>
<ol>
<h1>1.数据说明</h1>
<ol>
<p>测序数据的产生是经过了DNA提取、建库、测序多个步骤的，然而，这些步骤中产生的无效数据会对生物信息数据高级分析带来严重的干扰，比如建库阶段会出现建库长度的偏差，测序阶段会出现测序错误的情况。我们必须通过一些手段将这些无效数据过滤排除掉，以保证生物信息分析的正常进行。</p>
</ol>
<h2>1.1 原始测序数据 </h2>
<ol>
<p>测序得到的原始图像数据经 base calling 转化为序列数据，我们称之为 raw data 或 raw reads，结果以 fastq 文件格式存储 （文件名：*.fq），fastq 文件为用户得到的最原始文件，里面存储 reads 的序列以及 reads 的测序质量。在 fastq 格式文件中每个 read 由四行描述：</p>
		<pre>
		\@HWI-EAS80_4_4_1_554_126
		GTATGCCGTCTTCTGCTTGAAAAAAAAAAACATAAAACAA
		+HWI-EAS80_4_4_1_554_126
		hhhhhhhhhhhhhhhhhhh[hEhSJPLeLdCLEN>IXHAA
		</pre>
		<p><b>每个序列共有 4 行信息：</b></p>
		<ol>
			<p>第 1 行是序列名称，由测序仪产生，包含index序列及read1或read2标志；</p>
			<p>第 2 行是序列,由大写“ACGTN”组成；</p>
			<p>第 3 行是序列ID，也有省略了ID名称后直接用“+”表示；</p>
			<p>第 4 行是序列的测序质量，每个字母对应第 2 行每个碱基；</p>
		</ol>
		<p><b>Solexa测序碱基质量值的表示方法:</b></p>
		<ol>
			<p>碱基的质量都是以ASCII值表示的，根据测序时采用的质量方案的不同，计算十进制的质量值的方法也有所区别，常见的计算方法如下所示：</p>
			<ol>
				<p>（1）质量值 = 字符的ASCII值 - 64</p>
				<p>（2）质量值 = 字符的ASCII值 - 33</p>
			</ol>
			<p>Solexa测序碱基质量值的范围是[0,40]，即ASCII值表示为[B,h] 或 [#,I]。</p>
		</ol>
		<p>Solexa 测序错误率与测序质量值简明对应关系。具体地，如果测序错误率用 E 表示，Solexa 碱基质量值用 Q 表示，则有如下关系 ： <b>Q =-10 log10(E)</b></p>
</ol>
<h2>1.2 有效数据 </h2>
<ol>
<p>原始测序数据中会包含接头信息，低质量碱基，未测出的碱基（以N表示），这些信息会对后续的信息分析造成很大的干扰，通过精细的过滤方法将这些干扰信息去除掉，最终得到的数据即为有效数据，我们称之为clean data 或 clean reads，该文件的数据格式与Raw data完全一样。</p>
</ol>
<h1>2.数据过滤方法</h1>
<p>1)	去除质量值≤38的碱基达到一定数目（默认设置为40）的reads；</p>
<p>2)	去除含N的碱基达到一定数目（默认设置为10）的reads；</p>
<p>3)	去除Adapter污染（默认Adapter序列与reads序列有15 bp以上的overlap）；</p>
<p>4)	在有宿主污染可能性的前提下，需与宿主数据库进行比对，过滤掉可能是宿主污染的reads（默认设置比对一致性≥90%的reads为宿主污染）。</p>

<h1>3.质控结果报告</h1>
<h2>3.1 测序数据产量统计</h2>
<ol>
<p>对测序结果各部数据处理进行数据统计（以百万碱基为单位）；Sample ID表示样品名称；Raw Data表示下机原始数据(Raw Data)；Low_Quality表示低质量的碱基数据；N-num 表示含N碱基数据；Adapter 表示Adapter数据；Clean Data表示过滤得到的有效数据(Clean Data)；Q20,Q30表示Clean Data中测序错误率小于0.01(质量值大于20)和0.001(质量值大于30)的碱基数目的百分比；GC (%) 表示Clean Data中GC碱基含量的百分比；Effective Rate表示有效数据(Clean Data)与原始数据(Raw Data)的百分比。</p>
<p><b>统计结果见表1所示：</b></p>
</ol>
<ol>
		<div class=\"center\">
		<table>
			<caption>表 1&nbsp;&nbsp;数据产出统计信息</caption>\n";
			if($qc_tab_all){
				print OUT $qc_tab_all;
				$qc_tab_all = "";
			}
	print OUT "		</table>
		</div>
</ol>
	
</br><h2>3.2 碱基质量分布 & 碱基含量分布</h2>
<ol>
<p>测序数据的质量主要会分布在Q20以上，这样才能保证后续高级分析的正常进行。据测序技术的特点，测序片段末端的碱基质量一般会比前端的低。在碱基质量分布图中，横坐标为Reads上的位置，纵坐标为Reads该位置上的碱基质量分布。在碱基含量分布图中，横坐标为Reads上的位置，纵坐标为某种碱基在该位置的含量，五种颜色分别表示ATGC四种碱基及未测明的N的含量比例。</p>
<p><b>下图中，左图为测序碱基质量分布图，右图为测序碱基含量分布图</b></p>
</ol>
	<div class=\"center\">
		<table class=\"noborder\">\n";
for(my $i=0;$i<=$#name;$i++){
	print OUT "\t\t<tr class=\"noborder\"><td class=\"noborder\"><img src=\"./image/$png{$name[$i]}{\"qual\"}\" alt=\"qual\" width=\"540\"/></td><td class=\"noborder\"><img src=\"./image/$png{$name[$i]}{\"base\"}\" alt=\"base\" width=540\"/></td></tr>\n";
	print OUT "\t\t<tr class=\"noborder\"><td class=\"noborder\">$name[$i]（碱基质量分布）</td><td class=\"noborder\">$name[$i]（碱基含量分布）</td></tr>\n";
}

print OUT "		</table>
		<span class=\"fig\">图 1&nbsp;&nbsp;测序碱基质量分布 & 测序碱基含量分布</span>
	</div>

<h1>4.附录(联系信息)</h1>
<p><b>北京诺禾致源科技股份有限公司</b></p>
<ol>
<p>电话：010-82837801</p>
<p>传真：010-82837801</p>
<p>邮箱：novogene\@novogene.cn</p>
<p>技术支持：support\@novogene.cn</p>
<p>Website：<a href=\"http://www.novogene.cn\" target=\"_blank\">www.novogene.cn</a></p>
<p>地址：北京海淀区学清路38号金码大厦B座21层（100083）</p>
</ol>
</ol>
<div class=\"center\">
<font style=\"font-size:20px; width: 100%;\">
<p><b>Thanks!</b></p></font>
</dir>
<script type=\"text/javascript\">
<!--
genContent();
//-->
</script>
</body> 
<html> \n";

close OUT;

#print STDERR "Finaly at:\t".`date`."\n";
