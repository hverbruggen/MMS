#!/usr/bin/perl
#
#	MMS.pl     version 1.07
#
#   heroen.verbruggen@gmail.com
#
# 
#   Version history:
#   1.07  user can set java memory with -jm flag
#         program dies with error message if user tries to toggle layers in arguments file
#   1.06  bug related to Windows line endings fixed
#   1.05  error reporting for wrongly formatted CSV (column headers, multiple species)
#   1.04  custom training/test data
#   1.03  AIC/BIC functionality
#   1.02  SWD functionality
#   1.01  initial version
#

use warnings;
use strict;
use Data::Dumper;

####  global variables  ################################################################################################################################################
	my (
		$envdata,
		$samplesfile,
		$customtestfile,
		$outfile,
		$criterion,
		$method,
		$maxentargsfile,
		$maxentlink,
		$trainingtest,
		$swdmode,
		$customtestmode,
		
		$predictors,
		$npredictors,
		$maxentargs,
	);


####  define defaults  ################################################################################################################################################

	my $javamem = '1024m';
	my $defaults = {
		criterion => 'AUC',
		method => 'bss',
		maxentargs => '-a -r nowarnings noprefixes visible=false',
		trainingtest => '1',
		swdmode => '0',
		customtestmode => '0',
	};
	my $allowed_values = {
		criterion => {
			'AUC'  => 'area under ROC curve (for test set)',
			'AIC'  => 'Akaike Information Criterion',
			'AICc' => 'corrected Akaike Information Criterion',
			'BIC'  => 'Bayesian Information Criterion'
		},
		method => {
			'bss' => 'best subset selection',
			'fws' => 'forward stepwise selection',
			'bws' => 'backward stepwise selection',
		},
	};


####  parse command line  ################################################################################################################################################

	unless (	($ARGV[0]) and (substr($ARGV[0],0,1) eq "-") and
				($ARGV[1]) and
				($ARGV[2]) and (substr($ARGV[2],0,1) eq "-") and
				($ARGV[3]) and
				($ARGV[4]) and (substr($ARGV[4],0,1) eq "-") and
				($ARGV[5]) and
				($ARGV[6]) and (substr($ARGV[6],0,1) eq "-") and
				($ARGV[7]) )
		{usage()}
	
	for (my $i=0; $i<scalar(@ARGV); $i+=2) {
		if    ($ARGV[$i] eq "-e")  {$envdata        = $ARGV[$i+1]}
		elsif ($ARGV[$i] eq "-o")  {$outfile        = $ARGV[$i+1]}
		elsif ($ARGV[$i] eq "-s")  {$samplesfile    = $ARGV[$i+1]}
		elsif ($ARGV[$i] eq "-t")  {$customtestfile = $ARGV[$i+1]}
		elsif ($ARGV[$i] eq "-m")  {$maxentlink     = $ARGV[$i+1]}
		elsif ($ARGV[$i] eq "-ma") {$maxentargsfile = $ARGV[$i+1]}
		elsif ($ARGV[$i] eq "-me") {$method         = $ARGV[$i+1]}
		elsif ($ARGV[$i] eq "-rc") {$criterion      = $ARGV[$i+1]}
		elsif ($ARGV[$i] eq "-tt") {$trainingtest   = $ARGV[$i+1]}
		elsif ($ARGV[$i] eq "-jm") {$javamem        = $ARGV[$i+1].'m'}
		else {usage()}
	}
	
	sub usage {
		print "\nwrong usage  --  use the following parameters\n"; 
		print "\nmandatory parameters\n";
		print "   -e   environmental data\n";
		print "         name of directory containing rasters (raster mode)\n";
		print "         file with background csv data (SWD mode)\n";
		print "   -s   samples file\n";
		print "         sample coordinates in csv file (raster mode)\n";
		print "         sample data in csv format (SWD mode)\n";
		print "   -m   link to maxent jar file\n";
		print "   -o   output file\n";
		print "\noptional parameters\n";
		print "   -t   test samples file\n";
		print "         sample coordinates in csv file (raster mode)\n";
		print "         sample data in csv format (SWD mode)\n";
		print "         (using this option activates custom training/test mode)\n";
		print "   -me  method for variable selection (default: ",$defaults->{method},")\n";
		foreach my $key (sort keys %{$allowed_values->{method}}) {
			print "         $key : ",$allowed_values->{method}->{$key},"\n";
		}
		print "   -rc  evaluation criterion (default: ",$defaults->{criterion},")\n";
		foreach my $key (sort keys %{$allowed_values->{criterion}}) {
			print "         $key : ",$allowed_values->{criterion}->{$key},"\n";
		}
		print "   -tt  number of replicate training and test data sets (default: ",$defaults->{trainingtest},")\n";
		print "         (disregarded when in custom training/test mode)\n";
		print "   -ma  file with arguments to be passed to maxent (one per line)\n";
		print "   -jm  java memory (in megabytes)\n";
		print "\n";
		exit;
	}
	

