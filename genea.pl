#!/usr/bin/perl

use 5.010;
use utf8;
use open ':std', ':encoding(UTF-8)';
use feature 'unicode_strings';
#use warnings;

## License : GPL

## Historique
# 0.8 : 28/05/18 : Early debug
# 0.9 : 28/05/18 : première ébauche de CSV
# 1.0 : 29/05/18 : Formalisation, constantes, correction des dates, première version versionnée
# 1.1 : 29/05/18 : Multiple verboses, fin de cas de précision de date
# 1.2 : 29/05/18 : Retour format CSV initial, traitement des dates révolutionnaire
#                : ajout de précision sur année, uppercase ; recupération des diacritiques.
# 1.3 : 30/05/18 : Suppression du module Switch - switch limit - help page - debug dates & accents
#                : Fix bug de logique sur les majuscules des prénoms - recombinaison compatible forme combinée unicode
# 1.4 : 30/05/18 : Ajout affichage en forme d'arbre

# Dependencies :
# CPAN - Text::Unidecode qw(unidecode);
#      - HTML::Entities qw(decode_entities);
#      - Unicode::Normalize;

######

use constant VERSION 		=> "1.4";

# DEBUG LEVEL
use constant { 
	XTRACE	=> 6,
	TRACE	=> 5,
	DEBUG	=> 4,
	INFO	=> 3,
	WARN	=> 2,
	ERR	=> 1,
	CRIT	=> 0
};

use constant LEVEL => [ qw/CRIT ERR WARN INFO DEBUG TRACE XTRACE XXTRACE XXXTRACE/ ];

#use Switch; # deprecated
#use DateTime::Calendar::FrenchRevolutionary;
use Text::Unidecode qw(unidecode);
use HTML::Entities qw(decode_entities);
use Unicode::Normalize;

use constant FORMAT		=> "SOSA;prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;jour_décès_lui;mois_décès_lui;année_décès_lui;lieu_décès_lui;métier_lui;prénom_elle;nom_elle;jour_naiss_elle;mois_naiss_elle;année_naiss_elle;lieu_naiss_elle;jour_décès_elle;mois_décès_elle;année_décès_elle;lieu_décès_elle;métier_elle;jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant";
#use constant FORMAT		=> "SOSA;prénom_lui;nom_lui;periode_naiss_lui;date_naiss_lui;lieu_naiss_lui;periode_décès_lui;date_décès_lui;lieu_décès_lui;métier_lui;prénom_elle;nom_elle;periode_naiss_elle;date_naiss_elle;lieu_naiss_elle;periode_décès_elle;date_décès_elle;lieu_décès_elle;métier_elle;periode_marr;date_marr;lieu_marr;nb_enfant";

# State
use constant ST_INTERLIGNE	=> 20;
use constant ST_AFF 		=> 30;
use constant ST_DATE_NAISS	=> 23;
use constant ST_DATE_MARIAGE	=> 26;
use constant ST_DATE_DECES	=> 29;

# Globales
my $state=0;
my @lines; # contient les données à afficher
my %lines; # contient les données à afficher
my $line;  # contient les données à afficher
my $last_sosa=0;

my $SW_LIMIT=0;
my $SW_DEBUG=0;
my $SW_TREE=0;
my $SOSA_LIMIT=0;
my $DEBUG_LEVEL=CRIT;
my $TREE_LIMIT=0;


sub message { # Affichage d'un message selon verbosité
	my ($alert_level,$message)=@_;
	print STDERR LEVEL->[$alert_level]." $alert_level: $message\n" if $DEBUG_LEVEL >= $alert_level;
}

sub add_line { # Concatenation de donnees en une ligne (vers CSV)
	my ($tmp_line,$alert_level,$message)=@_;
	message ($alert_level,$message) if $message;
	# Nettoyage du HTML
	$line.=decode_entities($tmp_line);
	#$line.=unidecode(decode_entities($tmp_line));
}

# Conversion URL_ENCODE vers ANSI classique
sub un_urlize {
	my ($rv) = @_;
	$rv =~ s/\+/ /g;
	$rv =~ s/%(..)/pack("c",hex($1))/ge;
	return $rv;
}

sub revo2greg { # To be written
	my ($date)=@_;
}

