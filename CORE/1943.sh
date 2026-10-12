#!/usr/bin/env bash
set -euo pipefail
OUT='arcade/1943'
ZIPS=()
while (($#)); do
 case "$1" in
 -o|--out) [[ $# -ge 2 ]] || { echo 'Missing output directory' >&2; exit 1; }; OUT=$2; shift 2;;
 -h|--help) echo "Usage: $0 [1943.zip [parent.zip ...]] [-o directory]"; exit 0;;
 -*) echo "Unknown option: $1" >&2; exit 1;;
 *) ZIPS+=("$1"); shift;;
 esac
done
((${#ZIPS[@]})) || ZIPS=('1943.zip')
for cmd in perl; do command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 1; }; done
for z in "${ZIPS[@]}"; do [[ -f "$z" ]] || { echo "Missing ZIP: $z" >&2; exit 1; }; done
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
# Read ZIPs in order, with later archives overriding earlier chip names.
perl -MIO::Uncompress::Unzip -e '
use strict; use warnings;
my $dir=shift @ARGV;
for my $zip (@ARGV) {
 my $z=IO::Uncompress::Unzip->new($zip) or die "Cannot open $zip: $IO::Uncompress::Unzip::UnzipError\n";
 for (;;) {
  my $info=$z->getHeaderInfo(); my $name=lc($info->{Name}); $name =~ s{.*[\/]}{};
  if (length($name) && $name !~ /[\/]/) {
   open my $f,">:raw","$dir/$name" or die $!;
   my $buf; while ((my $n=$z->read($buf))>0) { print {$f} $buf or die $! } close $f or die $!;
  }
  last unless $z->nextStream();
 }
}
' "$TMP" "${ZIPS[@]}"
# The binary builder below performs native Perl byte operations; no Python is called.
perl -MCompress::Raw::Zlib=crc32 -e '
use strict; use warnings;
my ($src,$out)=@ARGV; my %spec=(
 'main' => [qw(bme01.12d bme02.13d bme03.14d)],
 'sound' => [qw(bm05.4k)],
 'char' => [qw(bm04.5h)],
 'map1' => [qw(bm14.5f)],
 'map2' => [qw(bm23.8k)],
 'scr1' => [qw(bm15.10f bm16.11f bm17.12f bm18.14f bm19.10j bm20.11j bm21.12j bm22.14j)],
 'scr2' => [qw(bm24.14k bm25.14l)],
 'obj' => [qw(bm06.10a bm07.11a bm08.12a bm09.14a bm10.10c bm11.11c bm12.12c bm13.14c)],
 'prom' => [qw(bm.7k bm10.7l bm11.12l bm1.12a bm12.12m bm2.13a bm3.14a bm4.12c bm5.7f bm6.4b bm7.7c bm8.8c bm9.6l)],
 );
my %size=(main=>163840,sound=>32768,char=>32768,map1=>32768,map2=>32768,scr1=>262144,scr2=>65536,obj=>262144,prom=>7168);
sub chip { my ($n)=@_; open my $f,"<:raw","$src/$n" or die "Missing chip $n\n"; local $/; return <$f> }
sub swap16 { my ($s)=@_; die "Odd size\n" if length($s)%2; return pack("v*",unpack("n*",$s)) }
sub interleave { my ($a,$b)=@_; die "Lane mismatch\n" if length($a)!=length($b); my $r=""; for(my $i=0;$i<length($a);$i++){ $r.=substr($a,$i,1).substr($b,$i,1) } return $r }
sub permute { my ($s,$mode)=@_; my $r="\0" x length($s); for(my $i=0;$i<length($s);$i++){ my $d=$mode eq "obj" ? (($i & ~0x7c)|(($i & 0x40)>>4)|(($i & 0x3c)<<1)) : (($i & ~0x1e)|(($i & 0x10)>>3)|(($i & 0x0e)<<1)); substr($r,$d,1)=substr($s,$i,1) } return $r }
for my $region (qw(main sound char map1 map2 scr1 scr2 obj prom)) {
 my @p=map {chip($_)} @{$spec{$region}}; my $data;
 if($region eq "char" || $region eq "map1" || $region eq "map2") { $data=swap16($p[0]) }
 elsif($region eq "scr2") { $data=interleave($p[1],$p[0]) }
 elsif($region eq "scr1" || $region eq "obj") { my @s=(4,0,5,1,6,2,7,3); $data=""; for(my $i=0;$i<8;$i+=2){$data.=interleave($p[$s[$i]],$p[$s[$i+1]])} }
 else { $data=join("",@p) }
 $data=permute($data,"map") if $region eq "map1" || $region eq "map2";
 $data=permute($data,"obj") if $region eq "obj";
 my $name="1943_${region}.rom"; die "Wrong size for $name: ".length($data)." expected $size{$region}\n" unless length($data)==$size{$region};
 open my $f,">:raw","$out/$name" or die $!; print {$f} $data or die $!; close $f or die $!;
 printf "%-20s %7d bytes  CRC32 %08X\n",$name,length($data),crc32($data);
}
' "$TMP" "$OUT"
echo 'Object sorting: hvvvvxx; map sorting: hvvvx'
