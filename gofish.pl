#!/usr/bin/perl
###################
# Just another quick implementation of Go Fish!
# Written in an attempt to deal with boredom between projects.
# 
# Author: George Brink <siberianowl@yahoo.com>
###################


use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use Getopt::Long;

### Deal with options
our $applicationName = basename($0);
my ($printHelp,  $debug, $useIcons);
my ($sortHand, $handSize) = (1, 7);
GetOptions(
	'handSize=i' => \$handSize,
	'help' => \$printHelp,
	'sortHand!' => \$sortHand,
	'useIcons' => \$useIcons,
	'debug' => \$debug
) or usage();
usage() if $printHelp;


### setup the initial state of the game
srand (time ^ $$ ^ unpack "%L*", `ps axww | gzip -f`);
my @deck = shuffleDeck();
my (@humanHand, @computerHand);
for (my $initalHandSize=0; $initalHandSize<$handSize; $initalHandSize++) {
	push @humanHand, shift @deck;
	push @computerHand, shift @deck;
}
my (@humanBooks, @computerBooks);

### define card names
my @cardNamesLong = ('Ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King');
my @cardNamesShort = ('A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K');
my @cardSuits = ('Heart', 'Club', 'Diamond', 'Spade');

### For UTF8 terminals (almost all Linux's terms)
my %cardSuitIcons = ( 'H' => "\xE2\x99\xA5", 'D' => "\xE2\x99\xA6", 'C' => "\xE2\x99\xA3", 'S' => "\xE2\x99\xA0");
### For Non-UTF8 terminals (for example Windows's console)
#my %cardSuitIcons = ( 'H' => "\x03", 'D' => "\x04", 'C' => "\x05", 'S' => "\x06");

### Game starts here!
my $turn = int(rand(2));
print "Throwing coin ... ", ($turn ? "HEAD! I" : "TAIL! You"), " start\n";

while(1) {
	print "\n";
	if ($debug) {
		print "-----------------\n\tBefore Turn\n";
		print "\tMy hand is: ", cardSetToString(@computerHand), "\n";
		print "\tYour hand is: ", cardSetToString(@humanHand), "\n";
	}

	### first, remove completed books from both hands
	for (my $side=0; $side<2; $side++) {
		my $handToCheckForGroups = $side ? \@computerHand : \@humanHand;
		my $bookGroupToFill = $side ? \@computerBooks : \@humanBooks;
		my %groups;
		for my $card (@{$handToCheckForGroups}) {
			$groups{ int($card/4) } ++;
		}
		for my $k (sort {$a<=>$b} keys %groups) {
			if ($groups{$k} == 4) {
				push @{$bookGroupToFill}, $k;
				@{$handToCheckForGroups} = map { int($_ / 4) == $k ? () : $_ } @{$handToCheckForGroups};
			}
		}
	}

	### check for game completion
	if (scalar(@deck) == 0 and scalar(@computerHand) == 0 and scalar(@humanHand) == 0) {
		print "The game is over!\n";
		last;
	}

	### If after packing (or previous stealing) the hand is empty - go fish
	if (scalar(@computerHand) == 0) {
		print "My hand is empty, taking one from the deck...\n";
		push @computerHand, shift @deck;
	}
	if (scalar(@humanHand) == 0) {
		print "Your hand is empty, take one from the deck...\n";
		push @humanHand, shift @deck;
	}

	print "My books (", booksToString( @computerBooks), ") Your books (", booksToString( @humanBooks ), ")\n";


	my $presentedCard;
	if ($turn) {
		### computers turn
		my $askForIndex = int(rand(scalar(@computerHand)));
		$presentedCard = $computerHand[$askForIndex];
		my ($cardValue, $cardSuit) = decryptCard($presentedCard, 0);
		print "I have $cardValue of $cardSuit, do you have any ${cardValue}s?\n";
	} else {  ### Here starts Human's turn
		print "Your hand is: [", cardSetToString(@humanHand), "]\n";

		do {
			print "Which card would you show me? ";
			my $input = <>;
			chomp $input;
			if ($input =~ /^([A23456789JQK]|10)([HCDS])$/i ) {
				$presentedCard = encryptCard($1, $2);
				my ($v,$s) = decryptCard($presentedCard);
				if (! grep(/^$presentedCard$/, @humanHand)) {
					print "You do not have $v of $s. No cheating allowed!\n";
					$presentedCard = undef;
				} else {
					print "I see you have $v of $s. I will look for my ${v}s.\n";
				}
			} else {
				print "What is $input???\n";
			}
		} while(!defined($presentedCard));
		
	}



	my @found;
	for my $v ($turn ? @humanHand : @computerHand) {
		if (int($v / 4) == int($presentedCard / 4)) {
			push @found, $v;
		}
	}
	if (scalar(@found) == 0) {
		if ($turn) {
			print "I see... You do not. I'll go fish\n";
		} else {
			print "Sorry, I do not. Go fish!\n";
		}
		if (scalar(@deck)) {
			my $nextCard = shift @deck;
			if (!$turn or $debug) {
				my ($v,$s) = decryptCard($nextCard);
				print "Fished out $v of $s\n";
			}
			if ($turn) {
				push @computerHand, $nextCard;
			} else {
				push @humanHand, $nextCard;
			}
			if ( int($presentedCard / 4) == int($nextCard / 4) ) {
				my ($v, $s) = decryptCard($nextCard);
				if ($turn) {
					print "Suceess! I got $v of $s. I'll continue\n";
				} else {
					print "Lucky you... Please continue\n";
				}
				$turn = $turn?0:1; # in order to repeat the turn we need to do extra flip
			}
		} else {
			print "Deck is empty... ", $turn?'You':'Mine', " turn\n";
		}
	} else { # @found is not empty
		if ($turn) {
			print "You do? Nice! I am taking [";
		} else {
			print "Here you go: [";
		}
		print cardSetToString(@found), "]\n";
		if ( $turn) {
			push @computerHand, @found;
			@humanHand = map { int($_ / 4) == int($presentedCard / 4) ? () : $_ } @humanHand;
		} else {
			push @humanHand, @found;
			@computerHand = map { int($_ / 4) == int($presentedCard / 4) ? () : $_ } @computerHand;
		}
	}


	$turn = $turn ? 0 : 1;


	if ($debug) {
		print "\tAfter Turn\n";
		print "\tMy hand is: ", cardSetToString(@computerHand), "\n";
		print "\tYour hand is: ", cardSetToString(@humanHand), "\n";
	}
}

