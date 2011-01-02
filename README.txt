This an (almost) drop-in replacement for the unhosted.php shipping with the current Unhosted code base.

To use, place in a CGI-enabled directory on your server.

Then, find the unhosted.js file and then find the line containing "xmlhttp.open("POST" - without the outer quotes.
Replace the unhosted.php reference with the path to unhosted.pl

Open unhosted.pl and edit the log in details so they correspond to a valid MySQL user with access to the unhosted database.
Save changes, make sure unhosted.pl is executable (chmod 755 or similar).

Finally, you'll need to create the unhosted database. To do this log in as user with a "CREATE" grant and issue a

CREATE DATABASE unhosted;

or similar, change unhosted to the desired database name. 

Make sure the user of the perl script can do at least SELECT, UPDATE, INSERT, and DELETE. If you wish to also create your tables
through the script, that user will need a CREATE grant as well. If you wish to create those yourself, make sure to set the

$CAN_CREATE_TABLES

variable in unhosted.pl to 0.

The commands needed to create the two tables are:

CREATE TABLE `entries` (`chan` varchar(255), `app` varchar(255), `keyPath` varchar(255), `save` blob, PRIMARY KEY (`chan`, `app`, `keyPath`));		
CREATE TABLE `messages` (`chan` blob, `app` blob, `keyPath` blob, `save` blob)");

At this point you should have a working unhosted back-end. 