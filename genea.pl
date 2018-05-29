#!/usr/bin/perl

use utf8;
use open ':std', ':encoding(UTF-8)';
use feature 'unicode_strings';

## License : GPL

## Historique
# 0.8 : 28/05/18 : Early debug
# 0.9 : 28/05/18 : première ébauche de CSV
# 1.0 : 29/05/18 : Formalisation, constantes, correction des dates, première version versionnée

# Dependencies :
# CPAN - DateTime::Calendar::FrenchRevolutionary

######

use constant VERSION 		=> "1.1";

# DEBUG LEVEL
use constant { 
	TRACE	=> 5,
	DEBUG	=> 4,
	INFO	=> 3,
	WARN	=> 2,
	ERR	=> 1,
	CRIT	=> 0
};

$DEBUG_LEVEL=CRIT;

use constant LEVEL => [ qw/CRIT ERR WARN INFO DEBUG TRACE/ ];

use Switch;
#use DateTime::Calendar::FrenchRevolutionary;
use Text::Unidecode qw(unidecode);
use HTML::Entities qw(decode_entities);

#use constant FORMAT		=> "SOSA;prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;jour_décès_lui;mois_décès_lui;année_décès_lui;lieu_décès_lui;métier_lui;prénom_elle;nom_elle;jour_naiss_elle;mois_naiss_elle;année_naiss_elle;lieu_naiss_elle;jour_décès_elle;mois_décès_elle;année_décès_elle;lieu_décès_elle;métier_elle;jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant";
use constant FORMAT		=> "SOSA;prénom_lui;nom_lui;periode_naiss_lui;date_naiss_lui;lieu_naiss_lui;periode_décès_lui;date_décès_lui;lieu_décès_lui;métier_lui;prénom_elle;nom_elle;periode_naiss_elle;date_naiss_elle;lieu_naiss_elle;periode_décès_elle;date_décès_elle;lieu_décès_elle;métier_elle;periode_marr;date_marr;lieu_marr;nb_enfant";

# State
use constant ST_INTERLIGNE	=> 20;
use constant ST_AFF 		=> 30;

# Globales
my @lines; # contient les données à afficher
my $line;  # contient les données à afficher

my $state=0;
foreach $opt (@ARGV){
	switch ($state) {
		case 0 { $state=2 if $opt eq "-v"}
		case 2 { $state=0; $DEBUG_LEVEL=$opt}
	}
}

sub message {
	my ($alert_level,$message)=@_;
	print STDERR LEVEL->[$alert_level]." $alert_level: $message\n" if $DEBUG_LEVEL >= $alert_level;
}

sub add_line { # Concatenation de donnees en une ligne
	my ($tmp_line,$alert_level,$message)=@_;
	message ($alert_level,$message) if $message;
	# Nettoyage du HTML
	$line.=unidecode(decode_entities($tmp_line));
}

# Conversion URL_ENCODE vers ANSI classique
sub un_urlize {
	my ($rv) = @_;
	$rv =~ s/\+/ /g;
	$rv =~ s/%(..)/pack("c",hex($1))/ge;
	return $rv;
}

sub revo2greg {
	my ($date)=@_;
}

# Conversion URL_ENCODE vers ANSI classique
sub parse_date {
	my ($date_in) = @_;	
	my $date;
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
	# Remplacement des / en -
	$date =~ s/\//-/g;
	message  DEBUG, "| $periode ---- $date ---- $comm |";
	message  DEBUG, "$state";

	switch ($comm) { # Type de date
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
	switch ($periode) { # avant, après, peut-être... TODO : traductions d'autres langues
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
	$date =~ s/ +$/!/; 
	message DEBUG, "| $periode ---- $date ---- $comm |";
	return $date;
}

my $state=0;

# Entête
push @lines,"# <GeneaParse v".VERSION.">";
push @lines,FORMAT;

while (<STDIN>) {
	print "$state $_" if DEBUG_LEVEL >= TRACE;
	# s/&nbsp;/ /g;

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
			message TRACE,"======\n";
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
				$sosa =~ s/(&nbsp;| )//g;
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
						message TRACE, "$key --> $value";
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
						message TRACE, "$key --> $value";
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
			$line="";
			message INFO,"====================";
			add_line $sosa.';',INFO,"=== $sosa ===";
			message DEBUG,"# prénom_lui;nom_lui;periode_naiss_lui;date_naiss_lui;lieu_naiss_lui;";
			foreach $k (p, n) {
				add_line "$items_a{$k};",DEBUG,$k.":".$items_a{$k};
			}
			add_line parse_date($dn).";",DEBUG,"dn:$dn";
			add_line "$ln;",DEBUG,"ln:$ln";

			message DEBUG,"# periode_décès_lui;date_décès_lui;lieu_décès_lui;métier_lui;";
			add_line parse_date($dd).";",DEBUG,"dd:$dd";
			add_line "$ld;";
			add_line "$prof;";

			message DEBUG,"# prénom_elle;nom_elle;periode_naiss_elle;date_naiss_elle;";
			foreach $k (p, n) {
				add_line "$items_b{$k};",DEBUG,$k.":".$items_b{$k};
			}
			add_line ";";

			message DEBUG, "# lieu_naiss_elle;";
			add_line ";";

			message DEBUG, "# periode_décès_elle;date_décès_elle;lieu_décès_elle;";
			add_line ";;;;";

			message DEBUG,"# métier_elle";
			add_line ";";

			message DEBUG, "# jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant";
			message DEBUG, "$dm;$lm;$nbe";
			add_line parse_date($dm).";";
			add_line "$lm;";
			add_line "$nbe";

			push @lines,$line;
			message DEBUG,$line;

			if (/^<tr>/) { $state=21; } else { $state=ST_INTERLIGNE }
		}
	}	

}

foreach (@lines) {
	print "$_\n";
}
