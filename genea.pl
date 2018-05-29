#!/usr/bin/perl

use constant VERSION 		=> "1.0";
use constant DEBUG 		=> 0;

use utf8;
use open ':std', ':encoding(UTF-8)';
use Switch;
#use DateTime::Calendar::FrenchRevolutionary;
use feature 'unicode_strings';

## License : GPL

## Historique
# 0.8 : 28/05/18 : Early debug
# 0.9 : 28/05/18 : première ébauche de CSV
# 1.0 : 29/05/18 : Formalisation, constantes, correction des dates, première version versionnée

# Dependencies :
# CPAN - DateTime::Calendar::FrenchRevolutionary

use constant FORMAT		=> "SOSA;prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;jour_décès_lui;mois_décès_lui;année_décès_lui;lieu_décès_lui;métier_lui;prénom_elle;nom_elle;jour_naiss_elle;mois_naiss_elle;année_naiss_elle;lieu_naiss_elle;jour_décès_elle;mois_décès_elle;année_décès_elle;lieu_décès_elle;métier_elle;jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant";

use constant ST_INTERLIGNE	=> 20;
use constant ST_AFF 		=> 30;

# Conversion URL_ENCODE vers ANSI classique
sub un_urlize {
	my ($rv) = @_;
	$rv =~ s/\+/ /g;
	$rv =~ s/%(..)/pack("c",hex($1))/ge;
	$rv =~ s/&nbsp;/ /g;
	return $rv;
}

sub revo2greg {
	my ($date)=@_;
}