####  evaluate arguments  ################################################################################################################################################

	# check for presence of input files
	unless ($envdata and $outfile and $samplesfile and $maxentlink) {usage()}
	unless (-e $envdata) {die "\n#### FATAL ERROR ####\ndirectory does not exist: $envdata\n"}
	unless (-e $samplesfile) {die "\n#### FATAL ERROR ####\nfile does not exist: $samplesfile\n"}
	unless (-e $maxentlink) {die "\n#### FATAL ERROR ####\nfile does not exist: $maxentlink\n"}
	if ($maxentargsfile and !(-e $maxentargsfile)) {die "\n#### FATAL ERROR ####\nfile does not exist: $maxentargsfile\n"}
	# determine whether to run in raster or SWD mode
	unless (-d $envdata) {$swdmode = 1}
	# set or evaluate method
	if ($method) {
		unless ($allowed_values->{method}->{$method}) {
			print "method $method not known, use one of following:\n";
			foreach my $key (sort keys %{$allowed_values->{method}}) {print "  $key : ",$allowed_values->{method}->{$key},"\n"}
			die
		}
	} else {$method = $defaults->{method}}
	# set or evaluate criterion
	if ($criterion) {
		unless ($allowed_values->{criterion}->{$criterion}) {
			print "criterion $criterion not known, use one of following:\n";
			foreach my $key (sort keys %{$allowed_values->{criterion}}) {print "  $key : ",$allowed_values->{criterion}->{$key},"\n"}
			die
		}	
	} else {$criterion = $defaults->{criterion}}
	# set or evaluate training/test option
	unless ($trainingtest && ($trainingtest =~ /^\d+$/)) {$trainingtest = $defaults->{trainingtest}}
	# custom test samples mode?
	if ($customtestfile) {
		unless (-e $customtestfile) {die "\n#### FATAL ERROR ####\nfile does not exist: $samplesfile\n"}
		$customtestmode = 1;
		$trainingtest = 1;
	} else {$customtestmode = $defaults->{customtestmode}}
	# get list of variables (.asc files in rasterdir or columns in csv file) and verify if it's more than one
	if ($swdmode) {
		unless (open FH,$samplesfile) {die "\n#### FATAL ERROR ####\ncould not read from file $samplesfile - make sure it's not locked by another program\n"}
		my $l = <FH>;
		my @a = split /\s*,\s*/,$l;
		foreach my $colname (@a) {
			if (!($colname =~ /species/i) && !($colname =~ /long/i) && !($colname =~ /longitude/i) && !($colname =~ /lat/i) && !($colname =~ /latitude/i)) {
				push @$predictors,$colname
			}
		}
		close FH;
		$npredictors = scalar @$predictors;
		unless ($npredictors > 1) {die "\n#### FATAL ERROR ####\nless than two variable columns were found in the csv file $samplesfile\n"}
	} else {
		opendir FASD, $envdata; my @a = readdir(FASD);
		foreach my $f (@a) {$f =~ s/[\r\n]//g; if ($f =~ /\.asc/) {push @$predictors,$f}}
		closedir FASD;
		$npredictors = scalar @$predictors;
		unless ($npredictors > 1) {die "\n#### FATAL ERROR ####\nless than two raster files were found in the raster directory $envdata\n"}
	}
	# check for java in path
=head
	{  # I have commented this because it did not behave in a predictable way on all platforms
		my $tempfile = "temp".randdig(10);
		my $a = system("java > $tempfile");
		if (($a eq '256') && (-s $tempfile == 0)) {die "\n#### FATAL ERROR ####\njava must be installed, be in the path, and be reachable with 'java' command\n"}
		else {open FH,$tempfile; my $line = <FH>; unless ($line =~ /^Usage:/i) {die "\n#### FATAL ERROR ####\njava must be installed, be in the path, and be reachable with 'java' command\n"}}
		unlink($tempfile) || system("rm $tempfile");
	}
=cut
	# load maxent arguments
	if ($maxentargsfile) {
		unless (open FH,$maxentargsfile) {die "\n#### FATAL ERROR ####\ncannot read from file: $maxentargsfile\n"}
		my @b; my @a = <FH>; close FH;
		foreach my $line (@a) {
			$line =~ s/[\r\n\s]//g;
			unless ($line =~ /^\s*$/) {   # ignores blank lines
				if ($line =~ /^(.*)\=(.*)$/) {   # ignore lines that are not in key=value format
					my ($key,$value) = ($1,$2);
					if ($key =~ /^visible$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^askoverwrite$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^warnings$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^tooltips$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^autorun$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^plots$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^responsecurves$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^jackknife$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^replicates$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^replicatetype$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^randomseed$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^randomtestpoints$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					elsif ($key =~ /^testsamplesfile$/i) {print "WARNING: The line in the maxent arguments file where the $key flag is set has been ignored -- $key has a default value in MMS that must not be overruled\n"}
					else {push @b,$line} # all other arguments should be fine and are added to the arguments array
				} else {
					print "WARNING: The following line in the maxent arguments file is ill-formatted and ignored:\n$line\n";
				}
				if (($line =~ /togglelayerselected/i) or ($line =~ /-N/)) {
					die "\n#### FATAL ERROR ####\nYou must not toggle predictors in the file with maxent arguments. If there are predictors you want to exclude from the MMS run, they need to be manually removed either by deleting the ascii files if you are working with rasters or by removing the appropriate columns if you are working with an SWD file.\n"
				}
				if (($line =~ /togglespeciesselected/i) or ($line =~ /-E/)) {
					die "\n#### FATAL ERROR ####\nYou must not toggle species in the file with maxent arguments. Note that MMS works with a single species at a time. If you have multiple species, you have to separate them out into different files and run MMS on each of them separately.\n"
				}
			}
		}
		$maxentargs = join(" ",@b)." ".$defaults->{maxentargs};
	} else {$maxentargs = $defaults->{maxentargs}}


####  print overview of settings  ################################################################################################################################################

	print "\nsettings used for variable selection\n------------------------------------\n";
	print "rasters / SWD      $envdata\n";
	print "samples file       $samplesfile\n";
	if ($customtestmode) {print "custom test file   $customtestfile\n"}
	print "output file        $outfile\n";
	print "# predictors       $npredictors\n";
	print "method             $method (",$allowed_values->{method}->{$method},")\n";
	print "criterion          $criterion (",$allowed_values->{criterion}->{$criterion},")\n";
	print "java memory        $javamem\n";
	print "maxent arguments   $maxentargs\n";
	if ($swdmode) {print "running mode       SWD\n"}


####  generate test and training sets  ################################################################################################################################################
unless ($customtestmode) {
	print "\n\ntraining and test sets\n----------------------\n";
	unless(open FH,$samplesfile) {die "\n#### FATAL ERROR ####\ncannot read from file: $samplesfile\n"}
	my @a = <FH>; close FH;
	if (scalar @a == 1) {@a = split /\r/,$a[0];} # fixes mac line endings
	my $header = shift @a; $header =~ s/[\r\n]//g;
	my @b; foreach my $line (@a) {$line =~ s/[\r\n]//; unless ($line =~ /^\s*$/) {push @b,$line}}
	my $totalsamples = scalar @b; if ($totalsamples % 2 == 1) {++$totalsamples}
	unless (has_single_species($header,\@b)){die "\n#### FATAL ERROR ####\nCSV file has multiple species -- if you want to survey models for multiple species, you must prepare separate CSV files for each species and run MMS separately on each of those\n\n"}
	print "total      ",scalar(@b),"\n";
	print "training   ",($totalsamples/2),"\n";
	print "test       ",($totalsamples/2),"\n";
	print "saving files\n";
	for (my $rep = 0; $rep < $trainingtest; ++$rep) {
		my $trainfile = $samplesfile.".training".$rep;
		my $testfile = $samplesfile.".test".$rep;
		my (@training,@test); @test = @b;
		for (my $i = 0; $i < $totalsamples/2; ++$i) {
			my $rand = int rand scalar @test;
			push @training,splice(@test,$rand,1);
		}
		unless (open FH,">".$trainfile) {die "\n#### FATAL ERROR ####\ncannot write to file: $trainfile\n"}
		print FH $header,"\n";
		foreach my $el (@training) {print FH $el,"\n";}
		close FH;
		unless (open FH,">".$testfile) {die "\n#### FATAL ERROR ####\ncannot write to file: $testfile\n"}
		print FH $header,"\n";
		foreach my $el (@test) {print FH $el,"\n";}
		close FH;
		print "  set $rep: $trainfile, $testfile\n";
	}
}

####  variable selection  ################################################################################################################################################

	unless (open OUT,">$outfile") {die "\n#### FATAL ERROR ####\ncannot write to file: $outfile\n"}
	my ($varcombinations,$scores,$bestsubsets,$bestscore);
	
	# best subset selection
	if ($method eq 'bss') {
		print "\n\nbest subset selection\n---------------------\n";
		print "initializing\n";
		my $combination0; for (my $i = 0; $i < $npredictors; ++$i) {push @$combination0,0} push @$varcombinations,$combination0;
		my $combination1; @$combination1 = @$combination0; $combination1->[0] = 1; push @$varcombinations,$combination1;
		for (my $i = 1; $i < $npredictors; ++$i) {
			my $currentmax = scalar(@$varcombinations);
			for (my $in = 0; $in < $currentmax; ++$in) {
				my $varcomb = $varcombinations->[$in];
				my $newvarcomb;
				@$newvarcomb = @$varcomb;
				$newvarcomb->[$i] = 1;
				push @$varcombinations,$newvarcomb;
			}
		}
		print "  $npredictors rasters => ",scalar(@$varcombinations)," variable combinations\n";
		print "running maxent (please be patient)\n";
		for (my $i = 0; $i < scalar(@$varcombinations); ++$i) {
			my $varcomb = $varcombinations->[$i];
			my $string = join('',@$varcomb);
			if ($string =~ /1/) {
				run_maxent($varcomb);
				my $score = extract_score($varcomb);
				push @$scores, $score;
				print "  set ",($i+1)," ($string): $criterion\=$score\n";
				my $varlist = get_variable_list($varcomb);
				print OUT $string,"\t",$score,"\t",join(' ',@$varlist),"\n";;
				clean_up_maxent($varcomb);
			} else {
				print "  set ",($i+1)," ($string): $criterion\=NA\n";
			}
		}
		shift @$varcombinations;  # removing the first combination because there are no variables here
		($bestsubsets,$bestscore) = select_best_varcombinations($varcombinations,$scores);
		
	# forward stepwise selection
	} elsif ($method eq 'fws') {
		print "\n\nforward stepwise selection\n--------------------------\n";
		print "running maxent (please be patient)\n";
		my $setcounter; $setcounter = 0;
		my $previous_best; for (my $i = 0; $i < $npredictors; ++$i) {push @{$previous_best->[0]},0}
		for (my $currentnrasters = 1; $currentnrasters <= $npredictors; ++$currentnrasters) {
			my ($currentvarcombs,$currentscores);
			foreach my $varcomb (@$previous_best) {
				for (my $pos = 0; $pos < scalar @$varcomb; ++$pos) {
					my $a; @$a = @$varcomb;
					if ($a->[$pos] == 0) {
						$a->[$pos] = 1;
						push @$currentvarcombs,$a;
					}
				}
			}
			$currentvarcombs = remove_duplicate_varcombs($currentvarcombs);
			for (my $i = 0; $i < scalar(@$currentvarcombs); ++$i) {
				my $varcomb = $currentvarcombs->[$i];
				my $string = join('',@$varcomb);
				run_maxent($varcomb);
				my $score = extract_score($varcomb);
				push @$currentscores, $score;
				++$setcounter;
				print "  set $setcounter ($string): $criterion\=$score\n";
				my $varlist = get_variable_list($varcomb);
				print OUT $string,"\t",$score,"\t",join(' ',@$varlist),"\n";;
				clean_up_maxent($varcomb);
			}
			push @$varcombinations,@$currentvarcombs;
			push @$scores,@$currentscores;
			my ($currentbestsubsets,$currentbestscore) = select_best_varcombinations($currentvarcombs,$currentscores);
			$previous_best = $currentbestsubsets;
		}
		($bestsubsets,$bestscore) = select_best_varcombinations($varcombinations,$scores);
		
	# backward stepwise selection	
	} elsif ($method eq 'bws') {
		print "\n\nbackward stepwise selection\n---------------------------\n";
		print "running maxent (please be patient)\n";
		my $setcounter; $setcounter = 0;
		my $previous_best; for (my $i = 0; $i < $npredictors; ++$i) {push @{$previous_best->[0]},1}
		for (my $currentnrasters = $npredictors; $currentnrasters >= 1; --$currentnrasters) {
			my ($currentvarcombs,$currentscores);
			if ($setcounter == 0) {
				push @$currentvarcombs,$previous_best->[0];
			} else {
				foreach my $varcomb (@$previous_best) {
					for (my $pos = 0; $pos < scalar @$varcomb; ++$pos) {
						my $a; @$a = @$varcomb;
						if ($a->[$pos] == 1) {
							$a->[$pos] = 0;
							push @$currentvarcombs,$a;
						}
					}
				}
			}
			$currentvarcombs = remove_duplicate_varcombs($currentvarcombs);
			for (my $i = 0; $i < scalar(@$currentvarcombs); ++$i) {
				my $varcomb = $currentvarcombs->[$i];
				my $string = join('',@$varcomb);
				if ($string =~ /1/) {
					run_maxent($varcomb);
					my $score = extract_score($varcomb);
					push @$currentscores, $score;
					++$setcounter;
					print "  set $setcounter ($string): $criterion\=$score\n";
					my $varlist = get_variable_list($varcomb);
					print OUT $string,"\t",$score,"\t",join(' ',@$varlist),"\n";;
					clean_up_maxent($varcomb);
				} else {
					print "  set ",($setcounter+1)," ($string): $criterion\=NA\n";
				}
			}
			push @$varcombinations,@$currentvarcombs;
			push @$scores,@$currentscores;
			my ($currentbestsubsets,$currentbestscore) = select_best_varcombinations($currentvarcombs,$currentscores);
			$previous_best = $currentbestsubsets;
		}
		($bestsubsets,$bestscore) = select_best_varcombinations($varcombinations,$scores);
	}
	
	close OUT;


####  reporting results  ################################################################################################################################################
{
	print "\n\noptimal variable combinations\n-----------------------------\n";
	print "there are/is ",scalar(@$bestsubsets)," variable sets/set with optimal $criterion\n";
	my $counter; $counter = 0;
	foreach my $bestsubset (@$bestsubsets) {
		++$counter;
		print "variable set $counter\n";
		print "  subset       ",join('',@$bestsubset),"\n";
		print "  $criterion value",spaces(7-length($criterion)),"$bestscore\n";
		print "  # variables  "; my $str; $str = join('',@$bestsubset); $str =~ s/0//g; print length($str),"\n";
		print "  variables   "; for (my $i = 0; $i < scalar @$bestsubset; ++$i) {if ($bestsubset->[$i]) {print " ",$predictors->[$i]}} print "\n";
	}
	print "\nexhaustive list of evaluated models and $criterion values in $outfile";
	print "\n\n";
}

####  subroutines  ################################################################################################################################################

	sub run_maxent {
		my $varcomb = shift;
		for (my $rep = 0; $rep < $trainingtest; ++$rep) {
			my $dir = 'out'.join('',@$varcomb).'rep'.$rep;
			my $trainfile = $samplesfile.".training".$rep;
			my $testfile = $samplesfile.".test".$rep;
			if ($customtestmode) {
				$trainfile = $samplesfile;
				$testfile = $customtestfile;
			}
			mkdir $dir;
			my $cmd = 'java -Xmx'.$javamem.' -jar '.$maxentlink.' -e '.$envdata.' -s '.$trainfile.' testsamplesfile='.$testfile;
			$cmd .= ' -o '.$dir.' '.$maxentargs;
			my $excmd;
			for (my $i = 0; $i < scalar(@$varcomb); ++$i) {
				my $exclude = 1 - $varcomb->[$i];
				my $layername = $predictors->[$i];
				if ($swdmode) {
					if ($exclude) {$excmd .= ' -N '.$layername}
				} else {
					$layername =~ /(.*)\.asc/i;
					my $root = $1;
					if ($exclude) {$excmd .= ' -N '.$root}
				}
			}
			if ($excmd) {$cmd .= $excmd}
			system $cmd;
		}
	}
	
	sub clean_up_maxent {
		my $varcomb = shift;
		for (my $rep = 0; $rep < $trainingtest; ++$rep) {
			my $dir = 'out'.join('',@$varcomb).'rep'.$rep;
			if (-e $dir) {
				chdir $dir;
				if (-e 'plots') {
					chdir 'plots';
					unlink glob "*" || system("rm -r *");
					chdir '..';
					rmdir 'plots' || system("rm -r plots");
				}
				unlink glob "*" || system("rm -r *");
				chdir '..';
				rmdir $dir || system("rm -r $dir");
			}
		}
	}
	
	sub remove_duplicate_varcombs {
		my $varcombs = shift;
		my $hash;
		foreach my $varcomb (@$varcombs) {$hash->{join('',@$varcomb)} = 1}
		my $out;
		foreach my $key (sort keys %$hash) {
			my $array; @$array = split '',$key;
			push @$out,$array;
		}
		return $out;
	}
	
	sub select_best_varcombinations {
		my $combs = shift;
		my $scores = shift;
		my $minmax; $minmax = 'min';
		if ($criterion eq 'AUC') {$minmax = 'max'}
		my $bestscore; $bestscore = $scores->[0];
		my $bestindices; $bestindices = [0];
		for (my $i = 0; $i < scalar @$scores; ++$i) {
			my $score = $scores->[$i];
			if ($minmax eq 'min') {
				if ($score < $bestscore) {
					$bestindices = [$i]; $bestscore = $score;
				} elsif ($score == $bestscore) {
					push @$bestindices,$i
				}
			}
			if ($minmax eq 'max') {
				if ($score > $bestscore) {
					$bestindices = [$i]; $bestscore = $score;
				} elsif ($score == $bestscore) {
					push @$bestindices,$i
				}
			}
		}
		my $bestcombs; foreach my $index (@$bestindices) {push @$bestcombs,$combs->[$index]}
		return ($bestcombs,$bestscore);
	}
	
	sub extract_score {
		my $varcomb = shift;
		if ($criterion eq 'AUC') {return extract_AUC_score($varcomb);}
		else {return extract_IC_score($varcomb,$criterion);}
	}
	
	sub extract_AUC_score {
		my $varcomb = shift;
		my $AUC;
		for (my $rep = 0; $rep < $trainingtest; ++$rep) {
			my $dir = 'out'.join('',@$varcomb).'rep'.$rep;
			opendir D, $dir; my @a = readdir(D); closedir D;
			foreach my $f (@a) {
				$f =~ s/[\r\n]//g;
				if ($f =~ /\.html$/) {
					unless (open FH,$dir.'/'.$f) {print "cannot read from file $f\n"}
					while (my $line = <FH>) {
						if ($line =~ /Test AUC is ([\d\.]+)/) {
							push @$AUC,$1
						}
					}
					close FH;
				}
			}
		}
		if ($AUC) {
			my $avg; $avg = 0; foreach my $el (@$AUC) {$avg += $el}
			$avg /= scalar @$AUC;
			return $avg;
		} else {
			return -1;
		}
	}
	
	sub extract_IC_score {
		my $varcomb = shift;
		my $criterion = shift;
		my $IC;
		for (my $rep = 0; $rep < $trainingtest; ++$rep) {
			my $dir = 'out'.join('',@$varcomb).'rep'.$rep;
			push @$IC,calculate_AIC($dir,$criterion);
		}
		if ($IC) {
			my $avg; $avg = 0; foreach my $el (@$IC) {$avg += $el}
			$avg /= scalar @$IC;
			return $avg;
		} else {
			return 0;
		}
	}
	
	sub extract_nparams {  # this is a piece of code from ENMtools to extract number of model parameters from maxent lambda file
		my $lambdasfile = shift;
		my $nparams = 0;
		unless (open LAMBDAS, $lambdasfile) {die "\n#### FATAL ERROR ####\ncould not read from file $lambdasfile - make sure it's not locked by another program\n"}
		while(<LAMBDAS>){
			my @thisline = split(/,/, $_);
			my $weight = $thisline[1];
			$weight =~ s/\s+//;
			unless($weight eq "0.0"){
				$nparams++;
			}
		}
		$nparams = $nparams - 4;
		close LAMBDAS;
		return $nparams;
	}
	
	sub calculate_probs_SWD {  # new code to get probability values from maxent SWD output
		die "\n#### FATAL ERROR ####\nprobability calculation for SWD not implemented yet\n";
		# add code here
	}
	
	sub calculate_probs_raster {  # code modified from ENMtools to get probability values from maxent output raster
		my $datafile = shift;
		my $probsum; $probsum = 0;
		my $ocprobs;
		my %fileparams;         # this contains the ascii headers parsed from the maxent output ascii file
		# initialize variables needed for ENMtools code to run
		my $ref_points = WarrenCsvToArray($samplesfile);
		unless (open FH,$samplesfile) {die "\n#### FATAL ERROR ####\ncould not read from file $samplesfile - make sure it's not locked by another program\n"}
		my $headerline = <FH>; close FH;
		#use Data::Dumper; print Dumper $ref_points; exit;
		# what follows here is Dan's code for lnL calculation
		my @points = @{$ref_points};
		my $latcolumn; #tells the program which column contains lat (assumed to be 1 or 2, the other is assumed to be long)
		my @thisline = split(/,/, $headerline);
		if($thisline[1] =~ /^lat/i) {$latcolumn = 1;}
		elsif($thisline[2] =~ /^lat/i) {$latcolumn = 2;}
		unless ($latcolumn) {die "\n#### FATAL ERROR ####\ncould not find column with header 'latitude' and/or 'longitude'\n"}
		unless (open DATAFILE, $datafile) {die "\n#### FATAL ERROR ####\ncould not read from file $datafile - make sure it's not locked by another program\n"}
		while(<DATAFILE>){
			unless ($_=~ /^\s*[0123456789-]/){ # Distinguishes file parameters from data
				my @thisline = split(/\s+/, $_);
				$fileparams{lc($thisline[0])} = $thisline[1]; # Keys are being converted to all lower case!
			}
		}
		close DATAFILE;
		my $xll = $fileparams{xllcorner};
		my $yll = $fileparams{yllcorner};
		my $cellsize = $fileparams{cellsize};
		unless (open LAYER, $datafile) {die "\n#### FATAL ERROR ####\ncould not read from file $datafile - make sure it's not locked by another program\n"}
		my @env_data;
		while(<LAYER>) {
			if ($_=~ /^\s*[0123456789-]/){ # Distinguishes file parameters from data
				chomp($_);
				unshift(@env_data, $_);	# Remember, zero is the bottom left!
				my @thisline = split(/\s+/, $_);
				for(my $k = 0; $k < @thisline; $k++){
					if ($thisline[$k] != -9999) {$probsum += $thisline[$k];}
				}
			}
		}
		close LAYER;
		for (my $j = 0; $j< @points; $j++) {
			my $thisx;
			my $thisy;
			chomp($points[$j]);
			my @thisline = split(/,/, $points[$j]);
			if($latcolumn == 1){  
				$thisx = $thisline[1];
				$thisy = $thisline[0];
			}
			else{ #latcolumn is 2
				$thisx = $thisline[0];
				$thisy = $thisline[1];
			}
			my $row = int(($thisy - $yll)/$cellsize);
			my $col = int(($thisx - $xll)/$cellsize);
			@thisline = split(/\s+/, $env_data[$row]);
			my $layer_value = $thisline[$col];
			if($layer_value > 0){
				push @$ocprobs,$layer_value;
			}
			else {print "Found probability of $layer_value!\n";}
		}
		return ($probsum,$ocprobs);
	}
	
	sub get_maxent_output_filenames {
		my $dir = shift;
		my $out;
		opendir D, $dir; my @a = readdir(D); closedir D;
		foreach my $f (@a) {
			$f =~ s/[\r\n]//g;
			if ($f =~ /\.lambdas$/) {
				$out->{lambda} = $dir.'/'.$f;
			} elsif ($f =~ /\.asc$/) {
				$out->{asciiout} = $dir.'/'.$f;
			}
		}
		return $out;
	}
	
	sub calculate_AIC {
		my $dir = shift;
		my $criterion = shift;
		
		# define some key variables used here
		my $probsum;   # sum of all maxent probability values accross output raster
		my $ocprobs;   # array of probability values for occurrence records
		my $nparams;   # number of parameters in model
		
		# get some filenames from maxent output directory
		my $maxentfiles = get_maxent_output_filenames($dir);
		my $lambdasfile = $maxentfiles->{lambda};
		my $ascii_output_file = $maxentfiles->{asciiout};
		unless ($lambdasfile) {die "\n#### FATAL ERROR ####\ncannot find lambdas file in maxent output $dir\n"}
		
		# calculate number of parameters
		$nparams = extract_nparams($lambdasfile);
		
		# calculate probsum and ocprobs
		if ($swdmode) {
			($probsum,$ocprobs) = calculate_probs_SWD();
		} else {
			unless ($ascii_output_file) {die "\n#### FATAL ERROR ####\ncannot find output raster file in maxent output $dir\n"}
			($probsum,$ocprobs) = calculate_probs_raster($ascii_output_file);
		}
		
		# calculate likelihood
		my $loglikelihood = 1;
		foreach my $probval (@$ocprobs) {
			$loglikelihood += log($probval/$probsum);
		}
		
		# calculate AIC, AICc, BIC
		my ($AICscore,$AICcscore,$BICscore);
		my $npoints = scalar @$ocprobs;  # number of occurrence points for which output probability > 0
		if ($nparams >= $npoints - 1) {
			$AICcscore = "x"; $AICscore = "x"; $BICscore = "x";
		} else {
			$AICcscore = (2 * $nparams - 2 * $loglikelihood) + (2*($nparams)*($nparams+1)/($npoints - $nparams - 1));
			$AICscore = 2 * $nparams - 2 * $loglikelihood;	
			$BICscore = $nparams*log($npoints) - 2*$loglikelihood;
		}
		
		# return value of desired criterion
		if ($criterion eq 'AIC') {return $AICscore}
		elsif ($criterion eq 'AICc') {return $AICcscore}
		elsif ($criterion eq 'BIC') {return $BICscore}
	}
	
	sub get_variable_list {
		my $varcomb = shift;
		my $out = [];
		for (my $i=0; $i < scalar @$varcomb; ++$i) {
			if ($varcomb->[$i]) {push @$out,$predictors->[$i]}
		}
		return $out;
	}
	
	sub randdig {
		my $nr = shift;
		my $out;
		for (my $i = 0; $i < $nr; ++$i) {
			$out .= int rand 10
		}
		return $out
	}
	
	sub spaces {
		my $nr = shift;
		my $out; $out = '';
		for (my $i = 0; $i < $nr; ++$i) {$out .= ' '}
		return $out;
	}

	sub WarrenCsvToArray {  # Takes a csv file and returns an array of XY values
		my $infile = shift;
		unless (open INFILE,$infile) {die "\n#### FATAL ERROR ####\ncould not read from file $infile - make sure it's not locked by another program\n"}
		my @thisarray = <INFILE>;
		if (scalar @thisarray == 1) {@thisarray = split /\r/,$thisarray[0];}
		foreach my $line (@thisarray) {$line =~ s/[\n\r]//g;}
		close INFILE;
		my @backgroundpoints;
		for(my $i = 1; $i < @thisarray; $i++){ #Starting at 1 to skip header line
			chomp $thisarray[$i];
			my @thisline = split(/,/ , $thisarray[$i]);
			my $thispoint = $thisline[1];
			for(my $j = 2; $j < @thisline; $j++){
				$thispoint = $thispoint . "," . $thisline[$j];	
			}
			push(@backgroundpoints, $thispoint);
		}
		return \@backgroundpoints;
	}
	
	sub has_single_species {  # this checks whether the csv file has a single species
		my $header = shift;
		my $records = shift;
		my $spindex;
		$header =~ s/[\r\n]//g;
		my @h = split /\,/,$header;
		for (my $i = 0; $i < scalar @h; ++$i) {if ($h[$i] =~ /species/i) {$spindex=$i}}
		unless (defined $spindex) {die "\n#### FATAL ERROR ####\nthere must be a column with header 'species' in your CSV file\n"}
		my $allsp;
		foreach my $line (@$records) {
			$line =~ s/[\r\n]//g;
			my @l = split /\,/,$line;
			$allsp->{$l[$spindex]}=1
		}
		if (scalar keys %$allsp == 1) {return 1} else {return 0}
	}