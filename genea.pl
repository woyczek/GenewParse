#!/usr/bin/perl

use v5.10;
use utf8;
use open ':std', ':encoding(UTF-8)';
use feature 'unicode_strings';
#use warnings;
use experimental qw(smartmatch);

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
# 1.5 : 31/05/18 : Ajout fichiers i/o + curl
# 1.6 : 07/06/18 : Fix accents on first name, add switch to ignore case normalization, add implexes
# 1.7 : 07/06/18 : Add titles to tree view

## TODO
# Faire quelque chose des titres
# Faire quelque chose des surnoms, alias, et autres grumeaux de patronyme
# gérer les divers calendriers (actuellement, on délègue cela à l'import)

#############################################
# https://github.com/woyczek/GeneaParse.git #
#############################################

# Dependencies :
# CPAN - Text::Unidecode qw(unidecode);
#      - HTML::Entities qw(decode_entities);
#      - Unicode::Normalize;
#      - experimental;

use constant VERSION 		=> "1.7";
use constant COMMIT_ID 		=> '$Id$';
use constant COMMIT_DATE        => '$Format:%ci$ - $Format %ar$ ($Format:%h$)';

#use Switch; # deprecated
#use DateTime::Calendar::FrenchRevolutionary;
use Text::Unidecode qw(unidecode);
use HTML::Entities qw(decode_entities);
use Unicode::Normalize;

use constant FORMAT		=> "SOSA;prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;jour_décès_lui;mois_décès_lui;année_décès_lui;lieu_décès_lui;métier_lui;prénom_elle;nom_elle;jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant";

# State
use constant ST_INTERLIGNE	=> 20;
use constant ST_AFF 		=> 30;
use constant ST_DATE_NAISS	=> 23;
use constant ST_DATE_MARIAGE	=> 26;
use constant ST_DATE_DECES	=> 29;

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

# Globales
my $state=0;
my @lines; # contient les données à afficher
my %lines; # contient les données à afficher
my $line;  # contient les données à afficher
my $last_sosa=0;

my $SW_LIMIT=0;
my $SW_DEBUG=0;
my $SW_TREE=0;
my $SW_IN=0;
my $SW_OUT=0;
my $SW_CURL=0;
my $SW_NORM=1;
my $SW_TITRE=1;
my $DISTANT_URL='';
my $SOSA_LIMIT=0;
my $DEBUG_LEVEL=CRIT;
my $TREE_LIMIT=0;

my $RE_CAR = "'’–−-"; # The dash MUST be the last one -- le trait d'union doit être le dernier
my $RE_CAR_SEP = qr/[${RE_CAR}]/;
my $RE_CAR_NOM = qr/^[\p{L}  ${RE_CAR}]+$/;
my $RE_CAR_WORD = qr/[\w  ${RE_CAR}]+/;

sub message { # Affichage d'un message selon verbosité
	my ($alert_level,$message)=@_;
	print STDERR LEVEL->[$alert_level]." $alert_level: $message\n" if $DEBUG_LEVEL >= $alert_level;
	exit 1 if $alert_level==CRIT;
}

sub add_line { # Concatenation de donnees en une ligne (vers CSV)
	my ($tmp_line,$alert_level,$message)=@_;
	message ($alert_level,$message) if $message;
	# Nettoyage du HTML
	$line.=decode_entities($tmp_line);
	#$line.=unidecode(decode_entities($tmp_line));
}

sub un_urlize { # Conversion URL_ENCODE vers ANSI classique
	my ($rv) = @_;
	$rv =~ s/\+/ /g;
	$rv =~ s/%(..)/pack("c",hex($1))/ge;
	return $rv;
}

sub revo2greg { # To be written
	my ($date)=@_;
}