# Conversion URL_ENCODE vers ANSI classique, nettoyage, découpage jj;mm;aaaa et précision
sub parse_date {
	my ($date_in) = @_;	
	my $date='';
	my $periode=''; my $comm='';
	my $jour='';my $mois='';my $an='';

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

	$date =~ s/ +$/!/; 
	if ($date =~ /^(\d{2})-([\dA-Z]{2})-([\dXIV]+)$/) {
		$jour=$1;
		$mois=$2;
		$an=$3;
	} elsif ($date =~ /^([\dA-Z]{2})-([\dXIV]+)$/) {
		$jour="";
		$mois=$1;
		$an=$2;
	} elsif ($date =~ /^([\dXIV]+)$/) {
		$jour="";
		$mois="";
		$an=$1;
	}
	given ($an) { # Serait mieux dans un hash
		when ('I') { $an=1; }    when ('II') { $an=2; }    when ('III') { $an=3; }
		when ('IIII') { $an=4; } when ('IV') { $an=4; }    when ('V') { $an=5; }
		when ('VI') { $an=6; }   when ('VII') { $an=7; }   when ('VIII') { $an=8; }
		when ('IX') { $an=9; }   when ('X') { $an=10; }    when ('XI') { $an=11; }
		when ('XII') { $an=12; } when ('XIII') { $an=13; } when ('I') { $an=1; }
	}

#	switch ($comm) { # Type de date
#		case /républicain/ {
#			#revo2greg(\$date);
#			$date="R:$date";
#		}
#		case /\(julien\)/ {
#			#revo2greg(\$date);
#			$date="J:$date";
#		}
#		case /\(hebrew\)/ {
#			#revo2greg(\$date);
#			$date="H:$date";
#		}
#		else {
#			$date="$date";
#		}
#	}

	given ($periode) { # avant, après, peut-être... TODO : traductions d'autres langues
		when (/^peut-être ?$/) {
			$an="?$an";
		}
		when (/^environ ?$/) {
			$an="/$an/";
		}
		when (/^vers ?$/) {
			$an="/$an/";
		}
		when (/^avant ?$/) {
			$an="/$an";
		}
		when (/^apr.s ?$/) {
			$an="$an/";
		}
	}
	message DEBUG, "| $periode ---- $date ---- $comm |";
	$date="$jour;$mois;$an";
	return $date;
}

