#!/usr/bin/env perl

use strict;

my $DEF_FORMAT = "d";	# Default format d=desire2learn, b=blackboard, ...

my $IDPREFIX = "Q";	# Can be changed with #@Prefix

my $TF_POINTS = 2;	# You can change this if you want a diff default
my $MC_POINTS = 2;	# You can change this if you want a diff default
my $SA_POINTS = 5;

my $TF_DIFFICULTY = 1;	# You can change this if you want a diff default
my $MC_DIFFICULTY = 1;	# You can change this if you want a diff default
my $SA_DIFFICULTY = 1;	# You can change this if you want a diff default

my %LINE_TO_QUESTION;
my %KEYWORDS_TO_LINE;

my @SMALL_WORDS = ('a', 'an', 'any', 'all', 'are', 'and','as','at','always',
		   'be', 'but','by','between','both',
		   'can', 'cannot',
		   'does', 'do', 'different','describe',
		   'every','each', 
		   'for', 'false',
		   'good',
		   'has','have','how','hint',
		   'is','in','it','if','into',
		   'like',
		   'might',
		   'not',
		   'one', 'only', 'of', 'or', 'other',
		   'some','same',
		   'the', 'this', 'that', 'to', 'too', 'true', 'two',
			'term','terms','than','thing',
		   'use','used','uses',
		   'which', 'when', 'who','with', 'within','what',
		   'you');


my %SMALL_WORDS_MAP = map { $_ => 1 } @SMALL_WORDS;  # A hash is more convenient

#
# (FYI - Probably don't want to change the starting counts...)
#

my $TRUE_COUNT = 0;
my $FALSE_COUNT = 0;

my $TF_COUNT = 0;
my $MC_COUNT = 0;
my $SA_COUNT = 0;

#
#----------------------------------------------------------------------
#
sub csv_escape {
	my($str) = @_;

	$str =~ s/"/""/g;

	return $str;
	}

#
#----------------------------------------------------------------------
#
sub question_to_keywords {
	my($q) = @_;
	my(%words);
	my($word);

	$q = lc($q);			# Force it to lowercase
	$q =~ s/[[:punct:]]//g;		# Remove all punctuation chars too


	for $word (split(/\s+/,$q)) {
		if (!defined($SMALL_WORDS_MAP{$word})) {
			$words{$word} = 1;
			}
		}

	# Now return a sorted version of the list

	return join(" ", sort(keys(%words)));
	}

#
#----------------------------------------------------------------------
#
sub check_for_dup_question {
	my($lineno,$question) = @_;
	my($keystr, $otherline);

	# First store the exact question
	$LINE_TO_QUESTION{$lineno} = $question;  

	$keystr = question_to_keywords($question);

	#print STDERR "Debug: $question => $keystr\n";
	
	if (defined($KEYWORDS_TO_LINE{$keystr})) {
		$otherline = $KEYWORDS_TO_LINE{$keystr};

		#
		#  Identical match or just similar?
		#
		if ($LINE_TO_QUESTION{$otherline} eq $question) {
			print STDERR 
			      "Warning!!! $lineno,$otherline are IDENTICAL\n";
			}
		else {
			print STDERR 
			      "Warning!!! $lineno,$otherline are similar\n";
			}

		print STDERR "\t$otherline: " . 
			     $LINE_TO_QUESTION{$otherline} . "\n";

		print STDERR "\t$lineno: $question\n\n";
		}
	else {
		# No match.  Save the first occurance
		$KEYWORDS_TO_LINE{$keystr} = $lineno;
		}

	}

#
#----------------------------------------------------------------------
#

