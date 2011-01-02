#!/usr/bin/perl

#
#    Unhosted storage node. Stores unhosted JSON for unhosted web apps.
#    Copyright (C) 2011 Nezerbahn (nezerbahn@gmail.com) for unhosted (http://www.unhosted.org)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use DBI;

$db = "unhosted";
$table = "";
$user = "uhtest";
$host = "localhost";
$password = "";

# allow creation of tables if they don't exist?
# if security is a concern, set to 0 (false)
$CAN_CREATE_TABLES = 1;


# max payload size for either GET or POST requests we wish to allow
$MAX_PAYLOAD = 65535;

# supported protocols, currently the preliminary 0.1 spec
@PROTOCOLS = ("UJ/0.1");

# protocol-specific fields we assign: when assigned, they will be accessed as $_{protocol}, $_{cmd} ...
@UHfields = ("protocol", "cmd", "PubSign", "WriteCaps", "ReadCaps");
# subfields, access as $_{u_method}, $_{u_chan} etc
@UHsubfields = ("method", "chan", "keyPath", "value", "delete");


# for WriteCaps
# these are basically username (R) to password (W) matching hashes - in reality
# these would be auto-generated and there would be more of them; this list provided
# for compatibility with the unhosted 0.1 code base
@chansR = ("7db31", "140d9", "b3108", "fabf8", "f56b6", "b569c", "cf2bb", "98617");
@chansW = ("0249e", "0e09a", "a13b4", "32960", "93541", "7a981", "7d2f0", "e1608");

# main
print "Content-Type: text/html\n";
print "Access-Control-Allow-Origin: *\n";
print "Access-Control-Allow-Methods: GET, POST, OPTIONS\n";
print "Access-Control-Allow-Headers: Content-Type\n";
print "Access-Control-Max-Age: 86400\n";
print "\n";

$GETdata = $ENV{'QUERY_STRING'};
$POSTdata = <STDIN>;
if(length($POSTdata) > $MAX_PAYLOAD || length($GETdata) > $MAX_PAYLOAD) { dienice("Excessive request length. Try less next time!"); }
$referer = $ENV{'HTTP_REFERER'};
$myhost = $ENV{'HTTP_HOST'};
$GETdata =~ s/\+/ /g;
$POSTdata =~ s/\+/ /g;
# clean up ampersands if we receive doubled or tripled ones in response
# ideally, this shouldn't happen; in reality it may and we handle it with this
$POSTdata =~ s/\&\&/\&/g;
$POSTdata =~ s/\&\&\&/\&/g;

if((!defined($referer)) || $referer eq "")
{
  dienice("This url is an unhosted JSON storage, and only works over CORS-AJAX. Please access using the unhosted JS library (www.unhosted.org).");
}

@POST = split(/&/, $POSTdata);
# get any variables presented assigned
&parse_UH_JSON();
#print "protocol=" . $_{protocol} . " cmd=" . $_{cmd} . "\n";
#print "method=" . $_{u_method} . " chan=" . $_{u_chan} . " keyPath=" . $_{u_keyPath} . " value=" . $_{u_value} . "\n";

my $foundhandle = 0;
if(defined($_{protocol}) && ($_{protocol} ne ""))
{
  my $protoid = 0;
  foreach my $prototest (@PROTOCOLS)
  {
    if($prototest eq $_{protocol})
    {
      $foundhandle++;
      &HandleProtocol($protoid);
      last;
    }
    
    $protoid++;
  }
}

if($foundhandle == 0)
{
  dienice("please add a \"protocol\" key to your POST");
}

# ---- subs ----


# arg 1: channel to check
# arg 2: provided writecaps
# returns 1 on match, 0 on mismatch
sub CheckWriteCaps
{
   my $cnt = 0;
   if(defined(@_[0]) && defined(@_[1]))
   {
      foreach $ccheck (@chansR)
      {
        if(trim($ccheck) eq trim(@_[0]))
        {
          if(trim(@_[1]) eq trim(@chansW[$cnt]))
          {
            return 1;
          }
        }
        $cnt++;
      }
   } else { return 0; }
}

# main protocol handler for any/all supported protocols
sub HandleProtocol
{
  my $protoid = @_[0];
  if($protoid == 0)
  {
    &HandleUJ01();
  }
}

