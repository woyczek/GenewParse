# NAME

GenewParse – genea.pl

# VERSION

Version 1.7

# SYNOPSIS

Parser of tables of ancestors of GeneWeb to a CSV file.

## Licence : GPL

## Changelog

- 0.8 – 28/05/18: Early debug.
- 0.9 – 28/05/18: First CSV output.
- 1.0 – 29/05/18: Formalisation, constants, dates bugfix, first versioned release.
- 1.1 – 29/05/18: Multiple verbose, date precision handling improvement.
- 1.2 – 29/05/18: Return back to initial CSV format, French Revolutionary Calendar dates handling, add precision on year, uppercase ; diacritics handling.
- 1.3 – 30/05/18: Change Switch module to given - switch limit - help page - debug dates & accents, fix logic for capitalisation - Unicode normalisation on split/combined mode.
- 1.4 – 30/05/18: Tree display.
- 1.5 – 31/05/18: Input/output files + cURL handling.
- 1.6 – 07/06/18: Add case normalisation switch and fix bugs on surnames with dashes, add implexes.
- 1.7 – 07/06/18: Add title and ignore title switch.
- 1.8 : 07/07/18 : Add lots of forbidden chars in diacritic list to be removed, fix multiple weddings, detect thousand separators for french language
- 1.9 : 07/07/18 : Add mark all individual as dead option, add entities switch

## Dependencies :
### CPAN 
- ```Text::Unidecode qw(unidecode);```
- ```HTML::Entities qw(decode_entities);```
- ```Unicode::Normalize;```

Install them with:
```
cpan -i Text::Unidecode qw(unidecode) HTML::Entities qw(decode_entities) Unicode::Normalize
```

# DESCRIPTION
The goal of this parser is to fetch a cURL result on URL of any GeneWeb version prior to 7.0, and transform it in CSV with normalisation ability.

All surnames are set-up with the normalisation options you gave, the French Republican dates are transformed, and some housekeeping is done.

# USAGE

```
genea.pl [-v <LEVEL>] [-s <SOSA>] [-t <LEVEL>] [-T] [-N] [-i <INPUT> [-u <URL>] ] [-o <OUTPUT>] [-d] [-e] [-h|-?]
        -v <LEVEL>  : With <LEVEL> value between 0 (quiet) and 6 (xtra trace).
        -s <SOSA>   : Only process given Sosa number <SOSA>.
        -N          : Disable case normalisation.
        -T          : Disable title catching.
        -t <LEVEL>  : Tree format display, by surname branches, with <LEVEL> as max depth.
        -i <INPUT>  : Input file. If this flag is omitted, the parser will use STDIN.
        -u <URL>    : URL to fetch and save to INPUT file, before processing this file. -i is mandatory, the file will be replaced.
        -o <OUTPUT> : Output file. If omitted, will use STDOUT.
        -d          : Mark all individual as dead
        -e          : Convert fields using urlencode and entities

Be careful. The order of the switches is important, and cURL on <URL> is done immediately, before looking up at the other switches.
```

Verbose levels:
- XTRACE  => 6,
- TRACE   => 5,
- DEBUG   => 4,
- INFO    => 3,
- WARN    => 2,
- ERR     => 1,
- CRIT    => 0