sub parse_patronyme { # Decoupage du patronyme en tronçon, selon les paramètres URL et l'affichage
        # nettoyage et passage unicode, accentuation, majuscules et minuscules forcées
	my ($url,$patronyme)=@_;
	my $prenom="",$nom="",$surname="";
	my %items;

	# Récupération selon les variables URL
	foreach $item (split /&/, $url) {
		($key,$value)=split "=",$item;
		$items{$key}=un_urlize($value);
		message TRACE, "$key --> $value";
	}
	$prenom=$items{p};
	$nom=$items{n};
	message TRACE,"PP:$patronyme:$prenom:$nom:";
	if ($patronyme =~ / <em>(.+)<\/em> /){
		$surname=$1;
		message DEBUG,"$patronyme - $` $'";
	}

	# Passage en bas de casse UTF-8 de la chaine HTML dans une temporaire
	$tmp_patro = NFD(lc($patronyme)); 
	# NFD -> Normalisation et décomposition en forme D, ie. lettre pure ansi et diacritique combinants
	# Servira à la suppression des diacritiques combinants
	message TRACE,"PP:$patronyme:$tmp_patro:";

	# Suppression des diacritiques dans la chaine HTML dans la temporaire
	if ($tmp_patro =~ s/\pM//g) {
		# \p{M} or \p{Mark}: a character intended to be combined with another character (e.g. accents, umlauts, enclosing boxes, etc.). 
		# Remplacement des tirets et élisions par des espaces
		$tmp_patro =~ s/['-]/ /g;
		message DEBUG,"Accents detectes. $tmp_patro";
		# Dénominateur commun : sans diacritique, bas de casse
		$tmp = NFD(lc($nom));
		message DEBUG,"LC CHECK $tmp";
		# Recupération de l'index de position de la variable dans le commentaire HTML bas de casse et désaccentué
		if ($tmp =~ /^[\p{L}' -]+$/) {
			# \p{L} matches a single code point in the category "letter".
			$index=index($tmp_patro,$tmp);
			message INFO,"Catch : $tmp ($index)";
			message TRACE,"PP:$tmp_patro:$tmp:$index!";
			message TRACE,"PP:$patronyme:$index:".length($tmp)."!";
			# Récupération de la sous chaîne dans l'originade
			$nom=substr($patronyme,$index,length($tmp));
		}
		# Même process avec le prenom
		$tmp = NFD(lc($prenom));
		message DEBUG,"LC CHECK $tmp";
		if ($tmp =~ /^[\p{L}' -]+$/) {
			$index=index($tmp_patro,$tmp);
			message INFO,"Catch : $tmp ($index)";
			message TRACE,"PP:$tmp_patro:$tmp:$index!";
			message TRACE,"PP:$patronyme:$index!".length($tmp);
			$prenom=substr($patronyme,$index,length($tmp));
		}
	}

	# Et reformation de la casse : "Prénom-Composé" "NOM-COMPOSÉ"
	# Plus recomposition canonique (transformation des glyphes + dacritiques combinants en glybhes combinés)
	# Pour compatibilité maximale
	message TRACE,"PP:$nom:$prenom:";
	$nom =~ s/([\w' -]+)/\U$1/g;
	$nom = NFC($nom);
	$prenom =~ s/([\w]+)/\u\L$1/g;
	$prenom = NFC($prenom);
	message INFO,"Resultat : P:$prenom N:$nom";
	return ($prenom,$nom,$surname);
}

my %GENERATION = qw( 1  1
	2  2
	4  3
	8  4
	16  5
	32  6
	64  7
	128  8
	256  9
	512  10
	1024  11
	2048  12
	4096  13
	8182  14
      );

sub get_gen {
	my ($sosa)=@_;
	my $msb=(($sosa | ($sosa >> 1) | ($sosa >> 2) | ($sosa >> 4) | ($sosa >> 8) | ($sosa >> 16) | ($sosa >> 32)) >> 1)  + 1;
	message DEBUG,"$sosa -> $msb -> $GENERATION{$msb}";
	return $GENERATION{$msb};
}


sub print_sosa {
	my ($sosa,$max_sosa)=@_;
	if ($sosa<$max_sosa) {
		my $gen=get_gen($sosa);
		if ($lines{$sosa} && $gen<=$TREE_LIMIT) {
			message TRACE, "$sosa - ".$gen;
			foreach $ref (@{$lines{$sosa}}) {
				printf "Gen %3s: %s\n",$gen,$lines[$ref];
			}
		} else {
			message DEBUG, "$sosa - ".get_gen($sosa)."XX";
		}
		#print " " x get_gen($sosa) . $sosa."\n";
		print_sosa($sosa*2,$max_sosa);
		print_sosa($sosa*2+1,$max_sosa);
	} else {
		return
	}
}

sub show_help {
	print "
Usage :
genea.pl [-v <LEVEL>] [-l <SOSA>] [-h|-?]
	-v <LEVEL> : avec <LEVEL> compris entre 0 (silencieux) et 6 (Xtra Trace)
	-l <SOSA>  : ne traite que le sosa <SOSA>
	-t <LEVEL> : affiche sous forme d'arbre, niveau <LEVEL> maximal
";
	exit;
}

###########################################################################

foreach my $opt (@ARGV){
	given ($state) {
		when (0) { 
			$state=2 if $opt eq "-v";
			$state=4 if $opt eq "-l";
			$state=6 if $opt eq "-t";
			show_help if $opt eq "-?";
			show_help if $opt eq "-h";
			show_help if $state == 0;	
		}
		when (2) { 
			$state=0; 
			$DEBUG_LEVEL=$opt;
			$SW_DEBUG=1;
		}
		when (4) { 
			$state=0; 
			$SW_LIMIT=1;
			$SOSA_LIMIT=$opt;
		}
		when (6) { 
			$state=0;
			$SW_TREE=1;
			$TREE_LIMIT=$opt;
		}
	}
}

$state=0;

message DEBUG, "Options : $SW_LIMIT : $SOSA_LIMIT - $SW_DEBUG : $DEBUG_LEVEL";


# Entête
push @lines,FORMAT;

foreach my $li (<STDIN>) {
	chomp $li;
	message XTRACE, "$state:$li!";
	# s/&nbsp;/ /g;

	given ($state) {
		when (0) {
			if ($li =~ /^<h2><span class="htitle">&nbsp;<\/span><span>(.+)<\/span><\/h2>/) {
				$root_sosa=$1;
				$state=1;
			}
			message TRACE,"-- $state";
		}
		when (1) {
			if ($li =~ /^<tbody>/) { $state=2; }
			message TRACE,"-- $state";
		}
		when (2) {
			if ($li =~ /^<\/tr>/) { $state=ST_INTERLIGNE; }
		}
		when (ST_INTERLIGNE) { # Interligne
			message INFO,"====================";
			if ($li =~ /^<tr>/) { 
				$state=201; 
				%items_a=();
				%items_b=();
			}
			if ($li =~ /^<tr dontbreak="1">/) {  # suite d'un mariage multiple
				$state=205; 
				%items_b=();
			}
			message TRACE,"-- $state";
		}
		when (201) { # SOSA
			if ($li =~ /^<td[^>]*>(.+)<\/td>/) {
				$sosa=un_urlize($1);
				$sosa =~ s/(&nbsp;| )//g;
				$last_sosa = $sosa if ($sosa > $last_sosa);
				$state=22;
				message INFO,"==== $sosa ====";
			}
			chomp;
			message TRACE,"-- $state $_";
		}
		when (22) { # Principal
			$state=ST_INTERLIGNE if ($li =~ /^<\/tr>/);
			next if ($SW_LIMIT and $SOSA_LIMIT!=$sosa);
			if ($li =~ /^<td[^>]*>(.+)<\/td>/) {
				$datas=$1;
				if ($datas =~ (/<a href=".+\?(.+)">(.*)<\/a>/)) {
					($items_a{p},$items_a{n},$tmp)=parse_patronyme($1,$2);
				}
				$state=ST_DATE_NAISS; 
				message TRACE,"-- $state Items n/p : $1 $2";
			}
		}
		when (ST_DATE_NAISS) { # DATE naiss
			if ($li =~ /^<td[^>]*>(.*)<\/td>/) {
				message DEBUG,"Naissance:$1";
				$dn=$1;
				$state=24;
			}
		}
		when (24) { # Lieu naiss
			if ($li =~ /^<td[^>]*>(.*)<\/td>/) {
				$ln=$1;
				$state=205;
			}
		}
		when (205) { # Second membre du couple
			$state=ST_INTERLIGNE if ($li =~ /^<\/tr>/ and $SOSA_LIMIT!=$sosa);
			next if ($SW_LIMIT and $SOSA_LIMIT!=$sosa);
			$state=ST_AFF if ($li =~ /^<\/tr>/);
			if ($li =~ /^<td[^>]*>(.*)<\/td>/) {
				$datas=$1;
				if ($datas =~ (/<a href=".+\?(.+)">(.*)<\/a>/)) {
					($items_b{p},$items_b{n},$tmp)=parse_patronyme($1,$2)
				}
				$state=ST_DATE_MARIAGE; 
				message TRACE,"-- $state $datas";
			}
		}
		when (ST_DATE_MARIAGE) { # DATE mariage
			$state=ST_AFF if ($li =~ /^<\/tr>/);
			if ($li =~ /^<td[^>]*>(.*)<\/td>/) {
				message DEBUG,"Mariage:$1";
				$dm=$1;
				$state=27;
			}
		}
		when (27) { # Lieu naissB
			$state=ST_AFF if ($li =~ /^<\/tr>/);
			if ($li =~ /^<td[^>]*>(.*)<\/td>/) {
				$lm=$1;
				$state=28;
			}
		}
		when (28) { # NB enfants
			$state=ST_AFF if ($li =~ /^<\/tr>/);
			if ($li =~ /^<td[^>]*>(.*)<\/td>/) {
				$nbe=$1;
				$state=ST_DATE_DECES;
			}
		}
		when (ST_DATE_DECES) { # date deces
			$state=ST_AFF if ($li =~ /^<\/tr>/);
			if ($li =~ /^<td[^>]*>(.*)<\/td>/) {
				message DEBUG,"Deces:$1";
				$dd=$1;
				$state=290;
			}
		}
		when (290) { # Lieu deces
			$state=ST_AFF if ($li =~ /^<\/tr>/);
			if ($li =~ /^<td[^>]*>(.*)<\/td>/) {
				$ld=$1;
				$state=291;
			}
		}
		when (291) { # Age
			$state=ST_AFF if ($li =~ /^<\/tr>/);
			if ($li =~ /^<td[^>]*>(.*)<\/td>/) {
				$age=$1;
				$state=292;
			}
		}
		when (292) { # Prof
			$state=ST_AFF if ($li =~ /^<\/tr>/);
			if ($li =~ /^<td[^>]*>(.*)<\/td>/) {
				message DEBUG,"Prof:$1";
				$prof=$1;
				$state=ST_AFF;
			}
		}


		when (ST_AFF) { 
			if ($SW_TREE) { # Arbre ##########
				# prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;
				# SOSA ; Prenom ; Nom ; Dat ; Naiss ; Lui ; Lieu ; 
				$line="";
				my $level=$sosa / 2;
				add_line " " x get_gen($sosa) x 2 . " - $sosa - ";
				add_line "$items_a{n} $items_a{p} ($dn à $ln / $dd à $ld) - $prof - $nbe enfants.";

				$line =~s/;\s+;/;;/g;
				push @lines,$line;
				push @{$lines{$sosa}},$#lines;
				message DEBUG,$line;
			} else { # CSV ##############
				# prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;jour_décès_lui;mois_décès_lui;année_décès_lui;lieu_décès_lui;métier_lui;prénom_elle;nom_elle;jour_naiss_elle;mois_naiss_elle;année_naiss_elle;lieu_naiss_elle;jour_décès_elle;mois_décès_elle;année_décès_elle;lieu_décès_elle;métier_elle;jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant
				# prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;
				# SOSA ; Prenom ; Nom ; Dat ; Naiss ; Lui ; Lieu ; 
				$line="";
				add_line $sosa.";";
				message DEBUG,"# prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;an_naiss_lui;lieu_naiss_lui;";
				foreach $k ('p', 'n') {
					add_line "$items_a{$k};",DEBUG,$k.":".$items_a{$k};
				}
				add_line parse_date($dn).";",DEBUG,"dn:$dn";
				add_line "$ln;",DEBUG,"ln:$ln";

				message DEBUG,"# periode_décès_lui;date_décès_lui;lieu_décès_lui;métier_lui;";
				add_line parse_date($dd).";",DEBUG,"dd:$dd";
				add_line "$ld;";
				add_line "$prof;";

				message DEBUG,"# prénom_elle;nom_elle;jour_naiss_elle;mois_naiss_elle;an_naiss_elle;";
				foreach $k ('p', 'n') {
					add_line "$items_b{$k};",DEBUG,$k.":".$items_b{$k};
				}
				add_line ";;;";

				message DEBUG, "# lieu_naiss_elle;";
				add_line ";";

				message DEBUG, "# jour_décès_elle;mois_décès_elle;an_décès_elle;lieu_décès_elle;";
				add_line ";;;;";

				message DEBUG,"# métier_elle";
				add_line ";";

				message DEBUG, "# jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant";
				message DEBUG, "$dm;$lm;$nbe";
				add_line parse_date($dm).";";
				add_line "$lm;";
				add_line "$nbe";

				$line =~s/;\s+;/;;/g;
				push @lines,$line;
				message DEBUG,$line;
			}

			if (/^<tr>/) { $state=201; } else { $state=ST_INTERLIGNE }
		}
	};

}

if ($SW_TREE) {
	message WARN,"==== ARBRE - $last_sosa";

	print "Affichage de l'arbre ascendant par SOSA (generation max : $TREE_LIMIT)\n";
	print "------------------------------------------------------------------\n";
	print_sosa(1,$last_sosa);
} else {
	message WARN,"==== LINE";
	unshift @lines,"# <GeneaParse v".VERSION.">";
	foreach (@lines) {
		print "$_\n";
		#message INFO,"$_";
	}
}