# handler for the current UJ/0.1 spec
sub HandleUJ01
{
  checkFieldsPresent($_{cmd}, "please add \"cmd\" key to your POST");
  # we have a decoded cmd
  checkFieldsPresent($_{u_method}, "please define a method inside your command");
  
  if(uc($_{u_method}) eq "SET")
  {
    checkFieldsPresent($_{WriteCaps}, "The SET command requires WriteCaps in the POST");
    checkFieldsPresent($_{PubSign}, "Please provide a PubSign so that your subscriber can check that this SET command really comes from you");
    checkFieldsPresent($_{u_chan}, "Please specify which channel you want to publish on");
    checkFieldsPresent($_{u_keyPath}, "Please specify which key path you're setting");
    checkFieldsPresent($_{u_value}, "Please specify a value for the key you're setting");
    # all good
    print dbSet("entries", $_{u_chan}, $myhost, $_{u_keyPath}, JSON_encode("cmd", $_{cmd}, "PubSign", $_{PubSign}));
  }
  
  if(uc($_{u_method}) eq "GET")
  {
    checkFieldsPresent($_{u_chan}, "Please specify which channel you want to publish on");
    checkFieldsPresent($_{u_keyPath}, "Please specify which key path you're setting");
    print dbGet("entries", $_{u_chan}, $myhost, $_{u_keyPath});
  }
  
  if(uc($_{u_method}) eq "SEND")
  {
    my $pstemp = $_{PubSign};
    if(!defined($_{PubSign}))
    {
      $pstemp = "";
    }
    checkFieldsPresent($_{u_chan}, "Please specify which channel you want to publish on");
    checkFieldsPresent($_{u_keyPath}, "Please specify which key path you're setting");
    checkFieldsPresent($_{u_value}, "Please specify a value for the key you're setting");
    print dbSend("messages", $_{u_chan}, $myhost, $_{u_keyPath}, JSON_encode("cmd", $_{cmd}, "PubSign", $pstemp));
  }
  
  if(uc($_{u_method}) eq "RECEIVE")
  {
    checkFieldsPresent($_{WriteCaps}, "The SET command requires WriteCaps in the POST");
    checkFieldsPresent($_{u_chan}, "Please specify which channel you want to publish on");
    checkFieldsPresent($_{u_keyPath}, "Please specify which key path you're setting");
    checkFieldsPresent($_{u_delete}, "Please specify whether you also want to delete the entries you retrieve");
    print dbGetR("messages", $_{u_chan}, $myhost, $_{u_keyPath}, $_{u_delete});
  }
  
}

# prints an error message and bails
sub dienice 
{
  my($errmsg) = @_;
  print "<h2>Error</h2>\n";
  print "$errmsg<p>\n";
  print "</body></html>\n";
  exit;
}

# arg 1: table to use
# arg 2...n - field values, must be in correct order
sub dbSet
{
  if(CheckWriteCaps($_{u_chan}, $_{WriteCaps}) == 0)
  {
    return "Channel password is incorrect.";
  }
  checkTable(@_[0]);
  my $sql = "";
  
  # set
  if(@_[0] eq "entries")
  {
    $table = @_[0];
    $dbh = DBI->connect("DBI:mysql:database=$db;host=$host", $user, $password)
    or dienice ("Connecting (oper): $DBI::errstr\n ");
    $sql = "INSERT INTO entries (`chan`, `app`, `keyPath`, `save`) VALUES (";
    $sql .= $dbh->quote(@_[1]) . ", " . $dbh->quote(@_[2]) . ", " . $dbh->quote(@_[3]) . ", " . $dbh->quote(@_[4]);
    $sql .= ") ON DUPLICATE KEY UPDATE save=" . $dbh->quote(@_[4]) . ";";
    $dbh->do($sql) or dienice ("DB Operation: $DBI::errstr\n ");
    $dbh->disconnect();
  }
  
  return "\"OK\"";
}

