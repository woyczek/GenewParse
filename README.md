# NAME

genea.pl - GenewParse

# VERSION

version 1.5

# SYNOPSYS

Parseur de tableau généalogique geneweb vers un fichier CSV, prêt pour le réimport.

## License : GPL

## Historique

## Historique

- 0.8 : 28/05/18 : Early debug
- 0.9 : 28/05/18 : première ébauche de CSV
- 1.0 : 29/05/18 : Formalisation, constantes, correction des dates, première version versionnée
- 1.1 : 29/05/18 : Multiple verboses, fin de cas de précision de date
- 1.2 : 29/05/18 : Retour format CSV initial, traitement des dates révolutionnaire ajout de précision sur année, uppercase ; recupération des diacritiques.
- 1.3 : 30/05/18 : Suppression du module Switch - switch limit - help page - debug dates & accents Fix bug de logique sur les majuscules des prénoms - recombinaison compatible forme combinée unicode
- 1.4 : 30/05/18 : Ajout affichage en forme d'arbre
- 1.5 : 31/05/18 : Ajout fichiers i/o + curl

## Dependencies :

### CPAN 

- ```Text::Unidecode qw(unidecode);```
- ```HTML::Entities qw(decode_entities);```
- ```Unicode::Normalize;```

# DESCRIPTION

Il parse le résultat d'un curl sur l'URL de votre geneweb, via STDIN

Il effectue le nettoyage des dates, normalisation Unicode, mise en forme des patronymes sous forme cononique.
La transformation des dates républicaines, et du nettoyage cosmétique.

# USAGE

```
genea.pl [-v <LEVEL>] [-l <SOSA>] [-t <LEVEL>] [-i <INPUT> [-u <URL>] ] [-o <OUTPUT>] [-h|-?]
        -v <LEVEL>  : avec <LEVEL> compris entre 0 (silencieux) et 6 (Xtra Trace)
        -l <SOSA>   : ne traite que le sosa <SOSA>
        -t <LEVEL>  : affiche sous forme d'arbre, niveau <LEVEL> maximal
        -i <INPUT>  : fichier en entrée. Si omis, utilisera STDIN
        -u <URL>    : URL à télécharger en pré-traitement. Nécessite -i, le fichier sera écrasé
        -o <OUTPUT> : fichier en sortie. Si omis, utilisera STDOUT

Be careful. The order of the switches is important, and CURL on <URL> is done immediately, before looking up at the other switches.

```


Niveaux de verbosité :
- XTRACE  => 6,
- TRACE   => 5,
- DEBUG   => 4,
- INFO    => 3,
- WARN    => 2,
- ERR     => 1,
- CRIT    => 0