print "\n\nFinal result:\nMy books: ", booksToString(@computerBooks), "\nYour books: ", booksToString(@humanBooks), "\n";
if (scalar(@computerBooks) < scalar(@humanBooks) ) {
	print "You win, congratulations!\n";
} else {
	print "I win, he-he-he...\n";
}
#print Dumper(@deck, @humanHand, @computerHand);



#####################################################################
sub decryptCard {
	my $cardIndex = $_[0];
	if ($_[1]) {
		return ( $cardNamesShort[ int($cardIndex / 4)  ], substr($cardSuits[ $cardIndex % 4 ],0,1) );
	} else {
		return ( $cardNamesLong[ int($cardIndex / 4) ], $cardSuits[$cardIndex % 4] );
	}
}
sub encryptCard {
	my ($cardValue, $cardSuit) = (uc($_[0]), uc($_[1]));
	my $cardIndex = 0;
	while ($cardIndex<scalar(@cardSuits) and substr($cardSuits[$cardIndex],0,1) ne $cardSuit) {$cardIndex++;}
	for my $vs (@cardNamesShort) {
		last if ($vs eq $cardValue);
		$cardIndex += 4;
	}
	return $cardIndex;
}

#####################################################################
sub cardSetToString {
	my @set = @_;
	@set = sort({$a <=> $b} @set) if ($sortHand);

	my @names;
	for my $cardID (@set) {
		my ($v,$s) = decryptCard($cardID, 1);
		$s = $cardSuitIcons{$s} if ($useIcons);
		push @names, "$v$s";
	}
	return join(', ', @names);
}

sub booksToString {
	my @books = @_;
	@books = sort({$a<=>$b} @books) if($sortHand);
	my @bookNames = map { $cardNamesShort[ $_ ] } @books;
	return join(', ', @bookNames);
}

#####################################################################
sub shuffleDeck {
	my @deck;
	for (my $cardValue = 0; $cardValue<52; $cardValue++) {
		push @deck, $cardValue;
	}
	for (my $iteration = 0; $iteration<1000; $iteration++) {
		my $pos1 = rand(52);
		my $pos2 = rand(52);
		my $tempCard = $deck[$pos1];
		$deck[$pos1] = $deck[$pos2];
		$deck[$pos2] = $tempCard;
	}
	return @deck;
}


#####################################################################
sub usage {
	print <<EOT;
$applicationName is an attempt to fight boredom between projects.
Or more specifically this is a classic Go Fish!
Card are entered by the short name, case insensitive.
For example: ah and AH = Ace of Hearts, 10d = 10 of Diamonds, etc.

Options:
  --handSize=i      How many cards are dealed to players at the start? (7)
  --[no-]sortHand   Should cards in a hand be sorted or not? (yes)
  --[no-]useIcons   Show suit icons instead of letters? (no)
  --help            This text
  --debug           Cheating mode (will show computer's hand)
EOT
	exit 0;
}
