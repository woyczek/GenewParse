#!/usr/bin/perl

$state=0;

use Switch;

sub un_urlize {
	my ($rv) = @_;
	$rv =~ s/\+/ /g;
	$rv =~ s/%(..)/pack("c",hex($1))/ge;
	$rv =~ s/&nbsp;/ /g;
	return $rv;
}


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
			if (/^<\/tr>/) { $state=20; }
		}
		case 20 { # Interligne
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
		case 23 { # DATE naissA
			if (/^<td[^>]*>(.*)<\/td>/) {
				$dn_a=$1;
				$state=24;
				$dn_a =~ s/(.*) .*/$1/;
			}
		}
		case 24 { # Lieu naissA
			if (/^<td[^>]*>(.*)<\/td>/) {
				$ln_a=$1;
				$state=25;
			}
		}
		case 25 { # Second membre du couple
			if (/^<\/tr>/) { $state=30; }
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
		case 26 { # DATE naissB
			if (/^<\/tr>/) { $state=30; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$dn_b=$1;
				$state=27;
				$dn_b =~ s/(.*) .*/$1/;
			}
		}
		case 27 { # Lieu naissB
			if (/^<\/tr>/) { $state=30; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$ln_b=$1;
				$state=28;
			}
		}
		case 28 { # NB enfants
			if (/^<\/tr>/) { $state=30; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$nbe=$1;
				$state=29;
			}
		}
		case 29 { # date mariage
			if (/^<\/tr>/) { $state=30; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$dm=$1;
				$state=290;
				$dm =~ s/(.*) .*/$1/;
			}
		}
		case 290 { # Lieu mariage
			if (/^<\/tr>/) { $state=30; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$lm=$1;
				$state=291;
			}
		}
		case 291 { # Age
			if (/^<\/tr>/) { $state=30; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$age=$1;
				$state=292;
			}
		}
		case 292 { # Prof
			if (/^<\/tr>/) { $state=30; }
			if (/^<td[^>]*>(.*)<\/td>/) {
				$prof=$1;
				$state=30;
			}
		}


		case 30 { # CSV
			# prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;jour_décès_lui;mois_décès_lui;année_décès_lui;lieu_décès_lui;métier_lui;prénom_elle;nom_elle;jour_naiss_elle;mois_naiss_elle;année_naiss_elle;lieu_naiss_elle;jour_décès_elle;mois_décès_elle;année_décès_elle;lieu_décès_elle;métier_elle;jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant
			print "$sosa;";
			foreach $k (p, n) {
				print "$items_a{$k};"
			}
			$dn_a =~ s/\//;/g;
			print "$dn_a;";
			print "$ln_a;";
			print ";;;;";
			print "$prof;";
			foreach $k (p, n) {
				print "$items_b{$k};"
			}
			$dn_b =~ s/\//;/g;
			print "$dn_b;";
			print "$ln_b;";
			print ";;;;";
			print ";";
			$dm =~ s/\//;/g;
			print "$dm;";
			print "$lm;";
			print "$nbe\n";
			if (/^<tr>/) { $state=21; } else { $state=20 }
		}
		case 31 { # Affichage
			print "=============\n";
			print "SOSA : $sosa\n";
			foreach $k (p, n, oc) {
				print "$k : $items_a{$k}\n";
			}
			print "dn 1 : $dn_a\n";
			print "ln 1 : $ln_a\n";
			foreach $k (p, n, oc) {
				print "$k : $items_b{$k}\n"
			}
			print "dn 2 : $dn_b\n";
			print "ln 2 : $ln_b\n";
			print "mariage : $dm\n";
			print "lieu mariage : $lm\n";
			print "profession : $prof\n";
			print "age : $age\n";
			print "nb enfants : $nbe\n";
			if (/^<tr>/) { $state=21; } else { $state=20 }
		}
	}	
$_="";

}