# Conversion URL_ENCODE vers ANSI classique
sub parse_date {
	my ($date_in) = @_;	
	my $date;
	$date_in =~ s/&nbsp;/ /g;
	if ($date_in =~ / ([^ ]+\/[^ ]+) /) {
		$periode=$`;
		$date=$1;
		$comm=$';
	}
	elsif ($date_in =~ /^(\w+) ([^ ]+)/){
		$date=$2;
		$periode=$1;
		$comm="";
	}
	elsif ($date_in =~ /^([^ ]+) ([\w()]+)/){
		$periode="";
		$date=$1;
		$comm=$2;
	}
	elsif ($date_in =~ /^([^ ]+)$/){
		$periode="";
		$date=$1;
		$comm="";
	}
	else {
		$date = $date_in;
	}
	$date =~ s/\//-/g;
	print "| $periode ---- $date ---- $comm |\n" if DEBUG;

	switch ($comm) {
		case /républicain/ {
			#revo2greg(\$date);
			$date="R:$date";
		}
		case /\(julien\)/ {
			#revo2greg(\$date);
			$date="J:$date";
		}
		case /\(hebrew\)/ {
			#revo2greg(\$date);
			$date="H:$date";
		}
		else {
			$date="$date";
		}
	}
	switch ($periode) {
		case /^peut-être ?$/ {
			$date="?;$date";
		}
		case /^environ ?$/ {
			$date="?;$date";
		}
		case /^vers ?$/ {
			$date="/;$date";
		}
		case /^avant ?$/ {
			$date="<;$date";
		}
		case /^apr.s ?$/ {
			$date=">;$date";
		}
		else { $date=";$date"; }
	}
	$date =~ s/ +$//;
	print "| $periode ---- $date ---- $comm |\n" if DEBUG;
	return $date;
}

my $state=0;

# Entête
print "# <GeneaParse v".VERSION.">\n";
print FORMAT;

while (<STDIN>) {
#	print "$state $_";
	switch ($state) {
		case 0 {
			if (/^<h2><span class="htitle">&nbsp;<\/span><span>(.+)<\/span><\/h2>/) {
				$root_sosa=$1;
				$state=1;
			}
		}
		case 1 {
			if (/^<tbody>/) { $state=2; }
		}
		case 2 {
			if (/^<\/tr>/) { $state=ST_INTERLIGNE; }
		}
		case ST_INTERLIGNE { # Interligne
			#print "======\n";
			if (/^<tr>/) { 
				$state=21; 
				%items_a={};
				%items_b={};
			}
			if (/^<tr dontbreak="1">/) {  # suite d'un mariage multiple
				$state=25; 
				%items_b={};
			}
		}
		case 21 { # SOSA
			if (/^<td[^>]*>(.+)<\/td>/) {
				$sosa=un_urlize($1);
				$sosa =~ s/ //g;
				$state=22;
			}
			#print "====$sosa====\n"
		}
		case 22 { # Principal
			if (/^<td[^>]*>(.+)<\/td>/) {
				$datas=$1;
				if ($datas =~ (/<a href=".+\?(.+)">(.*)<\/a>/)) {
					$url=$1;
				foreach $item (split /&/, $url) {
						($key,$value)=split "=",$item;
						$items_a{$key}=un_urlize($value);
						#print "$key --> $value\n";
					}
				}
				$state=23; 
			}
		}
		case 23 { # DATE naiss
			if (/^<td[^>]*>(.*)<\/td>/) {
				$dn=$1;
				$state=24;
			}
		}
		case 24 { # Lieu naiss
			if (/^<td[^>]*>(.*)<\/td>/) {
				$ln=$1;
				$state=25;
			}
		}
		case 25 { # Second membre du couple
			if (/^<\/tr>/) { $state=ST_AFF; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$datas=$1;
				if ($datas =~ (/<a href=".+\?(.+)">(.*)<\/a>/)) {
					$url=$1;
					foreach $item (split /&/, $url) {
						($key,$value)=split "=",$item;
						$items_b{$key}=un_urlize($value);
						#print "$key --> $value\n";
					}
				}
				$state=26; 
			}
		}
		case 26 { # DATE mariage
			if (/^<\/tr>/) { $state=ST_AFF; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$dm=$1;
				$state=27;
			}
		}
		case 27 { # Lieu naissB
			if (/^<\/tr>/) { $state=ST_AFF; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$lm=$1;
				$state=28;
			}
		}
		case 28 { # NB enfants
			if (/^<\/tr>/) { $state=ST_AFF; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$nbe=$1;
				$state=29;
			}
		}
		case 29 { # date deces
			if (/^<\/tr>/) { $state=ST_AFF; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$dd=$1;
				$state=290;
			}
		}
		case 290 { # Lieu deces
			if (/^<\/tr>/) { $state=ST_AFF; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$ld=$1;
				$state=291;
			}
		}
		case 291 { # Age
			if (/^<\/tr>/) { $state=ST_AFF; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$age=$1;
				$state=292;
			}
		}
		case 292 { # Prof
			if (/^<\/tr>/) { $state=ST_AFF; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$prof=$1;
				$state=ST_AFF;
			}
		}


		case ST_AFF { # CSV
			# prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;jour_décès_lui;mois_décès_lui;année_décès_lui;lieu_décès_lui;métier_lui;prénom_elle;nom_elle;jour_naiss_elle;mois_naiss_elle;année_naiss_elle;lieu_naiss_elle;jour_décès_elle;mois_décès_elle;année_décès_elle;lieu_décès_elle;métier_elle;jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant
			# prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;
			# SOSA ; Prenom ; Nom ; Dat ; Naiss ; Lui ; Lieu ; 
			print "=============\n= " if DEBUG;
			print "$sosa;";
			print " =\n# prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;\n" if DEBUG;
			foreach $k (p, n) {
				print "$items_a{$k};"
			}
			print parse_date($dn).";";
			print "$ln;";

			print "\n# jour_décès_lui;mois_décès_lui;année_décès_lui;lieu_décès_lui;métier_lui;\n" if DEBUG;
			print parse_date($dd).";";
			print "$ld;";
			print "$prof;";

			print "\n# prénom_elle;nom_elle;jour_naiss_elle;mois_naiss_elle;année_naiss_elle;\n" if DEBUG;
			foreach $k (p, n) {
				print "$items_b{$k};"
			}
			print ";;;;";

			print "\n# lieu_naiss_elle; \n" if DEBUG; 
			print ";";

			print "\n# jour_décès_elle;mois_décès_elle;année_décès_elle;lieu_décès_elle; \n" if DEBUG;
			print ";;;;";

			print "\n# métier_elle; \n" if DEBUG;
			print ";";

			print "\n# jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant \n" if DEBUG;
			print parse_date($dm).";";
			print "$lm;";
			print "$nbe\n";
			if (/^<tr>/) { $state=21; } else { $state=ST_INTERLIGNE }
		}
	}	
$_="";

}
