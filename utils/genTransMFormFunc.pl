
# usage: 
#   genInlines.pl Modal/GeneratePatterns.inline.hs.in Modal/ModalSystems.hs

# substitute ##<WORD> with Haskell code snippits

use strict;
use File::Basename;

my %substs = 
 ("�!modalAx" =>
  "inlineAxioms Modal \"modality empty\\n".
"pred p:()\\n".
". ",
  "�!caslAx" =>
  "inlineAxioms CASL \"sort world \\n".
"pred rel : world * world\\n".
"forall w1 : world \\n. ");

die "exactly one in- and one out-file needed!!" unless @ARGV == 2;

my ($infile,$outfile) = @ARGV;
my $outfile1 = join "", (fileparse($infile,'\.in'))[1,0];

print "Generating $outfile1\n";

open IN, "<$infile" or die "cannot read \"$infile\"";
open OUT, ">$outfile1" or die "cannot write to \"$outfile1\"";

while (<IN>) {
   foreach my $key (keys %substs) {
      s/$key\"/$substs{$key}/ge;
   }
   print OUT $_;
}

close IN;
close OUT;

my $outfile2 = join("", (fileparse($outfile1,'\.inline\.hs'))[1,0]).".hs";

my $input = `utils/outlineAxioms $outfile1`;
$input =~ s,^.*snip\s+><\s+Patterns(.*)snip\s+>/<\s+Patterns,$1,s;
$input =~ s/^\s*\[\(\[\[//s;
$input =~ s/(\})\]\]\)\]\s*$/$1/s;

# print "$input\n";
my @input = split(/\]\]\),\s+?\(\[\[/s, $input); 

print "Generating $outfile\n";
open OUT, ">$outfile" or die "cannot write to \"$outfile\"";

print OUT '{- look but don\'t touch !!
generated by utils genFunction.pl -}

module Modal.ModalSystems (transSchemaMFormula) where

import Common.PrettyPrint
import Common.AS_Annotation

-- CASL
import CASL.Logic_CASL 
import CASL.AS_Basic_CASL

-- ModalCASL
import Modal.AS_Modal
import Modal.Print_AS

addNonEmptyLabel :: String -> Named a -> Named a
addNonEmptyLabel l s 
    | null l    = s
    | otherwise = s {senName = l}

transSchemaMFormula :: SORT -> PRED_NAME -> [VAR] 
		    -> AnModFORM -> Named CASLFORMULA

',
'transSchemaMFormula world rel vars anMF =
   let '.
	  join("\n       ",map {'w'.$_.' = vars !! '.($_-1);} (1,2,3,4,5)).
	  ' in
    case (getRLabel anMF,item anMF) of
';

foreach my $pair (@input) {
    my ($pattern,$result) = split /\]\],\s+?\[\[/s,$pair;
    $pattern =~ s/""/label/os;
    $pattern =~ s/\n//gos;
    $pattern =~ s/\s+/ /go;
    $pattern =~ s/Simple_mod empty/_/go;
    $pattern =~ s/ (p|q) / _ /go;
    $pattern =~ s/\}\s*$//o;
    $pattern =~ s/NamedSen\{senName = //o;
    $pattern =~ s/(\w,) sentence = /$1/o;
    $pattern =~ s/\[\]/_/go;
    $result =~ s/\n//gos;
    $result =~ s/\s+/ /go;
    print OUT
'      ('.$pattern.") -> \n".
'        addNonEmptyLabel label ('.$result.")\n";
}
print OUT '      (_,f)'." ->\n".
          '          error ("Modal2CASL: unknown formula \\""++showPretty f "\\"\\n"++show f)
';

close OUT;
