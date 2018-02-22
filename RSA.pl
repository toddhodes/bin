#!/usr/sww/bin/perl5
($s,$k,$n)=@ARGV;$w=length$n;$k="0$k"if length($k)&1;$n="0$n",$w++if$w&1;die
"$0 -d|-e key mod <in >out\n"if$s!~/^-[de]$/||$#ARGV<2;$v=$w;$s=~/d/?$v-=2:
$w-=2;$_=unpack('B*',pack('H*',$k));s/^0*//g;s/0/d*ln%/g;s/1/d*ln%lm*ln%/g;
$c="1${_}p";while(read(STDIN,$m,$w/2)){$m=unpack("H$w",$m);chop($a=
`echo 16o16i\U$m\Esm\U$n\Esn$c|dc`);print pack('H*','0'x($v-length$a).$a);}
