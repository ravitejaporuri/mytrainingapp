#!/usr/bin/perl

my $filename = "BookData.txt.log";

open ( MYFH , "<" . $filename ) || die ("cannot open the file BookData.txt.log : $!\n") ;
	my @Lines = <MYFH> ;
close ( MYFH ); 



for my $Line (@Lines)
{

$Line =~ s/^\s+//g; ### Removing the first column spaces only
$Line =~ s/\s+/ /g; ### Removing multiple spaces in between

my ($Data1, $Data2) = (split (/\|/, $Line));

my ($Booktype, $BookSize, $BidPrice) = (split (/ /,$Data1))[0,2,3];
my ($AskPrice, $AskSize) = (split (/ /,$Data2))[2,3];

#print "\$BookSize = $BookSize, \$BidPrice = $BidPrice, \$AskPrice = $AskPrice, \$AskSize = $AskSize\n";

if ("$Booktype" == "Book*")
{
  ### Temporary variables to check the Ask price and Bid Prices
  my $temp1 = 0;
  my $temp2 = 0;
  $bookname = (split (/ /,$Data1))[2];
  next;
}
if (("$BidPrice" > "0") && ("$AskPrice" > "0"))
{

 if ("$BidPrice" == "Price" || "$BidPrice" == "") ### Skipping the Table convention
  {
	next;
  }
 if ("$BidPrice" == "$AskPrice")
  {
	print "The best bid is equal to best ask which should not be the case \n";
	next;
  }
 if ("$BidPrice" <= "0")
  {
	print "Bidding not possible as the Value is 0 or negative \n";
	next;
  }
 if ("$BookSize" <= "0")
  {
	print " Book Size is invalid. Neglecting this case \n";
	next;
  }
 if ("$AskSize" <= "0")
  {
	print "Book Ask Price is invalid. Neglecting this case \n";
	next;
  } 
 if ("$temp1" != "0" && "$temp1" < "$BidPrice")
  {
	print "Bids are not in descending order \n";
	$temp1 = $BidPrice;
	next;
  }
 else
  {
	$temp1 = $BidPrice;
  }
 if (("$temp2" != "0" && "$temp2" > "$AskPrice"))
  {
	print "Ask price is not in ascending order\n";
	$temp2 = $AskPrice;
	next;
  }
 else
  {
	$temp2 = $AskPrice;
  }
 if ((defined $AskPrice && "$BidPrice" > "$AskPrice"))
  {
	print "Bid is greater than ask price\n";
	next;
  }
}  ## End of IF statement checking for Bid Price and Ask Price greater than 0

else ## As the Bid price / Ask price is not available, skipping to the next line
  {
	next;
  }

} ## End of For loop