sub parse_date { # Conversion URL_ENCODE vers ANSI classique, nettoyage, découpage jj;mm;aaaa et précision
	my ($date_in) = @_;	
	my $date='';
	my $periode=''; my $comm='';
	my $jour='';my $mois='';my $an='';

	# Précision, date, calendrier
	if ($date_in =~ / ([^ ]+\/[^ ]+) /) {
		$periode=$`;
		$date=$1;
		$comm=$';
	}
	# Précision, date
	elsif ($date_in =~ /^(\w+) ([^ ]+)/){
		$date=$2;
		$periode=$1;
		$comm="";
	}
	# Date, calendrier
	elsif ($date_in =~ /^([^ ]+) ([\w()]+)/){
		$periode="";
		$date=$1;
		$comm=$2;
	}
	# Date seule
	elsif ($date_in =~ /^([^ ]+)$/){
		$periode="";
		$date=$1;
		$comm="";
	}
	# Default : tel quel.
	else {
		$date = $date_in;
	}
	# Remplacement des / en -
	$date =~ s/\//-/g;
	message  DEBUG, "| $periode ---- $date ---- $comm |";
	message  TRACE, "$state";

	# Affichage des erreurs. TO BE DELETED
	$date =~ s/ +$/!/; 

	# Allez, on découpe en jj/mm/aa+
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
	# Conversion révol - révol, mais numérique
	given ($an) { # Serait mieux dans un hash
		when ('I') { $an=1; }    when ('II') { $an=2; }    when ('III') { $an=3; }
		when ('IIII') { $an=4; } when ('IV') { $an=4; }    when ('V') { $an=5; }
		when ('VI') { $an=6; }   when ('VII') { $an=7; }   when ('VIII') { $an=8; }
		when ('IX') { $an=9; }   when ('X') { $an=10; }    when ('XI') { $an=11; }
		when ('XII') { $an=12; } when ('XIII') { $an=13; } when ('I') { $an=1; }
	}

	# Flag type de calendrier, deprecated (laissé pour mémoire et réactivation le cas échéant)
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
	# Réassemblage
	$date="$jour;$mois;$an";
	return $date;
}

sub parse_patronyme { # Decoupage du patronyme en tronçons, selon les paramètres URL et l'affichage
        # nettoyage et passage unicode, accentuation, majuscules et minuscules forcées
	my ($url,$patronyme)=@_;
	my $prenom="",$nom="",$surname="";
	my %items;
	my $is_diacritic;
	my $is_tiret;

	# Récupération selon les variables URL
	foreach $item (split /&/, $url) {
		($key,$value)=split "=",$item;
		$items{$key}=un_urlize($value);
		message TRACE, "$key --> $value";
	}
	$prenom=$items{p};
	$nom=$items{n};
	message DEBUG,"PP:$patronyme:$prenom:$nom:";
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
	# et Remplacement des tirets et élisions par des espaces
	$is_diacritic=($tmp_patro =~ s/[\pM]//g);
	$is_tiret=($tmp_patro =~ s/$RE_CAR_SEP/ /g);
	if ($is_diacritic || $is_tiret || (!$SW_NORM) ) {
		# \p{M} or \p{Mark}: a character intended to be combined with another character (e.g. accents, umlauts, enclosing boxes, etc.). 
		message DEBUG,"Accents detectes. $tmp_patro - $RE_CAR_SEP";
		# Dénominateur commun : sans diacritique, bas de casse
		$tmp = NFD(lc($nom));
		message DEBUG,"LC CHECK $tmp";
		# Recupération de l'index de position de la variable dans le commentaire HTML bas de casse et désaccentué
		#if ($tmp =~ /^[\p{L}'  ’-]+$/) {
		if ($tmp =~ /$RE_CAR_NOM/) {
			# \p{L} matches a single code point in the category "letter".
			$index=index($tmp_patro,$tmp);
			message INFO,"Catch : $tmp ($index) -- $RE_CAR_SEP -- $RE_CAR_NOM";
			message DEBUG,"PP:$tmp_patro:$tmp:$index!";
			message DEBUG,"PP:$patronyme:$index:".length($tmp)."!";
			# Récupération de la sous chaîne dans l'originade
			$nom=substr($patronyme,$index,length($tmp));
		}
		# Même process avec le prenom
		$tmp = NFD(lc($prenom));
		message DEBUG,"LC CHECK $tmp";
		#if ($tmp =~ /^[\p{L}'  ’–—−-]+$/) {
		if ($tmp =~ /$RE_CAR_NOM/) {
			$index=index($tmp_patro,$tmp);
			message INFO,"Catch : $tmp ($index) -- $RE_CAR_SEP -- $RE_CAR_NOM";
			message DEBUG,"PP:$tmp_patro:$tmp:$index!";
			message DEBUG,"PP:$patronyme:$index!".length($tmp);
			$prenom=substr($patronyme,$index,length($tmp));
		}
	}

	# Et reformation de la casse : "Prénom-Composé" "NOM-COMPOSÉ"
	# Plus recomposition canonique (transformation des glyphes + dacritiques combinants en glybhes combinés)
	# Pour compatibilité maximale
	message TRACE,"PP:$nom:$prenom:";
	#$nom =~ s/([\w'  ’-]+)/\U$1/g;
	$nom =~ s/(${RE_CAR_WORD}+)/\U$1/g if $SW_NORM;
	$nom = NFC($nom);
	$prenom =~ s/([\w]+)/\u\L$1/g if $SW_NORM;
	$prenom = NFC($prenom);
	message INFO,"Resultat : P:$prenom N:$nom";
	return ($prenom,$nom,$surname);
}

# Fonctions d'affichage de l'arbre (ce n'est pas le fonctionnement nominal, mais pratique pour debug)
# Puissances de 2 (position du MSB)
my %GENERATION = qw( 1  1
	2        2
	4        3
	8        4
	16       5
	32       6
	64       7
	128      8
	256      9
	512     10
	1024    11
	2048    12
	4096    13
	8192    14
	16384   15
	32768   16
	65536   17
	131072  18
	262144  19
	524288  20
	1048576 21
      );

# Fonctions d'affichage de l'arbre (ce n'est pas le fonctionnement nominal, mais pratique pour debug)
sub get_gen { # Recupère la position du MSB. Les générations étant des puissances de 2, on utilise un algo binaire.
	my ($sosa)=@_;
	my $msb=$sosa;
	foreach $s (0,1,2,4,8,16,32) {
		$msb=$msb|($msb >> $s);
	}
	return $GENERATION{($msb>>1) + 1};
	message DEBUG,"$sosa -> $msb -> $GENERATION{$msb}";
}

# Fonctions d'affichage de l'arbre (ce n'est pas le fonctionnement nominal, mais pratique pour debug)
sub print_sosa { # Affiche les efants et le n½ud courant ; récursif
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

sub show_help { # Ben, help...
	print STDERR "
GenewParse version ".VERSION." - commit: ".COMMIT_ID." 

Usage :
genea.pl [-v <LEVEL>] [-s <SOSA>] [-t <LEVEL>] [-T] [-N] [-i <INPUT> [-u <URL>] ] [-o <OUTPUT>] [-h|-?]
	-v <LEVEL>  : With <LEVEL> value between 0 (quiet) and 6 (xtra trace).
	-s <SOSA>   : Only process given Sosa number <SOSA>.
	-N          : Disable case normalisation.
	-T          : Disable title catching.
	-t <LEVEL>  : Tree format display, by surname branches, with <LEVEL> as max depth.
	-i <INPUT>  : Input file. If this flag is omitted, the parser will use STDIN.
	-u <URL>    : URL to fetch and save to INPUT file, before processing this file. -i is mandatory, the file will be replaced.
	-o <OUTPUT> : Output file. If omitted, will use STDOUT.
";
	exit;
}

###########################################################################
# Principale

# Automate à états, sur $state.
# Pour chaque paramètre en argument, un tour d'automate.
foreach my $opt (@ARGV){ # Récupération et traitement des paramètres en ligne de commande
	given ($state) {
		message DEBUG, "Getopt $state - $opt";
		when (0) { 
			$state=2 if $opt eq "-v";
			$state=4 if $opt eq "-s";
			$state=6 if $opt eq "-t";
			$state=7 if $opt eq "-u";
			$state=8 if $opt eq "-i";
			$state=9 if $opt eq "-o";
			show_help if $opt eq "-?";
			show_help if $opt eq "-h";
			if ($opt eq "-T") {
				$SW_TITRE=0;
			}
			elsif ($opt eq "-N") {
				$SW_NORM=0;
			}
			elsif ($state == 0)
			{ 
				print STDERR "$opt : option non reconnue"; 
				show_help  
			} 
		}
		when (2) { # Verbosité (sur STDERR)
			$state=0; 
			$DEBUG_LEVEL=$opt;
			$SW_DEBUG=1;
		}
		when (4) { # Affichage d'un seul sosa
			$state=0; 
			$SW_LIMIT=1;
			$SOSA_LIMIT=$opt;
		}
		when (6) { # Affichage sous forme d'arbre, de profondeur $TREE_LIMIT
			$state=0;
			$SW_TREE=1;
			$TREE_LIMIT=$opt;
		}
		when (8) { # Input file
			$state=0;
			$SW_IN=1;
			$INFILE_NAME=$opt;
			open $INFILE, "<", $opt || die ("Fichier illisible $opt -- $!");
			message WARN, "Ouverture du fichier < $opt -- $!";
			*STDIN = *$INFILE;
		}
		when (9) { # Output uile
			$state=0;
			$SW_OUT=1;
			message WARN, "Ouverture du fichier > $opt";
			open $OUTFILE, ">", $opt || die ("Fichier illisible $opt -- $!");
			#message WARN, "Ouverture du fichier > $opt -- $!";
			select $OUTFILE;
		}
		when (7) { # CURL !
			show_help unless $SW_IN;
			message INFO, "Curl : -o $INFILE_NAME $opt $SW_IN";
			$DISTANT_URL=$opt;
			close $INFILE;
			`curl -o $INFILE_NAME "$DISTANT_URL"`;
			if (1) {
				message INFO, "Le fichier est généré, et pourra être réutilisé";
				message INFO, "avec '$ARGV[0] $INFILE_NAME'";
				open $INFILE, "<", $INFILE_NAME || die ("Fichier illisible $INFILE_NAME -- $!");
				message WARN, "Ouverture du fichier < $INFILE_NAME -- $!";
				*STDIN = *$INFILE;
			} else {
				warn "Erreur de CURL";
			}
		}
	}
}

$state=0;

message DEBUG, "Options : $SW_LIMIT : $SOSA_LIMIT - $SW_DEBUG : $DEBUG_LEVEL";

# Automate à états, sur $state.
# Pour chaque paramètre en argument, un tour d'automate.
foreach my $li (<STDIN>) {
	chomp $li;
	message XTRACE, "$state:$li!";
	# s/&nbsp;/ /g;

	given ($state) { # On démarre le traitement à ST_INTERLIGNE, mais on s'assure d'avoir le bon format sur les deux états précédents
		when (0) {
			if ($li =~ /^<table summary="ancestors" class="short_display_table">/) {
				$root_sosa=$1;
				$state=10;
				message INFO,"-- C'est une v7 - It is a v7 output. I cannot parse it. #######";
			}
			message TRACE,"-- $state";
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
		when (10) {
			if ($li =~ /^<\/colgroup>/) { $state=2; }
			message TRACE,"-- $state";
			message CRIT,"-- C'est une v7 - It is a v7 output. I cannot parse it. #######";
		}
		when (2) {
			if ($li =~ /^<\/tr>/) { $state=ST_INTERLIGNE; }
		}
		###############################################
		when (ST_INTERLIGNE) { # Interligne
			message INFO,"====================";
			if ($li =~ /^<tr id="[^"]+">/) { # Mariage simple
				$state=201; 
				%items_a=();
				%items_b=();
			}
			if ($li =~ /^<tr>/) { # Mariage simple
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
		when (201) { # SOSA # Première ligne d'un mariage multiple
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
			$implexe="";
			$titre="";
			$state=ST_INTERLIGNE if ($li =~ /^<\/tr>/);
			next if ($SW_LIMIT and $SOSA_LIMIT!=$sosa);
			if ($li =~ /^<td[^>]*>(.+)<\/td>/) {
				$datas=$1;
				if ($datas =~ (/<a href=".+\?(.+)">(.*)<\/a>/)) {
					($items_a{p},$items_a{n},$tmp)=parse_patronyme($1,$2);
				}
				if ($datas =~ (/<\/a>.+<em>(.+)<\/em>/)) { 
					message INFO,"Titre ! $1";
					$titre=$1 if $SW_TITRE; # Don't catch it if disable by options
				}
				if ($datas =~ (/ → (\d+)$/)) { 
					message INFO,"Implexe ! $1";
					$implexe=$1;
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
		when (205) { # Second membre du couple # Lignes suivantes d'un mariage multiple
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

		when (ST_AFF) {  # Traitement des données de la personne référencée par le SOSA $sosa
			if ($SW_TREE) { # Arbre ##########
				# prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;
				# SOSA ; Prenom ; Nom ; Dat ; Naiss ; Lui ; Lieu ; 
				$line="";
				my $level=$sosa / 2;
				add_line " " x get_gen($sosa) x 2 . " - $sosa - ";
				add_line "$items_a{n} $items_a{p}";
				add_line " \"$titre\" " if $titre;
				add_line "($dn à $ln / $dd à $ld) - $prof - $nbe enfants.";
				add_line " --> $implexe " if $implexe;

				$line =~s/;\s+;/;;/g;
				push @lines,$line;
				push @{$lines{$sosa}},$#lines;
				# On gère un buffer de lignes formatése
				# Et un hash de SOSA pointant vers le buffer.
				message DEBUG,$line;
			} else { # CSV ##############
				# prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;jour_décès_lui;mois_décès_lui;année_décès_lui;lieu_décès_lui;métier_lui;prénom_elle;nom_elle;jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant
				# prénom_lui;nom_lui;jour_naiss_lui;mois_naiss_lui;année_naiss_lui;lieu_naiss_lui;
				# SOSA ; Prenom ; Nom ; Dat ; Naiss ; Lui ; Lieu ; 
				$line="";

				# Génération du CSV. Le SOSA est le premier cham, le nb_enfants le dernier.
				# Tronçonné en morceaux pour la lisibilité du code.
				add_line $sosa;
				add_line "==$implexe" if ($implexe);
				add_line ";";
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

				message DEBUG,"# prénom_elle;nom_elle;";
				foreach $k ('p', 'n') {
					add_line "$items_b{$k};",DEBUG,$k.":".$items_b{$k};
				}

				message DEBUG, "# jour_marr;mois_marr;année_marr;lieu_marr;nb_enfant";
				message DEBUG, "$dm;$lm;$nbe";
				add_line parse_date($dm).";";
				add_line "$lm;";
				add_line "$nbe";

				$line =~s/;\s+;/;;/g;
				push @lines,$line;
				message DEBUG,$line;
			}

			# Fin de tableau ? Si oui, on a raté une ligne, et on retourne tout de suite au SOSA.
			# au risque de rater un individu
			if ($li =~ /^<tr>/) { 
				$state=201; 
				message WARN, "$sosa - Fin de ligne manquée, rattrapage."} 
			else { 
				$state=ST_INTERLIGNE 
			}
		}
	};

}

###############################################################################
# Post traitement

if ($SW_TREE) { # Affichage des lignes de l'arbre
	message WARN,"==== ARBRE - $last_sosa";

	print "Affichage de l'arbre ascendant par SOSA (generation max : $TREE_LIMIT)\n";
	print "------------------------------------------------------------------\n";
	print_sosa(1,$last_sosa);
} else { # Affichage du CSV, en vrac, dans l'ordre d'entrée.
	message WARN,"==== LINE";
	# Entête
	unshift @lines,FORMAT;
	unshift @lines,"# <GeneaParse v".VERSION.">";
	foreach (@lines) {
		print "$_\n";
		#message INFO,"$_";
	}
}

close $INFILE if $SW_IN;
close $OUTFILE if $SW_OUT;

1;