# arg 1: table to use
# arg 2...n - field values, must be in correct order
sub dbSend
{
  checkTable(@_[0]);
  my $sql = "";
  
  # send
  if(@_[0] eq "messages")
  {
    $table = @_[0];
    $dbh = DBI->connect("DBI:mysql:database=$db;host=$host", $user, $password)
    or dienice ("Connecting (oper): $DBI::errstr\n ");
    $sql = "INSERT INTO messages (`chan`, `app`, `keyPath`, `save`) VALUES (";
    $sql .= $dbh->quote(@_[1]) . ", " . $dbh->quote(@_[2]) . ", " . $dbh->quote(@_[3]) . ", " . $dbh->quote(@_[4]);
    $sql .= ");";
    $dbh->do($sql) or dienice ("DB Operation: $DBI::errstr\n ");
    $dbh->disconnect();
  }
  
  return "\"OK\"";
}
# gets from messages
# arg 1: table
# arg 2-4: fields to look up for response
sub dbGetR
{
  if(CheckWriteCaps($_{u_chan}, $_{WriteCaps}) == 0)
  {
    return "Channel password is incorrect.";
  }
  
  my $sql = "";
  # RECEIVE
  if(@_[0] eq "messages")
  {
    $table = @_[0];
    $dbh = DBI->connect("DBI:mysql:database=$db;host=$host", $user, $password)
    or dienice ("Connecting (oper): $DBI::errstr\n ");
    $sql = "SELECT save FROM messages WHERE chan=" . $dbh->quote(@_[1]) . " AND app=" . $dbh->quote(@_[2]) . " AND keyPath=" . $dbh->quote(@_[3]);
    # NOTE: above assumes only one result will be returned; we are doing the same
    $sth = $dbh->prepare($sql) or dienice ("Preparing: ", $dbh->errstr);
    $sth->execute or dienice ("Executing: ", $dbh->errstr);
    my $qcount = $DBI::rows;
    my $ccount = 0;
    my $response = "[";
    if($qcount > 0)
    {
      while(my $row = $sth->fetchrow_hashref)
      {
        $response .= $row->{'save'};
        if($qcount > 1)
        {
          if($ccount < ($qcount - 1))
          {
            $response .= ",";
          }
        }
        $ccount++;
      }
      $response .= "]";
      $sth->finish();
      $dbh->disconnect();
      # delete it?
      if((@_[4] eq "true") || (@_[4] eq "1"))
      {
        $dbh = DBI->connect("DBI:mysql:database=$db;host=$host", $user, $password)
        or dienice ("Connecting (oper): $DBI::errstr\n ");
        $sql = "DELETE FROM messages WHERE chan=" . $dbh->quote(@_[1]) . " AND app=" . $dbh->quote(@_[2]) . " AND keyPath=" . $dbh->quote(@_[3]);
        $dbh->do($sql) or dienice ("DB Operation: $DBI::errstr\n ");
        $dbh->disconnect();
      }
      #
      return $response;
      
    } else { return "[]"; }
  }
}


# gets from entries
# arg 1: table
# arg 2-4: fields to look up for response
sub dbGet
{
  my $sql = "";
  # get
  if(@_[0] eq "entries")
  {
    $table = @_[0];
    $dbh = DBI->connect("DBI:mysql:database=$db;host=$host", $user, $password)
    or dienice ("Connecting (oper): $DBI::errstr\n ");
    $sql = "SELECT save FROM entries WHERE chan=" . $dbh->quote(@_[1]) . " AND app=" . $dbh->quote(@_[2]) . " AND keyPath=" . $dbh->quote(@_[3]);
    # NOTE: above assumes only one result will be returned; we are doing the same
    $sth = $dbh->prepare($sql) or dienice ("Preparing: ", $dbh->errstr);
    $sth->execute or dienice ("Executing: ", $dbh->errstr);
    my $qcount = $DBI::rows;
    if($qcount > 0)
    {
      my $row = $sth->fetchrow_hashref;
      my $retv = $row->{'save'};
    } else { $retv = "{}"; }
    $sth->finish();
    $dbh->disconnect();
    return $retv;
  }
}