sub process_question {
	my($lineno,$question) = @_;

	$question =~ s/^\s+$//;	
	$question =~ s/^\d+\)\s+//;


	if (($question =~ /[\.\?]/) && ($question !~ /[\.\?]("|\))*$/)) {
		print STDERR "$lineno: Warning, did you forget the TAB " .
			     "after the question?\n";
		print STDERR "   $question\n";
		}

	&check_for_dup_question($lineno, $question);

	return $question;
	}

#
#----------------------------------------------------------------------
#

sub byalpha {
	my($a1) = "\L${$a}{answer}";
	my($b1) = "\L${$b}{answer}";
	my($aa1,$bb1);

	$aa1 = "1$a1";
	$bb1 = "1$b1";

	
	if ($a1 =~ /^both\s/) 	       	{ $aa1 = "2$a1"; }
	if ($b1 =~ /^both\s/) 	       	{ $bb1 = "2$b1"; }

	if ($a1 =~ /^neither\s/)        { $aa1 = "3$a1"; }
	if ($b1 =~ /^neither\s/)        { $bb1 = "3$b1"; }

	if ($a1 =~ /^all\s/) 		{ $aa1 = "4$a1"; }
	if ($b1 =~ /^all\s/) 		{ $bb1 = "4$b1"; }

	if ($a1 =~ /^none\s/) 		{ $aa1 = "5$a1"; }
	if ($b1 =~ /^none\s/) 		{ $bb1 = "5$b1"; }

	#print "Comparing $a1 vs $b1\n";

	return ($aa1 cmp $bb1);	
	}

#
#----------------------------------------------------------------------
#

sub reorder_mc_options {
	my($nosort, @result) = @_;
	my(@result2);
	my($i);

	if (! $nosort) {
		@result = sort(byalpha @result);
		}

	for($i=0;$i<=$#result;$i++) {
		$result2[$#result2+1] = $result[$i]{answer};
		$result2[$#result2+1] = $result[$i]{tag};
		}

	return @result2;
	}
#
#----------------------------------------------------------------------
#

sub handle_mc_options {
	my($lineno,$quest,$nosort,$code,@line) = @_;
	my(@result);
	my($cur,$next);
	my($i);
	my($numcorrect) = 0;
	my($numincorrect) = 0;
	my(%ans,$one);

	while ($#line > -1) {
		$cur = shift @line;

		# Peek at the next item
		$next = "";
		if ($#line > -1) { $next = "\L$line[0]"; }

		$cur  =~ s/^\s*//; 	$cur  =~ s/\s*$//;
		$next =~ s/^\s*//; 	$next =~ s/\s*$//;

		# Do I already have the Blackboard format?
		if ($next =~ /^(in)?correct$/) {
			# Just use it and then consume it 
			shift @line;
			}
		# Ok, not the Blackboard format - see if a * is given		
		#  (indicating the correct answer)
		elsif (($cur ne "*") && (($cur =~ /\*$/) || ($cur =~ /^\*/))) {

			$cur =~ s/^\*//;
			$cur =~ s/\*$//;
			$next = "correct";	

			}
		else {
			$next = "incorrect";	
			}

		# Save this answer
		$i = $#result + 1;


		$result[$i]{answer} = $cur;
		$result[$i]{tag} = $next;

		# Update the list of questions
		$one = $cur;
		$one =~ s/^\*//;

		if (defined($ans{$one})) {
			print STDERR "$lineno: Warning, " &&
			 	     "$cur given as two seperate " &&
				     "answers to $quest\n";
			}

		$ans{$one} = 1;

		if ($next eq "correct") { 
			$numcorrect++; 
			} else { 
			$numincorrect++; 
			}
		}

	# If only one answer is given and is true/false/t/f then
	# convert it into true/false
	if (($numcorrect + $numincorrect == 1) && 
	    ($result[0]{answer} =~ /^(t)|(true)|(f)|(false)$/i)) {

		$code = "TF";

		$TF_COUNT++;

		if ($result[0]{answer} =~ /^t/i) {
			@result = ( "true" );
			$TRUE_COUNT++;
			}
		elsif ($result[0]{answer} =~ /^f/i) {
			@result = ( "false" );
			$FALSE_COUNT++;
			}
		else {
			# This should not happen
			@result = ( "???" );
			}
		}
        elsif (($numincorrect + $numcorrect == 0)) {
		# No answers?  Then assume short answer

		$code = "SA";
		$SA_COUNT++;

		@result = ();
		}
	else {
		if ($numincorrect < 1) {
			print STDERR "$lineno: Warning, too few " .
				"incorrect answers " .
				"(cor=$numcorrect, incor=$numincorrect)\n";
			print STDERR "    $quest\n";
			}

		if ($numcorrect > 1) {
			print STDERR "$lineno: Warning, too many " .
				"correct answers " .
				"(cor=$numcorrect, incor=$numincorrect)\n";
			print STDERR "    $quest\n";
			}

		if ($numcorrect < 1) {
			print STDERR "$lineno: Warning, no " .
				"correct answer " .
				"(cor=$numcorrect, incor=$numincorrect)\n";
			print STDERR "    $quest\n";
			}

		$MC_COUNT++;

		@result = &reorder_mc_options($nosort, @result);
		}

	return ($code,@result);
	}
#
#----------------------------------------------------------------------
#
sub output_printable {
	my($code,$question,@line) = @_;
	my($ret);

	$ret = $code . "\t" . $question . "\r\n";

	while ($#line > -1) {
		$ret .= "\t\t";
		$ret .= shift @line;
		$ret .= "\t";
		$ret .= shift @line;
		$ret .= "\r\n";
		}

	return $ret;
	}


#
#----------------------------------------------------------------------
#
sub output_blackboard {
	my($code,$question,@line) = @_;
	my($ret);

	$ret = $code . "\t" . $question . "\t" .  join("\t",@line) . "\r\n";

	return $ret;
	}

#
#----------------------------------------------------------------------
#

sub output_desire2learn {
	my($code,$question,@line) = @_;
	my($ret);
	my($id,$ans,$type);

	if ($code eq "FIB") { $code = "MC"; }   # D2L does not have a 
						#  a seperate fill-in-the-blank 

	if ($code eq "TF") {
		$id = "$IDPREFIX-TF-" . $TF_COUNT;
		}
	elsif ($code eq "SA") {
		$id = "$IDPREFIX-SA-" . $SA_COUNT;
		$code = "WR";		# Change it to "written response" type
		}
	else {
		$id = "$IDPREFIX-MC-" . $MC_COUNT;
		}

	$ret  = "NewQuestion,$code,\r\nID,$id\r\n";

	$ret .= "QuestionText,\"" . &csv_escape($question) . "\"\r\n";

	if ($code eq "TF") {
		$ret .= "Points,"     . $TF_POINTS     . "\r\n";
		$ret .= "Difficulty," . $TF_DIFFICULTY . "\r\n";

		$ans = shift @line;

		$ret .= "TRUE,"  . (($ans eq "true")  ? 100 : 0) . "\r\n";
		$ret .= "FALSE," . (($ans eq "false") ? 100 : 0) . "\r\n";

		if (($ans ne "true") && ($ans ne "false")) {
			print STDERR 
			   "Warning: $question is neither true nor false\n";
			}
		}	
	elsif (($code eq "SA") || ($code eq "WR")) {
		$ret .= "Points,"     . $SA_POINTS     . "\r\n";
		$ret .= "Difficulty," . $SA_DIFFICULTY . "\r\n";
		}
	else {
		$ret .= "Points,"     . $MC_POINTS     . "\r\n";
		$ret .= "Difficulty," . $MC_DIFFICULTY . "\r\n";

		while ($#line > 0) {
			$ans = shift @line;
			$type = shift @line;
			
			$ret .= "Option," . ($type eq "correct" ? 100 : 0) . 
				",\"" . &csv_escape($ans) . "\"\r\n";
			}
		}


	$ret .= "\r\n"; 	# Blank line between questions

	return $ret;
	}


#
#----------------------------------------------------------------------
#

sub process_line {
	my($format,$lineno,@line) = @_;
	my($ret);
	my($code) = "MC";
	my($question);
	my($nosort) = 0;

	# Already have a code?  If so, then use it

	if ($line[0] =~ /^[A-Z_]+$/) {
		$code = shift @line;
		}

	$question = &process_question($lineno,shift @line);

	# If the question begins with "!" then don't sort the
	#  multiple-choice answers

	if (substr($question,0,1) eq "!") {
		$nosort = 1;
		$question = substr($question,1);
		}

	if (($code eq "MC") || ($code eq "FIB")) {
		($code,@line) = &handle_mc_options($lineno,$question,
						   $nosort,$code,@line);
		}

	if ($format eq "p") {
		$ret = &output_printable($code, $question, @line);
		}
	elsif ($format eq "d") {
		$ret = &output_desire2learn($code, $question, @line);
		}
	elsif ($format eq "t") {
		$ret = "";	# Test mode - don't display anything
		}
	else {
		# Blackboard mode
		$ret = &output_blackboard($code,$question, @line); 
		}
	return $ret;
	}
#
#----------------------------------------------------------------------
#

sub fix_worddoc {
	my($line) = @_;
	
	$line =~ s/\222/'/g;
	$line =~ s/\223/"/g;
	$line =~ s/\224/"/g;
	$line =~ s/\226/-/g;

	return $line;
	}
#
#----------------------------------------------------------------------
#

sub fix_plus {
	my($str) = @_;

	# Allow a - at the end of the line to indicate to add
	#  an "none of the above" which is incorrect

	$str =~ 
	 s/\t+\-$/\tnone of the above\tincorrect/;

	# Allow a -none at the end of the line to indicate to add
	#  an "none of the above" which is correct

	$str =~ 
	 s/\t+\-none$/\tnone of the above\tcorrect/i;

	# Allow a + at the end of the line to indicate to add
	#  an "all of the above" and "none of the above" both incorrect

	$str =~ 
	 s/\t+\+$/\tall of the above\tincorrect\tnone of the above\tincorrect/;

	# Allow a +all at the end to incidate to add an "all of the
	# above" which is correct, and an incorrect "none of the above"
	$str =~ 
	 s/\t+\+all$/\tall of the above\tcorrect\tnone of the above\tincorrect/i;
		
	# Allow a +none at the end to incidate to add an "all of the
	# above" which is incorrect, and an correct "none of the above"
	$str =~ 
	 s/\t+\+none$/\tall of the above\tincorrect\tnone of the above\tcorrect/i;
		
	return $str;
	}
#
#----------------------------------------------------------------------
#

sub fix_whitespaces {
	my($str) = @_;

	$str =~ s/\r//g;
	$str =~ s/^\s+//;
	$str =~ s/\s+$//;

	# Allow spaces mixed with tab as long as there
	# is at least one tab
	$str =~ s/[\s\t]*\t[\s\t]*/\t/g;

	return $str;
	}
#
#----------------------------------------------------------------------
#
sub print_q_types {
	print STDERR "\n";

	if ($TF_COUNT > 0) {
		printf STDERR "%-15s: %d\n", "True/False", $TF_COUNT;
		}
	if ($MC_COUNT > 0) {
		printf STDERR "%-15s: %d\n", "Multiple Choice", $MC_COUNT;
		}

	if ($SA_COUNT > 0) {
		printf STDERR "%-15s: %d\n", "Short Answer", $SA_COUNT;
		}
	}

#
#----------------------------------------------------------------------
#

sub print_categories {
	my(%cat) = @_;
	my($k);

	if (keys(%cat) > 0) {
		print STDERR "\n";

		foreach $k (sort(keys(%cat))) {

			if (defined($cat{$k}{goal})) {
				printf STDERR "Category: %-10s Num. " .
					"Questions: %3d   Num. Needed: %3d",
					$k, $cat{$k}{count}, $cat{$k}{goal};

				if ($cat{$k}{goal} == $cat{$k}{count}) {
					print STDERR " -- ACHIEVED";
					}
				elsif ($cat{$k}{goal} < $cat{$k}{count}) {
					print STDERR " -- OVER";
					}

				print STDERR "\n";
				}

			else {
				printf STDERR "Category: %-10s Num. " .
					"Questions: %3d\n", 
					$k, $cat{$k}{count};
				}
			}
		}
	}


#
#----------------------------------------------------------------------
#

sub read_file {
	my($filename,$format) = @_;
	my($currline,$nextline);
	my(@line);
	my($newline);
	my($lineno) = 0;
	my($questno) = 0;
	my(%categories);
	my($currcategory) = "<unnamed>";
	my($letter);
	my($tot,$t_per,$f_per);

	open(FILE,$filename);
	$currline = <FILE>;
	$nextline = <FILE>;

	while($currline ne "") {
		chomp($currline);

		$lineno++;

		# Old-style continuation line?
		#  If so, then convert it to the new style
		if (/^\s+(\*?)[a-z][\)\.]\s*/) {
			s/^\s+/\t$1/;
			}	

		# Is there a continuation line?
		while ($nextline =~ /^\s*\t/) {
			chomp($nextline);

			$currline = $currline . $nextline;

			$nextline = <FILE>;

			$lineno++;
			}

		# Remove any comments
		# (but first check for @category directive)
		if ($currline =~ /^\s*#/) {

			#
			# Handle #@Category: abc
			#
			if ($currline =~ /#.*\@\s*Category(:|\s)\s*(\S+)/i) {
				$currcategory = $2;

				# Does it have a goal too?
				if ($currline =~ 
				      /#.*\@category(:|\s)\s*(\S+)\s+(\d+)/i) {

					$categories{$2}{goal} = $3;

					}
				}
			#
			#	Handle #@Points: xxx
			#
			if ($currline =~ 
			     /#.*\@\s*(tf_|mc_|sa |)points?(:|\s)\s*(\S+)/i) {

				$letter = substr($1,0,1);

				if ($letter eq "t" || $letter eq "T") {
					$TF_POINTS = $3;
					}
				elsif ($letter eq "m" || $letter eq "M") {
					$MC_POINTS = $3;
					}
				elsif ($letter eq "s" || $letter eq "S") {
					$SA_POINTS = $3;
					}
				else {
					$TF_POINTS = $3;
					$MC_POINTS = $3;
					$SA_POINTS = $3;
					}
				}

			#
			#	Handle #@Difficulty: xxx
			#
			if ($currline =~ 
			     /#.*\@\s*(tf_|mc_|sa |)difficulty(:|\s)\s*(\S+)/i) {

				$letter = substr($1,0,1);

				if ($letter eq "t" || $letter eq "T") {
					$TF_DIFFICULTY = $3;
					}
				elsif ($letter eq "s" || $letter eq "S") {
					$SA_DIFFICULTY = $3;
					}
				elsif ($letter eq "m" || $letter eq "M") {
					$MC_DIFFICULTY = $3;
					}
				else {
					$TF_DIFFICULTY = $3;
					$MC_DIFFICULTY = $3;
					$SA_DIFFICULTY = $3;
					}
				}

			#
			#	Handle #Prefix: xxx
			#
			if ($currline =~ /#.*\@\s*prefix(:|\s)\s*(\S+)/i) {
				$IDPREFIX = $2;
				}


			# Now remove the comments
			$currline =~ s/^\s*#.*//;
			}

		$currline = &fix_whitespaces($currline);
		$currline = &fix_plus($currline);

		@line = split(/\t+/,&fix_worddoc($currline));

		if ($#line > -1) {
			$newline = &process_line($format,$lineno,@line);
			$questno++;
			$categories{$currcategory}{count}++;
			print $newline;
			}

		$currline = $nextline;

		$nextline = <FILE>;
		}
	close(FILE);

	print STDERR 
	   "Processed $lineno lines, and $questno questions from $filename\n";

	&print_categories(%categories);

	&print_q_types();

	if ($TRUE_COUNT + $FALSE_COUNT > 0) {
		$tot = $TRUE_COUNT + $FALSE_COUNT;
		$t_per = 100.0 * $TRUE_COUNT / $tot;
		$f_per = 100.0 * $FALSE_COUNT / $tot;

		printf STDERR "\n%d true (%5.1f%%), %d false (%5.1f%%)\n",
		  	$TRUE_COUNT, $t_per, $FALSE_COUNT, $f_per;
		}
	}
#
#----------------------------------------------------------------------
#

sub main {
	my(@args) = @_;
	my($format) = $DEF_FORMAT;
	
	if ($#args == -1) {
		print STDERR "Usage: convert-q.pl [-b|-d|-p|-t] <input-file>\n";
		exit(1);
		}

	if ($args[0] eq "-b") { $format = "b"; shift @args; }
	if ($args[0] eq "-d") { $format = "d"; shift @args; }
	if ($args[0] eq "-p") { $format = "p"; shift @args; }
	if ($args[0] eq "-t") { $format = "t"; shift @args; }

	#if ($format eq "d") {
	#	print "# Reminder: The output file must end in .csv to work (brightspace limitation)\n";
	#	}

	&read_file(shift @args,$format);
	}

#
#----------------------------------------------------------------------
#

&main(@ARGV);