#
sub checkTable
{
  my $sql = "";
  $table = @_[0];
  $dbh = DBI->connect("DBI:mysql:database=$db;host=$host", $user, $password)
  or dienice ("Connecting (oper): $DBI::errstr\n ");
  $sql = "SHOW TABLES LIKE " . $dbh->quote($table);
  $sth = $dbh->prepare($sql) or dienice ("Preparing: ", $dbh->errstr);
  $sth->execute or dienice ("Executing: ", $dbh->errstr);
  my $qcount = $DBI::rows;
  $sth->finish();
  if($qcount == 0)
  {
    if($CAN_CREATE_TABLES == 1)
    {
      $sql = "CREATE TABLE IF NOT EXISTS entries (`chan` varchar(255), `app` varchar(255), `keyPath` varchar(255), `save` blob, PRIMARY KEY (chan, app, keyPath))";
      $dbh->do($sql) or dienice ("DB Operation: $DBI::errstr\n ");
      $sql = "CREATE TABLE IF NOT EXISTS messages (`chan` blob, `app` blob, `keyPath` blob, `save` blob)";
      $dbh->do($sql) or dienice ("DB Operation: $DBI::errstr\n ");
    } else {
      dienice("Required tables don't exist and they can't be created.");
    }
  }
  $dbh->disconnect();
}

# arg 1: field to check
# arg 2: error message if not defined
# displays message and terminates script
sub checkFieldsPresent
{
  if(defined(@_[0]))
  {
    
  } else {
    dienice(@_[1]);
  }
}

# leave only db-safe (url-encoded) chars in output string
# if any illegal chars are found, nothing is returned
# this allows alphanumerics and the period, so it is very restrictive
sub dbsafe
{
 my $rv = @_[0];
 if($rv =~ /^[a-zA-Z0-9.]+$/)
 {
    return $rv;
 }
 return "";
}

# removes whitespace both at the beginning and end of the expression
sub trim($)
{
 my $string = shift;
 $string =~ s/^\s+//;
 $string =~ s/\s+$//;
 return $string;	
}

# encodes the argument as a string of concatenated hex values
sub hexencode
{
  my $rv = @_[0];
  $rv =~ s/(.)/sprintf("%x",ord($1))/eg;
  return $rv;
}

# parses POST-encoded unhosted JSON data
sub parse_UH_JSON
{
  my @POSTn;
  my @POSTv;
  my $fname = "";
  my $vpair = "";
  
  foreach $vpair (@POST)
  {
    my @S1 = split(/=/, $vpair);
    if(scalar(@S1) == 2)
    {
      push(@POSTn, (trim(@S1[0])));
      push(@POSTv, (trim(@S1[1])));
    } else {
      # ignore it
    }
  }
  
  foreach $fname (@UHfields)
  {
    for(my $i = 0; $i < scalar(@POSTn); $i++)
    {
      if(($fname eq @POSTn[$i]))
      {   
            $_{$fname} = @POSTv[$i];
            last;
      }
    }
  }
  if((defined $_{cmd}) && ($_{cmd} ne ""))
  {
    &parse_UH_subfields($_{cmd});
  }
}

sub parse_UH_subfields
{
  my @UFV = split(/,/, @_[0]);
  my $fname = "";
  
  foreach $vpair (@UFV)
  {
    my @S1 = split(/:/, $vpair);
    if(scalar(@S1) == 2)
    {
      my $S1n = @S1[0];
      my $S1v = @S1[1];
      $S1n =~ s/\"//g;
      $S1n =~ s/{//g;
      $S1v =~ s/\"//g;
      $S1v =~ s/}//g;
      foreach $fname (@UHsubfields)
      {
        if($fname eq $S1n)
        {
          my $faname = "u_" . $fname;
          $_{$faname} = $S1v;
        }
      }
    }
  }
}

# provide data in pairs
# field name, field value
# output is JSON-encoded
sub JSON_encode
{
  my $outpt = "{";
  if((scalar(@_) % 2) != 0) { return ""; }
  if(scalar(@_) == 0) { return ""; }
  #
  for(my $jsc = 0; $jsc < (scalar(@_) - 1); $jsc += 2)
  {
    $outpt .= "\"" . @_[$jsc] . "\":";
    if(substr(@_[$jsc+1], 0, 1) eq "{")
    {
      $outpt .= @_[$jsc+1];
    } else {
      $outpt .= "\"" . @_[$jsc+1] . "\"";
    }
    if($jsc < (scalar(@_) - 2))
    {
      $outpt .= ",";
    }
  }
  $outpt .= "}";
  return $outpt;
}