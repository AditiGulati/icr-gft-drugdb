#!/usr/bin/perl -w
# rnaidb.pl - CGI UI for RNAi database

use strict;
use CGI;
use CGI qw( :standard );
use CGI::Carp qw ( fatalsToBrowser );
use DBI;
use Digest::MD5 qw ( md5 md5_hex md5_base64 );
use FileHandle;
use File::Copy qw(copy);
use File::Copy qw(move);
use File::Path qw(rmtree);

# for new file upload - fixes the error :- use string ("test_plateconf.txt") as a symbol ref while "strict refs" in use at...
no strict 'refs';
# to check if an error is due to dbi or not
use Data::Dumper;

# Get the name of the script from $0
$0 =~ /([^\/]+)$/;

my $script_name = $1;
my $conf_file = $script_name;
$conf_file =~ s/pl$/conf/;

## stuff to configure when moving... ##

my $users_file = './users.txt';
my $temp_file_path = '/tmp/tmp.csv';

# These are the basic set of options
my %configures = &get_configures_hash($conf_file);

sub get_configures_hash{
        my $configures = shift;
        my %configures;
        open RES, "< $configures" or die "Can't read list of configures from file:\n$configures\n$!\n";
        while(<RES>){
                next if /^(#|[\n\r])/;
                my ($key, $value);
                if(/^([^\t]+)\t+([^\t]+)/){
                        $key = $1;
                        $value = $2;
                }
                chomp($value);
                if(exists($configures{$key})){die "configure: $key is duplicated in the configures file $configures\n\nYou need to fix that to continue\n";}
                $configures{$key} = $value;
        }
        return %configures;
}
my $sqldb_name = $configures{'sqldb_name'};
my $sqldb_host = $configures{'sqldb_host'};
my $sqldb_port = $configures{'sqldb_port'};
my $sqldb_user = $configures{'sqldb_user'};
my $sqldb_pass = $configures{'sqldb_pass'};

## Declare variables globally ##

my $ISOGENIC_SET;
my $ADD_NEW_FILES_LINK = $configures{'hostname'} . "cgi-bin/$script_name?add_new_files=1";

#my $username;
#my $password;
 
$| = 1;
#$|++;

#STDOUT->autoflush(1);
#STDERR->autoflush(1);

# These are needed to allow file uploads
# whilst reducing the risk of attack (someone
# uploading a huge file and filling the disk)
$CGI::DISABLE_UPLOADS = 0;
$CGI::POST_MAX = 1024 * 1000;
# $CGI::POST_MAX limits the max size of a post in bytes
# Note that most of the XLS files from the plate reader
# are below 500 KB

# security config
my $num_hash_itts = 500;
my $auth_code_salt = "1IwaCauw4Lxum6WU5hM8";
# The $auth_code_salt should be read in from
# a file that is generated if it doesn't exist

# HTML strings used in pages:

my $page_header = "<html>
				   <head>
				   <meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />
				   <title>GFT DRUG database</title>
				   <link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"/css/rnaidb.css\" />
				   <meta name=\"viewport\" content=\"width=1000, initial-scale=0.5, minimum-scale=0.45\" />
				   </head>
				   <body>
				   <div id=\"Box\"></div><div id=\"MainFullWidth\">
				   <a href=$configures{'hostname'}><img src=\"http://gft.icr.ac.uk/images/ICR_GFT_drugDB_logo_placeholder.png\" width=415px height=160px></a>
				   <p>
				   <a href=\"/cgi-bin/$script_name?add_new_screen=1\">Add new screen</a>\&nbsp;\&nbsp;
				   <a href=\"/cgi-bin/$script_name?show_all_screens=1\">Show all screens</a>\&nbsp;\&nbsp;
				   <a href=\"/cgi-bin/$script_name?compute_drug_effect=1\">Drug effect analysis</a>\&nbsp;\&nbsp;
				   <a href=\"/cgi-bin/$script_name?show_all_drug_effect_screens=1\">Drug effect results</a>\&nbsp;\&nbsp;
				   <a href=\"/cgi-bin/$script_name?limma_analysis=1\">Limma analysis</a>\&nbsp;\&nbsp;
				   <a href=\"/cgi-bin/$script_name?show_all_limma_screens=1\">Limma results</a>\&nbsp;\&nbsp;
				   <a href=\"/cgi-bin/$script_name?configure_export=1\">Configure export</a>\&nbsp;\&nbsp;
				   </p>";
				   
# HTML strings used in add new screen:

#my $tissue_file = $configures{'screenDir_path'} . "tissue_type.txt";
#my $tissue_list;
#my $t_l;
#open IN, "< $tissue_file"
  #or die "Cannot open $tissue_file:$!\n";

#while (<IN>) {
  #if ($_ =~ /^ADRENAL/) {
    #$t_l = $tissue_list;
 # }
#}
#$tissue_list = $_;
#chomp $tissue_list;
#close IN;

#my $cell_line_file = $configures{'screenDir_path'}. "cell_lines.txt";
#my $cell_line_list;
#my $c_l;
#open IN, "< $cell_line_file"
  #or die "Cannot open $cell_line_file:$!\n";
#while (<IN>) {
  #if ($_ =~ /^1321N1/) {
   # $c_l = $cell_line_list;
  #}
#}
#$cell_line_list = $_;
#chomp $cell_line_list;
#close IN;
 

				   						 				   						  				   
my $page_footer = "</div> <!-- end Main --></div> 
				   <!-- end Box -->
				   </body>
				   </html>";

#$ISOGENIC_SET = $q -> param( "isogenicSet" );
 # my $tissue_type = $q -> param( "tissue_type" );
 # my $cell_line_name = $q -> param( "cell_line_name" );
 # my $date_of_run = $q -> param( "date_of_run" );
 # my $operator = $q -> param( "operator" );
 # my $transfection_reagent = $q -> param( "transfection_reagent" );
 # my $instrument = $q -> param( "instrument" );
 # my $is_isogenic = $q -> param( "is_isogenic" );
 # my $gene_name_if_isogenic = $q -> param( "gene_name_if_isogenic" );
 # my $new_isogenic_set = $q ->  param( "name_of_set_if_isogenic" );
#  my $isogenic_mutant_description = $q -> param( "isogenic_mutant_description" );
 # my $method_of_isogenic_knockdown = $q -> param( "method_of_isogenic_knockdown" );

# == config over, code below == #

# make a new CGI object
my $q = new CGI;

# This line may need to be moved in the future
# it allows us to create a hash to add to the 
# users.txt file...
#if ($q -> param( "authenticate_user" )){
#  &authenticate_user ( $q );
#}
#elsif ($q -> param( "add_new_user" )){
#  &add_new_user ( $q );
#}
#elsif ($q -> param( "login" )){
#  &login ( $q );
#}

# either get a cookie or go to login page and exit
#my $login_key = $q -> cookie("login_key") || &login($q) && exit(0);
my $login_key = $q -> cookie ( "login_key" );

# if we got a cookie, is it valid?
#my $user = &authenticate_login_key($login_key);


# connect to the database
my $dsn = "DBI:mysql:database=$sqldb_name;host=$sqldb_host;port=$sqldb_port";
my $dbh = DBI -> connect ( $dsn, $sqldb_user, $sqldb_pass, { RaiseError => 0, AutoCommit => 1 } )
  or die "Cannot connect to database: " . $DBI::errstr;
  

# Decide what to do based on the params passed to the script
if( $q -> param ( "logout" ) ) {
  &logout ( $q );
}
elsif ( $q -> param( "show_all_screens" )) {
  &show_all_screens ( $q );
}
elsif ( $q -> param( "add_new_screen" )) {
  &add_new_screen ( $q );
}
elsif ( $q -> param( "save_new_screen" )) {
  &save_new_screen ( $q );
}
elsif ( $q -> param( "add_new_files" )) {
  &add_new_files ( $q );
}
elsif ( $q -> param( "compute_drug_effect" )) {
  &compute_drug_effect ( $q );
}
elsif ( $q -> param( "save_drug_effect_screens" )) {
  &save_drug_effect_screens ( $q );
}
elsif ( $q -> param( "limma_analysis" )) {
  &limma_analysis ( $q );
}
elsif ( $q -> param( "save_limma_analysis" )) {
  &save_limma_analysis ( $q );
}
elsif ( $q -> param( "show_all_drug_effect_screens" )) {
  &show_all_drug_effect_screens ( $q );
}
elsif ( $q -> param( "show_all_limma_screens" )) {
  &show_all_limma_screens ( $q );
}
elsif ( $q -> param( "save_new_uploaded_plateconf_file" )) {
  &save_new_uploaded_plateconf_file ( $q );
}
elsif ( $q -> param ( "save_new_uploaded_platelist_file" )) {
  &save_new_uploaded_platelist_file ( $q );
}
elsif ( $q -> param ( "save_new_uploaded_templib_file" )) {
  &save_new_uploaded_templib_file ( $q );
}
elsif ( $q -> param ( "configure_export" )) {
  &configure_export ( $q );
}
elsif ( $q -> param ( "show_qc" )) {
  &show_qc ( $q );
}
elsif ( $q -> param ( "save_qc_status" )) {
  &save_qc_status ( $q );
}
elsif ( $q -> param ( "run_export" )) {
  &run_export ( $q );
}
else {
 &home ( $q );
}


# home sub for debugging

# ===================
# subroutine for home
# ===================

sub home { 
  print $q -> header ( "text/html" );
#  my $user = $q -> param('user');
  print "$page_header";

  # read data from database and output
  # summary info about all screens

  print "<h1>Hello!</h1>";
  #if ( defined ( $login_key ) ) {
  #  print "got cookie $login_key<br />";
  #}
  #else {
  #  print "Where's my cookie?"
  #}
  
  if ($script_name =~ "devel")
  {
  	print "<p>This is the test version.</p>";
  	print "<p>Data will be deleted.</p>";
  }
  else
  {
  	print "<p>This is the working version of DRUG database.</p>";
  }
  
  #print "<p>";
  #print "<p>Configname is $conf_file</p>";
  #print "</p>";
  
  #print "<p>";
  #print "<p>Connected to the database $sqldb_name</p>";
  #print "</p>";
  
  print "$page_footer";
  print $q -> end_html;
}


# ================================
# subroutine for adding new screen
# ================================

sub add_new_screen {
  print $q -> header ( "text/html" );
  my $user = $q -> param( 'user' );
  my $page_header_for_add_new_screen_sub1 = "<html>
				   						  <head>
				   						  <meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />
				   						  <title>GFT DRUG database</title>
				   						  <link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"/css/rnaidb.css\" />
				   						  <meta name=\"viewport\" content=\"width=1000, initial-scale=0.5, minimum-scale=0.45\" />
				   						  <link rel=\"stylesheet\" href=\"http://code.jquery.com/ui/1.11.1/themes/smoothness/jquery-ui.css\">
				    					  <script src=\"http://code.jquery.com/jquery-1.10.2.js\"></script>
				   						  <script src=\"http://code.jquery.com/ui/1.11.1/jquery-ui.js\"></script>
				   						  <script>
										   \$(function() {
											   var availableTissues = [";
 my $page_header_for_add_new_screen_sub2=  "\$( \"#tissues\" ).autocomplete ({
										    source: availableTissues
										    });
										    \$( \"#celllines\" ).autocomplete ({
										    source: availableCellLines
										    });
										  });									  
										  function make_tissues_Blank() {
										    var a = document.getElementById( \"tissues\" );
										    if (a.value == \"Enter tissue type\")
										    {
										    	a.value = \"\";
										    }
										  }
										  function make_cellLines_Blank() {
										    var b = document.getElementById( \"celllines\" );
										    if (b.value ==\"Enter cell line name\")
										    {
										    	b.value = \"\";
										    }
										  }    
										  function make_collab_Blank() {
										    var b = document.getElementById( \"CollaboratoR\" );
										    if (b.value ==\"Optional\")
										    {
										    	b.value = \"\";
										    }
										  }   
										  function make_cellsPerWell_Blank() {
										    var b = document.getElementById( \"CellsperwelL\" );
										    if (b.value ==\"Enter cell number\")
										    {
										    	b.value = \"\";
										    }
										  }    
										  function make_lengthOfAssay_Blank() {
										    var b = document.getElementById( \"LengthofassaY\" );
										    if (b.value ==\"Enter length of assay\")
										    {
										    	b.value = \"\";
										    }
										  } 
										  function enableText() {
										    if(document.addNewScreen.is_isogenic.checked) {
										      document.addNewScreen.gene_name_if_isogenic.disabled = false;
										      document.addNewScreen.isogenic_mutant_description.disabled = false;
										      document.addNewScreen.method_of_isogenic_knockdown.disabled = false;
										    }
										    else {
										      document.addNewScreen.gene_name_if_isogenic.disabled = true;
										      document.addNewScreen.isogenic_mutant_description.disabled = true;
										      document.addNewScreen.method_of_isogenic_knockdown.disabled = true;
										    }
										  } 
										  function enableText_DS() {
										    if(document.addNewScreen.is_drug_screen.checked) {
										      document.addNewScreen.compound.disabled = false;
										      document.addNewScreen.concentration.disabled = false;
										      document.addNewScreen.dosing_regime.disabled = false;  
										    }
										    else {
										      document.addNewScreen.compound.disabled = true;
										      document.addNewScreen.concentration.disabled = true;
										      document.addNewScreen.dosing_regime.disabled = true;  
										    }
										  }
										  function make_geneName_Blank() {
										    var c = document.getElementById( \"geneName\" );
										    if(c.value == \"Enter gene name\")
										    {
										    	c.value = \"\";
										    }
										  } 
										  function make_isogenicDescription_Blank() {
										    var e = document.getElementById( \"isogenicDescription\" );
										    if (e.value == \"e.g. parental\")
										    {
										    	e.value = \"\";
										    }
										  } 
										  function make_isogenicKnockdown_Blank() {
										    var f = document.getElementById( \"isogenicKnockdown\" );
										    if (f.value = \"e.g. ZFN or shRNA\")
										    {
										    	f.value = \"\";
										    }
										  }  
										  function make_notes_Blank() {
										    var g = document.getElementById( \"NoteS\" );
										    if (g.value == \"write notes for Description.txt\")
										    {
										    	g.value = \"\";
										    }
										  }  
										  function make_compound_Blank() {
										    var h = document.getElementById( \"CompounD\" );
										    if (h.value == \"e.g. cisplatin\")
										    {
										    	h.value = \"\";
										    }
										  } 
										  function make_concentration_Blank() {
										    var i = document.getElementById( \"ConcentratioN\" );
										    if (i.value == \"e.g. 100 ng\")
										    {
										    	i.value = \"\";
										    }
										  }   
										  function make_dosingregime_Blank() {
										    var j = document.getElementById( \"dosingRegime\" );
										    if (j.value == \"e.g. 24 hrs after transfection\")
										    {
										    	j.value = \"\";
										    }
										  }  
										  function checkForm ( form ) {
										    if ( document.addNewScreen.uploaded_excel_file.value == '') {
										      alert ( \"Please select an Excel data file.\" );
										      return false;
										    }
										    
										    if ( document.addNewScreen.plate_conf.selectedIndex == 0 ) {
										      alert ( \"Please select plateconf file.\" );
										      return false;
										    }
										    if ( document.addNewScreen.plate_list.selectedIndex == 0 ) {
										      alert ( \"Please select platelist file.\" );
										      return false;
										    }
										    if ( document.addNewScreen.template_library.selectedIndex == 0 ) {
										      alert ( \"Please select template library file.\" );
										      return false;
										    }
										    if (( form[\"tissue_type\"].value == \"Enter tissue type\") || ( form[\"tissue_type\"].value == \"\")) {
										      alert ( \"Please enter tissue type.\" );
										      return false;
										    } 
										    if (( form[\"cell_line_name\"].value == \"Enter cell line name\") || ( form[\"cell_line_name\"].value == \"\")) {
										      alert ( \"Please enter cell line name.\" );
										      return false;
										    }
										    if ( form[\"operator\"].value == \"\" ) {
										      alert ( \"Please enter your name.\" );
										      return false;
										    }
										    if ( form[\"cells_per_well\"].value == \"Enter cell number\" ) {
										      alert ( \"Please enter number of cells per well.\" );
										      return false;
										    }
										    if ( document.addNewScreen.instrument.selectedIndex == 0 ) {
										      alert ( \"Please select instrument used for this screen.\" );
										      return false;
										    }
										    if ( form[\"length_of_assay\"].value == \"Enter length of assay\" ) {
										      alert ( \"Please enter length of assay.\" );
										      return false;
										    }
										    if ( document.addNewScreen.is_isogenic.checked && form[\"gene_name_if_isogenic\"].value == \"Enter gene name\") {
										      alert ( \"Please enter gene name.\" );
										      return false;
										    }
										    if ( document.addNewScreen.is_isogenic.checked && form[\"gene_name_if_isogenic\"].value == \"\" ) {
										      alert ( \"Please enter gene name.\" );
										      return false;
										    }
										    if ( document.addNewScreen.is_isogenic.checked && form[\"isogenic_mutant_description\"].value == \"e.g. parental\") {
										      alert ( \"Please enter isogenic description.\" );
										      return false;
										    }
										    if ( document.addNewScreen.is_isogenic.checked && form[\"isogenic_mutant_description\"].value == \"\" ) {
										      alert ( \"Please enter isogenic description.\" );
										      return false;
										    }
										    if ( document.addNewScreen.is_isogenic.checked && form[\"method_of_isogenic_knockdown\"].value == \"e.g. CRISPR or shRNA\") {
										      alert ( \"Please enter method of isogenic knockdown.\" );
										      return false;
										    }
										    if ( document.addNewScreen.is_isogenic.checked && form[\"method_of_isogenic_knockdown\"].value == \"\" ) {
										      alert ( \"Please enter method of isogenic knockdown.\" );
										      return false;
										    }
										    if ( document.addNewScreen.is_drug_screen.checked && form[\"compound\"].value == \"e.g. cisplatin\") {
										      alert ( \"Please enter compound name.\" );
										      return false;
										    }
										    if ( document.addNewScreen.is_drug_screen.checked && form[\"compound\"].value == \"\" ) {
										      alert ( \"Please enter compound name.\" );
										      return false;
										    }
										    var answer = confirm(\"Please make sure the data are correct. Don't forget to complete the isogenic/drugscreen part of the form if it's relevant. The data once saved cannot be edited easily.\")
										  	return answer;
										  }	
       									  </script>
				   						  </head>
				   						  <body>
				   						  <div id=\"Box\"></div><div id=\"MainFullWidth\">
				   						  <a href=$configures{'hostname'}><img src=\"http://gft.icr.ac.uk/images/ICR_GFT_drugDB_logo_placeholder.png\" width=415px height=160px></a>
				   						  <p>
				   						  <a href=\"/cgi-bin/$script_name?add_new_screen=1\">Add new screen</a>\&nbsp;\&nbsp;
				    					  <a href=\"/cgi-bin/$script_name?show_all_screens=1\">Show all screens</a>\&nbsp;\&nbsp;
				    					  <a href=\"/cgi-bin/$script_name?compute_drug_effect=1\">Drug effect analysis</a>\&nbsp;\&nbsp;
				   						  <a href=\"/cgi-bin/$script_name?show_all_drug_effect_screens=1\">Drug effect results</a>\&nbsp;\&nbsp;
				   						  <a href=\"/cgi-bin/$script_name?limma_analysis=1\">Limma analysis</a>\&nbsp;\&nbsp;
				   						  <a href=\"/cgi-bin/$script_name?show_all_limma_screens=1\">Limma results</a>\&nbsp;\&nbsp;
				   						  <a href=\"/cgi-bin/$script_name?configure_export=1\">Configure export</a>\&nbsp;\&nbsp;
				   						  </p>";
				   						  
  print "$page_header_for_add_new_screen_sub1";
  ## get the existing tissue type from the database ##
  my $tissueType;
  my @tissueType;
  
  my $query = "SELECT Tissue_of_origin FROM Tissue_type order by Tissue_of_origin";
  my $query_handle = $dbh -> prepare ( $query );
     				#or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle->execute();
  
  while ( $tissueType = $query_handle -> fetchrow_array ){
    push ( @tissueType, $tissueType );  
  }

  my $number_of_tissue_type = scalar @tissueType;
  my $i = undef;
  for ($i = 0; $i < $number_of_tissue_type-1; $i++)
  {
  	print "\"$tissueType[$i]\",\n";
  }
  print "\"$tissueType[$i]\"];\n";
  
  print "var availableCellLines = [";
  
  my $cellLineName;
  my @cellLineName;
 
  $query = "SELECT Cell_line_name FROM Cell_line order by Cell_line_name";
  $query_handle = $dbh -> prepare ( $query );
  $query_handle->execute();

  while ( $cellLineName = $query_handle -> fetchrow_array ){  
    push ( @cellLineName, $cellLineName );
  }
  my $number_of_cell_line = scalar @cellLineName;
  for ($i = 0; $i < $number_of_cell_line-1; $i++)
  {
  	print "\"$cellLineName[$i]\",\n";
  }
  print "\"$cellLineName[$i]\"];\n";
   
  print "$page_header_for_add_new_screen_sub2";
  
  print "<h2>Add new screen:</h2><p></p>";
  
  print $q -> start_multipart_form ( -method => "POST",
  									 -name => "addNewScreen",
  									 -onSubmit => "return checkForm( this )" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";
  
  ## print a message if the new plateconf has been successfully uploaded and saved to the server ##
  
  my $file_upload_message = $q -> param ( "file_upload_message" );
  
  #$file_upload_message = shift;
  if ( defined ( $file_upload_message ) ) {
    print "<div id=\"Message\"><p><b>$file_upload_message</b></p></div>";
  }

  ##
  ## add main screen info here ##
  ## 
 
  print "<p><b>General screen information:</b></p>";
  print "<p>";
 
  ## get the CTG excel file ##
  
  print "<p>Plate excel file(s):<br />";
  #print "<p>";
  
  print $q -> filefield ( -name => 'uploaded_excel_file',
                         -default => 'starting value',
                         -size => 35,
                         -maxlength => 256,
                         -id => "xls_file" );
  print "<br />";
  #print "<p>";
 
  print $q -> filefield ( -name => 'uploaded_excel_file2',
                         -default => 'starting value',
                         -size => 35,
                         -maxlength => 256,
                         -id => "xls_file2" );
  print "<br />";
  print $q -> filefield ( -name => 'uploaded_excel_file3',
                         -default => 'starting value',
                         -size => 35,
                         -maxlength => 256,
                         -id => "xls_file3" );
  print "<br />";
   
  ## get the existing platelist filenames from the database and display them in the popup menu ##
  
  $query = "SELECT Platelist_file_location FROM Platelist_file_path WHERE Platelist_file_path_ID > '18'";
  $query_handle = $dbh -> prepare ( $query );
     				#or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle->execute();
    #or die "SQL Error: " . $query_handle -> errstr();
    
  my $platelist_path;
  my $platelist_file_dest;
  my $platelist_name;
  my @platelist_path;
  
  while ( $platelist_path = $query_handle -> fetchrow_array ) {
    $platelist_file_dest = $platelist_path;
    $platelist_file_dest =~ s/.*\///;
    $platelist_name = $platelist_file_dest;
    $platelist_name =~ s{\.[^.]+$}{};
    push ( @platelist_path, $platelist_name );
  }
  #$query_handle -> finish();
  unshift ( @platelist_path, "Please select" );
  
  print "<p>Plate list file:<br />";
  
  print $q -> popup_menu ( -name => 'plate_list',
  						   -value => \@platelist_path,
   						   -default => 'Please select',
   						   -id => "plist_file" );
  
  print " - OR <br />";
  
   ## View old Platelist file ## 
  my $plate_list_download_link = $configures{'hostname'} . $configures{'platelist_folder'}; 
  print "    ";
  print "<a href=\"$plate_list_download_link\">View existing plate list files</a>";
  
  print " - OR<br />";
  
  #link to the form for adding new platelist file 
  ##### http://gft.icr.ac.uk/cgi-bin/$script_name?add_new_files=1\#add_new_platelist_file ---- does not allow navigation to add_new_plateconf_file/add_new_platelist_file/add_new_plate_library_file pages
  #print "<p>";  
  print "<a href =" . $configures{'hostname'} .  "cgi-bin/$script_name?add_new_files=1\">Add new plate list file</a>";
  print "</p>";  
  		
  ## get the existing template library filenames from the database and display them in the popup menu ##
  
  $query = "SELECT Compound_library_file_location FROM Compound_library_file_path"; 
  $query_handle = $dbh -> prepare ( $query );
   					#or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle->execute();
    #or die "SQL Error: " . $query_handle -> errstr();
  
  my $templib_path;
  my $templib_file_dest;
  my $templib_name;
  my @templib_path;
  
  while ( $templib_path = $query_handle -> fetchrow_array ) {
    $templib_file_dest = $templib_path;
    $templib_file_dest =~ s/.*\///;
    $templib_name = $templib_file_dest;
    $templib_name =~ s{\.[^.]+$}{};
    push ( @templib_path, $templib_name );
  }
 # $query_handle -> finish();
  unshift( @templib_path, "Please select" );
  
  
  print "<p>Compound library file:<br />";
  
  print $q -> popup_menu ( -name => 'template_library',
  						  -value => \@templib_path,
   						  -default => 'Please select',
   						  -id => "tlib_file" );
  
  print " - OR<br />";
  
  ## View old template library ## 
  my $template_library_download_link = $configures{'hostname'} . $configures{'templib_folder'}; 
  print "    ";
  print "<a href=\"$template_library_download_link\">View existing compound library files</a>";
  
  print " - OR<br />";
  
  #link to the form for adding new template library file
  ##### http://gft.icr.ac.uk/cgi-bin/$script_name?add_new_files=1\#add_new_plate_library_file ---- does not allow navigation to add_new_plateconf_file/add_new_platelist_file/add_new_plate_library_file pages 
  #print "<p>";  	
  print "<a href =" . $configures{'hostname'} .  "cgi-bin/$script_name?add_new_files=1\"> Add new compound library file</a>";
  print "</p>";
  print "</p>";
  
  ## get the existing plateconf filenames from the database and display them in the popup menu ##
  
  $query = "SELECT Plateconf_file_location FROM Plateconf_file_path WHERE Plateconf_file_path_ID > '37'";
  $query_handle = $dbh -> prepare( $query );
    				   #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute();
    #or die "SQL Error: ".$query_handle->errstr();
  
  my $plateconf_path;
  my $plateconf_file_dest;
  my $plateconf_name;
  my @plateconf_path;
  
  while ( $plateconf_path = $query_handle -> fetchrow_array ){
    $plateconf_file_dest = $plateconf_path;
    $plateconf_file_dest =~ s/.*\///;
    $plateconf_name = $plateconf_file_dest;
    $plateconf_name =~ s{\.[^.]+$}{};
    
    push ( @plateconf_path, $plateconf_name );
  }
  #$query_handle -> finish();
  unshift( @plateconf_path, "Please select" );
  print "<p>Plate configure file:<br />";
  
  print $q -> popup_menu ( -name => 'plate_conf',
  						  -value => \@plateconf_path,
  						  -default => 'Please select',
  						  -id => "pconf_file" );							    		  
  print " - OR<br />";
  
  ## View old Plateconf file ## 
  my $plate_conf_download_link = $configures{'hostname'} . $configures{'plateconf_folder'}; 
  print "    ";
  print "<a href=\"$plate_conf_download_link\">View existing plate configure files</a>";
  
  print " - OR<br />";
  
  #link to the form for adding new plateconf file 
  ##### http://gft.icr.ac.uk/cgi-bin/$script_name?add_new_files=1\#add_new_plateconf_file ---- does not allow navigation to add_new_plateconf_file/add_new_platelist_file/add_new_plate_library_file pages
  #print "<p>";
  print "<a href =" . $configures{'hostname'} . "cgi-bin/$script_name?add_new_files=1\"> Add new plate configure file</a>";
  print "</p>";
  
  ## Enter information to store in the Description.txt file ##

  print "<p>";
  print "Notes about this screen:<br />";
  print $q -> textarea ( -name => "notes",
                         -default => 'write notes for Description.txt',
                         -rows => "8",
                         -columns => "40",
                         -onClick => "make_notes_Blank()",
                         -id => "NoteS" );
  print "</p>"; 
  
  print "</td>\n";
  
  print "<td align=left valign=top>\n"; 
  print "<p><b>&nbsp&nbsp&nbsp&nbsp&nbsp</b></p>";
  print "</td>\n";
  
  print "<td align=left valign=top>\n"; 
  print "<p><b>&nbsp&nbsp&nbsp&nbsp&nbsp</b></p>";
  
  print "Cell line name:<br />";
  print $q -> textfield ( -name => "cell_line_name",
                          -value => 'Enter cell line name',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_cellLines_Blank()",
                          -id => "celllines" );
  print "</p><p>";
  
  print "Tissue of origin:<br />";
  print $q -> textfield ( -name => "tissue_type",
                          -value => 'Enter tissue type',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_tissues_Blank()",
                          -id => "tissues" );
  print "</p><p>";
   
  ## get the current date ##
  
  my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime ( time );
  $year += 1900;
  $mon ++;
  my $date = sprintf ( "%04u-%02u-%02u",$year,$mon,$mday ); # set this to current date using localtime()
  print "</p><p>";
  print "Date of screen:<br />";
  print $q -> textfield ( -name => "date_of_run",
                          -value => $date,
                          -size => "30",
                          -maxlength => "45" );
  print "</p><p>";
  
  ## get the user (who is logged in?) ##
  
  print "Operator:<br />";
  print $q -> textfield ( -name => "operator",
                          -value => $user,
                          -size => "30",
                          -maxlength => "45",
                          -id => "OperatoR");
                          
  print "</p><p>";
                    
  ## get number of cell per well ##
                          
  print "No. of cells per well:<br />";
  print $q -> textfield ( -name => "cells_per_well",
                          -value => 'Enter cell number',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_cellsPerWell_Blank()",
                          -id => "CellsperwelL");
                          
  print "</p><p>";
                          
  ## get the collaborator ##
  
  print "Collaborator's name:<br />";
  print $q -> textfield ( -name => "collaborator",
                          -value => 'Optional',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_collab_Blank()",
                          -id => "CollaboratoR");
                          
  ## get the instrument name from the database ##
  
  print "</p><p>Instrument:<br />";
  
  my @instrument = ( "Please select", "1S10", "1C11", "VictorX" ); 
  print $q -> popup_menu ( -name => 'instrument',
  					       -value => \@instrument,
  						   -default => 'Please select',
  						   -id => "InstrumenT" );
  print "</p>";
  
   print "</p><p>";
                          
  ## get the length of assay ##
  
  print "Length of assay:<br />";
  print $q -> textfield ( -name => "length_of_assay",
                          -value => 'Enter length of assay',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_lengthOfAssay_Blank()",
                          -id => "LengthofassaY");

  print "<p>&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</p>";
                          
  print "<p><b>Analyse and save results:</b><br />";
  print "<input type=\"submit\" id=\"save_new_screen\" value=\"Analyse and save results\" name=\"save_new_screen\" />";
  print "</p>";

  print "</td>\n";

  # ======================
  # add isogenic info here
  # ======================
  print "<td align=left valign=top>\n"; 
  print "<p><b>&nbsp&nbsp&nbsp&nbsp&nbsp</b></p>";
  print "</td>\n";
  
  print "<td align=left valign=top>\n";
  
  print "<p><b>Isogenic screens:</b></p>";

  ## checkbox for isogenic screen ##

  print "<p>";
  
  print $q -> checkbox( -name=>'is_isogenic',
    					-checked=>0,
    					-onclick=>"enableText()",
   					    -value=>'ON',
    					-label=>'this is an isogenic screen' );

  print "</p><p>";
  
  ## enter modified gene name ##
  
  print "Modified gene name:<br />";
  print $q -> textfield ( -name => "gene_name_if_isogenic",
                          -value => 'Enter gene name',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_geneName_Blank()",
                          -id => "geneName",
                          -disabled );
  
  print "</p><p>";
   
 ## get the existing isogenic sets from the database and display them in the popup menu ##
 
# $ISOGENIC_SET = $dbh -> selectcol_arrayref ( "SELECT Name_of_set_if_isogenic FROM Name_of_set_if_isogenic WHERE Name_of_set_if_isogenic != 'NA'" )
#                   or die "Cannot prepare: " . $dbh->errstr();
# unshift( $ISOGENIC_SET, "Please select" );
 
#  print "<p>";

#  print "<p>Select isogenic set:<br />";
    
#  print $q -> popup_menu (-name =>'isogenicSet',
#  						  -value => $ISOGENIC_SET,
#  	                      -default =>'Please select',
#   	                      -disabled );

#  print " - OR";
#  print "<p>";
#  print "</p>";  
  
  ## enter isogenic set name ##
  
#  print "Enter isogenic set:<br />";
#  print $q -> textfield ( -name => "name_of_set_if_isogenic",
#                          -value => 'Enter isogenic set name',                         
 #                         -size => "30",
 #                         -maxlength => "45",
 #                         -onClick => "make_isogenic_Set_Blank()",
 #                         -id => "isogenic_Set",
 #                         -disabled );
                          
 # print "</p><p>";
   
  ## get isogenic mutant description ##
  
  print "Isogenic description:<br />";
  print $q -> textfield ( -name => "isogenic_mutant_description",
                          -value => 'e.g. parental',
                          -size => "30",
                          -maxlength => "45", 
                          -onClick => "make_isogenicDescription_Blank()",
                          -id => "isogenicDescription",
                          -disabled );
  
  print "</p><p>";  
  
  ## get method of isogenic knockout ##
  
  print "Method of isogenic mutation:<br />";
  print $q -> textfield ( -name => "method_of_isogenic_knockdown",
                          -value => 'e.g. CRISPR or shRNA',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_isogenicKnockdown_Blank()",
                          -id => "isogenicKnockdown",
                          -disabled );
   
  print "</p><p>";
  print "</td>\n";                        
  
  # =========================
  # add drug screen info here
  # =========================

  print "<td align=left valign=top>\n"; 
  print "<p><b>&nbsp&nbsp&nbsp&nbsp&nbsp</b></p>";
  print "</td>\n";
  
  print "<td align=left valign=top>\n";
  
  print "<p><b>Drug Arm:</b></p>";

  ## checkbox for drug screen ##

  print "<p>";
  
  print $q -> checkbox( -name=>'is_drug_screen',
    					-checked=>0,
    					-onclick=>"enableText_DS()",
   					    -value=>'ON',
    					-label=>'this is a drug screen' );

  print "</p><p>";
  
  ##  select control from dropdown menu ##
  
  #print "<p>";
  
  #my @CONTROL = ( "Please select", "DMSO", "DNS" ); # this should be read from a text file or from the SQL database
  #print "Control:<br />";
  #print $q -> popup_menu( -name => 'Control',
  #					      -value => \@CONTROL,
  #						  -default => 'Please select' );
  #print "</p>";
  
  ## çompound used ##
  
  print "<p>";
  
  print "Compound:<br />";
  print $q -> textfield ( -name => "compound",
                          -value => 'e.g. cisplatin',
                          -size => "30",
                          -maxlength => "45",
                          -id => "CompounD",
                          -onClick => "make_compound_Blank()",
                          -disabled );
  
  print "</p>";
                          
  ## concentration ##
  
  print "<p>";
  
  print "Concentration:<br />";
  print $q -> textfield ( -name => "concentration",
                          -value => 'e.g. 100 ng',
                          -size => "30",
                          -maxlength => "45",
                          -id => "ConcentratioN",
                          -onClick => "make_concentration_Blank()",
                          -disabled ); 
                          
  print "</p>";
  
  ## dosing regime ##
  
  print "<p>";
  
  print "Dosing regime:<br />";
  print $q -> textfield ( -name => "dosing_regime",
                          -value => 'e.g. 24 hrs after transfection',
                          -size => "30",
                          -maxlength => "45",
                          -id => "dosingRegime",
                          -onClick => "make_dosingregime_Blank()",
                          -disabled ); 
    
  print "</p>";                       
                                                            
  ## put notes text field for drug screen ##

 #print "<td align=left valign=centre>\n";
  
  print "<p></p>";
  print "</p></p>";
  #print "Notes about the drug screen:<br />";
  #print $q -> textarea ( -name => "drug_screen_notes",
  #                      -default => 'write notes for drug screen',
  #                       -rows => "8",
  #                       -columns => "40" );                              
  print "</td>\n";
                    
  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html;
                                                                          
} #end of add_new_screen subroutine


  # =================================================================================
  # Subroutine for downloading/uploading new plateconf/platelist/library files
  # =================================================================================

sub add_new_files {
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Add new file(s):</h1>";

  ## Downloading/uploading platelist file ## 
  
  print $q -> start_multipart_form ( -method => "POST" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<a name=\"new_plate_list_file\"><p><b>Upload new plate list file:</b>";
  print " - OR  ";
 
  ## download old Platelist file ##
 
  my $plate_list_download_link = $configures{'hostname'} . $configures{'platelist_folder'};

  #print "<p><div id=\"Note\">NOTE: For downloading existing platelist files, click on the link below.</div></p>";
  
  #print "<p>";
  print "<a href=\"$plate_list_download_link\">View existing plate list files</a>";
  print "</p>";
  
  ## get new platelist file ##
  
  #print "<p>Upload new platelist file:<br />";
  #print "<p></p>";
  
  print $q -> filefield ( -name=>"new_uploaded_platelist_file",
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256 );
  print "</p>";
  
  ## enter new platelist file name ##
  
  #print "<p>Enter new platelist file name:<br />";
  #print "<p></p>";
   
  #print $q -> textfield ( -name => "new_platelist_filename",
  #                        -value => 'e.g. platelist_p9_v2',
  #                       -size => "30",
  #                        -maxlength => "45" ); 
  #print "<p></p>";
  
  #print"<p><div id=\"Note\">NOTE: The name of the new uploaded plate list file should be different from the names of existing platelist files. The words in the filename must be joined with an underscore ( _ ).</div></p>";
  
  ## create a hidden field ##
  #hidden fields pass information along with the user-entered input that is not to be manipulated by the user-a way to have web forms to remember previous information 
  
  print $q -> hidden ( -name=>'save_new_uploaded_platelist_file',
  					   -default=>'save_new_uploaded_platelist_file' );
  
  ## submit newly uploaded plateconf file ##
  
  print "<p>";
  print "<input type=\"submit\" id=\"save_new_uploaded_platelist_file\" value=\"Save the uploaded plate list file\" name=\"save_new_uploaded_platelist_file\" />";
  print "</p>";
  
  print "</td>\n";
  print "</tr>\n";
  print $q -> end_multipart_form(); 
  
  ## Downloading/uploading template library file ## 
  
  print $q -> start_multipart_form(-method=>"POST"); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<a name=\"new_plate_library_file\"><p><b>Upload new compound library file:</b>";
  print " - OR  ";
 
  ## download old template library file ##
 
  my $library_download_link = $configures{'hostname'} . $configures{'templib_folder'};
  
  #print "<p><div id=\"Note\">NOTE: For downloading the library file for editing, right click on the relevant link below and select the 'Save Link As...' option for saving the file on your computer.</div></p>";
  
  #print "<p>";
  print "<a href=\"$library_download_link\">View existing compound library files</a>";
  print "</p>";
  
  ## get new template library file ##
  		  
  #print "<p>Upload new template library file:<br />";
  #print "<p></p>";
    
  print $q -> filefield( -name=>'new_uploaded_templib_file',
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256 );
  print "</p>";
    
  #enter new template library file name
  #print "<p>Enter new template library file name:<br />";
  #print "<p></p>";

  #print $q -> textfield ( -name => "new_templib_filename",
  #                        -value => 'e.g. KS_TS_CGC_WNT_384_template', 
  #                        -size => "30",
  #                        -maxlength => "45" );  
  #print "<p></p>";
  
  #print"<p><div id=\"Note\">NOTE: The name of the new uploaded library file should be different from the names of the existing library files. The words in the filename must be joined with an underscore ( _ ).</div></p>";
  
  ## create a hidden field ##
  #hidden fields pass information along with the user-entered input that is not to be manipulated by the user-a way to have web forms to remember previous information 
  
  print $q -> hidden ( -name=>'save_new_uploaded_templib_file',
  					   -default=>'save_new_uploaded_templib_file' );

  ## submit newly uploaded template library file ##
  
  print "<p>";
  print "<input type=\"submit\" id=\"save_new_uploaded_templib_file\" value=\"Save the uploaded compound library file\" name=\"save_new_uploaded_templib_file\" />";
  print "</p>";
  
  print "<tr colspan=2>\n";
  print "<td align=left valign=top>\n";

  print "</td>\n";
  print "</tr>\n";
  print $q -> end_multipart_form();
  
    ## Downloading/uploading plateconf file ##
  
  print $q -> start_multipart_form ( -method => "POST" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<a name=\"new_plate_conf_file\"><p><b>Upload new plate configure file:</b>";
  #print "<p>";
 
  ## download old Plateconf file ##
 
  my $plate_conf_download_link = $configures{'hostname'} . $configures{'plateconf_folder'};
  
  #print "<div id=\"Note\"><p>NOTE: For downloading existing plateconf files, click on the link below.</p></div>";
  print " - OR  ";
  #print "<p>";
  print "<a href=\"$plate_conf_download_link\">View existing plate configure files</a>";
  print "</p>";
  
  ## get new Plateconf file ##
  
  #print "<p>Upload new plateconf file:<br />";
  #print "<p></p>";
  
  print $q -> filefield ( -name=>'new_uploaded_plateconf_file',
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256 );
  print "</p>";
  
  ## enter new plateconf file name ##
  
  #print "<p>Enter new plateconf file name:<br />";
  #print "<p></p>";
  
  #print $q -> textfield ( -name => "new_plateconf_filename",
  #                        -value => 'e.g. KS_TS_CGC_WNT_384_plateconf',
  #                        -size => "30",
  #                        -maxlength => "45" );

  #print "<p></p>";
  
  #print"<p><div id=\"Note\">NOTE: The name of the new uploaded plate configure file should be different from the names of existing plate conf files. The words in the filename must be joined with an underscore ( _ ).</div></p>";
  
  ## create a hidden field ##
  #hidden fields pass information along with the user-entered input that is not to be manipulated by the user ## a way to have web forms to remember previous information 
  
  print $q -> hidden ( -name=>'save_new_uploaded_plateconf_file',
  					   -default=>'save_new_uploaded_plateconf_file' );
  
  ## submit the form for uploading plateconf file ##
  
  print "<p>";
  print "<input type=\"submit\" id=\"save_new_uploaded_plateconf_file\" value=\"Save the uploaded plate configure file\" name=\"save_new_uploaded_plateconf_file\" />";
  print "</p>";
  
  print "</td>\n";
  print "</tr>\n";
  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html; 
  
} #end of add_new_files subroutine


# ================================
# Subroutine for saving new screen
# ================================

sub save_new_screen {
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Saving new screen data:</h1>";

  $ISOGENIC_SET = $q -> param( "isogenicSet" );
  my $tissue_type = $q -> param( "tissue_type" );
  my $cell_line_name = $q -> param( "cell_line_name" );
  my $date_of_run = $q -> param( "date_of_run" );
  my $operator = $q -> param( "operator" );
  my $collaborator = $q -> param( "collaborator" );
  my $cells_per_well = $q -> param( "cells_per_well" );
  my $length_of_assay = $q -> param( "length_of_assay" );
  my $instrument = $q -> param( "instrument" );
  my $is_isogenic = $q -> param( "is_isogenic" );
  my $is_drug_screen = $q -> param ( "is_drug_screen" );
  my $gene_name_if_isogenic = $q -> param( "gene_name_if_isogenic" );
  my $isogenic_mutant_description = $q -> param( "isogenic_mutant_description" );
  my $method_of_isogenic_knockdown = $q -> param( "method_of_isogenic_knockdown" );
  my $compound = $q -> param( "compound" );
  my $compound_concentration = $q -> param( "concentration" );
  my $dosing_regime = $q -> param( "dosing_regime" );
  my $notes = $q -> param( "notes" );
#  my $sicon1 = $q -> param( "sicon1_empty" );
#  my $sicon2 = $q -> param( "sicon2_empty" );
#  my $allstar = $q -> param( "allstar_empty" );
  my $xls_files;
  
  ##################Check cell line name and tissue of origin
  	$tissue_type = uc $tissue_type;
  	$cell_line_name = uc $cell_line_name;
  	$tissue_type =~ s/^\s+//g;
	$tissue_type =~ s/[^A-Z0-9_]*//g;
	$cell_line_name =~ s/^\s+//g;
	$cell_line_name =~ s/[^A-Z0-9]*//g;
		  		
	my $query = "SELECT Tissue_type_Tissue_type_ID FROM Cell_line where Cell_line_name = '$cell_line_name'";
	my $query_handle = $dbh -> prepare ( $query );
	$query_handle->execute();
	my $tissue_type_tissue_type_id = $query_handle -> fetchrow_array;
	if (defined ($tissue_type_tissue_type_id))
	{	
		$query = "SELECT Tissue_of_origin FROM Tissue_type where Tissue_type_ID = $tissue_type_tissue_type_id";
		$query_handle = $dbh -> prepare ( $query );
		$query_handle->execute();
		my $tissue_type_in_data_base = $query_handle -> fetchrow_array;

		if ($tissue_type ne $tissue_type_in_data_base)
		{
			my $message = "Error: The tissue of origin you entered for cell line $cell_line_name was $tissue_type. It is $tissue_type_in_data_base in the database. Please check!";
			print "<div id=\"Message\"><p><b>$message</b></p></div>";  
			print "$page_footer";
			print $q -> end_html;
			return;
		}
	} else
	{
        $query = "select Tissue_type_ID from Tissue_type where Tissue_of_origin = '$tissue_type'";
        $query_handle = $dbh -> prepare ( $query );
		$query_handle->execute();
		my $tissue_type_id = $query_handle -> fetchrow_array;
        if (!defined ($tissue_type_id))
        {
			$query = "INSERT into Tissue_type (Tissue_of_origin) values ('$tissue_type')";
			$query_handle = $dbh -> prepare ( $query );
			$query_handle->execute();
			$query = "select Tissue_type_ID from Tissue_type where Tissue_of_origin = '$tissue_type'";
        	$query_handle = $dbh -> prepare ( $query );
			$query_handle->execute();
			$tissue_type_id = $query_handle -> fetchrow_array;
        }
		
		$query = "INSERT into Cell_line (Cell_line_name, Tissue_type_Tissue_type_ID) values ('$cell_line_name', '$tissue_type_id')";
		$query_handle = $dbh -> prepare ( $query );
		$query_handle->execute();
		my $message = "New cell line and corresponding tissue of origin have been added to the database.";
		print "<div id=\"Message\"><p><b>$message</b></p></div>";
	}
  
  ################################################[[[get params to check the previous page is working as expected]]]
  
  ################################################[[[my $tmp_file_path = "/home/agulati/data/tmp_file";]]]

  ## match plateconf name, selected from the drop down menu, to the file and store it in a variable ##
  
  my $plateconf = $q -> param( "plate_conf" );
  my $plateconf_file_path;
  my $plateconf_target;
  
  ## match platelist name, selected from the drop down menu, to the file and store it in a variable ##   
      
  my $platelist = $q -> param( "plate_list" );
  my $platelist_file_path;
  my $platelist_target;
  my $platelist_tmp_file;
  my $platelist_prefix;

  ## match templib name, selected from the drop down menu, to the file and store it in a variable ##

  my $templib = $q -> param( "template_library" );
  my $templib_file_path;
  my $templib_target;
  
  ## New screen directory - name and location ##
  
  my $screen_dir_name = $q -> param( "screen_dir_name" );
  my $screenDescription_filename;

  $gene_name_if_isogenic =~ s/\s+//g; 
  $gene_name_if_isogenic =~ s/\//-/g;
   
  $isogenic_mutant_description =~ s/\s+//g;
  $isogenic_mutant_description =~ s/\//-/g;
  
  $method_of_isogenic_knockdown =~ s/\s+//g;
  $method_of_isogenic_knockdown =~ s/\//-/g;
  
  if ( $collaborator eq "Optional" || $collaborator eq "" ) {
    $collaborator = "NA";
  }
  if ( $dosing_regime eq "e.g. 24 hrs after transfection" || $dosing_regime eq "" ) {
    $dosing_regime = "NA";
  }
  
  $compound =~ s/\s+//g;
  $compound =~ s/\//-/g;
  $compound = uc($compound);
  
  if ( $compound_concentration eq "e.g. 100 ng" || $compound_concentration eq "" ) {
    $compound_concentration = "";
  }

  $compound_concentration =~ s/[^A-Za-z0-9_-\d.]*//g;
  
  $isogenic_mutant_description =~ s/\s+//g;
  
  my $guide_file;
  
    if ( not defined ($screen_dir_name)) {
   
      $screen_dir_name = $tissue_type ."_". $cell_line_name ."_". $date_of_run . "_" . $templib . "_sA";
    
    if ( ($is_isogenic eq 'ON') & ($is_drug_screen ne 'ON') )
    {
    	$screen_dir_name = "IS" . "_" . $tissue_type . "_" . $cell_line_name . "_" . $gene_name_if_isogenic . "_" . $isogenic_mutant_description . "_" . $date_of_run . "_" . $templib . "_sA";
    }
    if (($is_isogenic ne 'ON') & ($is_drug_screen eq 'ON') & (defined($compound_concentration)))
    {
    	$screen_dir_name = $tissue_type . "_" . $cell_line_name . "_" . $compound . "_" . $compound_concentration . "_" . $date_of_run . "_" . $templib . "_dA";
    }
    if (($is_isogenic eq 'ON') & ($is_drug_screen eq 'ON') & (defined($compound_concentration)))
    {
    	$screen_dir_name = "IS" . "_" . $tissue_type . "_" . $cell_line_name . "_" . $gene_name_if_isogenic . "_" . $isogenic_mutant_description . "_" . $compound . "_" . $compound_concentration . "_" . $date_of_run . "_" . $templib . "_dA";
    }
    if (($is_isogenic ne 'ON') & ($is_drug_screen eq 'ON') & (not defined($compound_concentration)))
    {
    	$screen_dir_name = $tissue_type . "_" . $cell_line_name . "_" . $compound . "_" . $date_of_run . "_" . $templib . "_dA";
    }
     if (($is_isogenic eq 'ON') & ($is_drug_screen eq 'ON') & (not defined($compound_concentration)))
    {
    	$screen_dir_name = "IS" . "_" . $tissue_type . "_" . $cell_line_name . "_" . $gene_name_if_isogenic . "_" . $isogenic_mutant_description . "_" . $compound . "_" . $date_of_run . "_" . $templib . "_dA";
    }
  }

  my $screenDir_path = $configures{'screenDir_path'};
  my $file_path = "$screenDir_path/$screen_dir_name";

  if ( -e $file_path ) {
 	my $message = "A screen with the same name already exists. Cannot make new RNAi screen directory $screen_dir_name in $screenDir_path";
 	print "<div id=\"Message\"><p><b>$message</b></p></div>";
 	die "Cannot make new RNAi screen directory $screen_dir_name in $screenDir_path: $!";
 	return;
  }
  
  if ( ! -e $file_path ) {
    mkdir( "$file_path" );
    `chmod -R 777 $file_path`;
    `chown -R agulati:agulati $file_path`;
      
    print "<p><div id=\"Note\">Created new screen directory...</div></p>";
    
    ## add screen directory name as prefix to all the filenames in the selected platelist file ##

    $plateconf_file_path = $configures{'WebDocumentRoot'} . $configures{'plateconf_folder'}.$plateconf.".txt";
    $plateconf_target = $file_path."/".$plateconf.".txt";
    copy $plateconf_file_path, $plateconf_target;
    
    #print "<p><div id=\"Note\">Selected plateconf file saved in the new screen directory...</div></p>";  
  
    ## match platelist name, selected from the drop down menu, to the file and store it in a variable ##   
      
    $platelist_file_path = $configures{'WebDocumentRoot'} . $configures{'platelist_folder'}.$platelist.".txt";
    $platelist_target = $file_path."/".$platelist.".txt";
    copy $platelist_file_path, $platelist_target;
   # $platelist_tmp_file = $file_path."/tmp_platelist_file.txt";
    
    #print "<p><div id=\"Note\">Selected platelist file saved in the new screen directory...</div></p>";  
  
   # $platelist_prefix = $screen_dir_name."_";
  
   # open IN, "< $platelist_target"
   #   or die "Cannot open $platelist_target:$!\n";
   # open OUT, "> $platelist_tmp_file"
   #   or die "Cannot open $platelist_tmp_file:$!\n";
   # while (<IN>) {
   #   if ($_ =~ /^Filename/) {
   #     print OUT $_;
    #  }
    #  else{
    #    print OUT $platelist_prefix.$_;
    #  }
   # }
   # close IN;
   # close OUT; 
   # move $platelist_tmp_file, $platelist_target;
    
    ## match templib name, selected from the drop down menu, to the file and store it in a variable ##

    $templib_file_path = $configures{'WebDocumentRoot'} . $configures{'templib_folder'}.$templib.".txt";
    $templib_target = $file_path."/".$templib.".txt"; 
    copy $templib_file_path, $templib_target; 
    
    #print "<p><div id=\"Note\">Selected template library file saved in the new screen directory...</div></p>";  
  
  ############################################[[[probably need to copy $temp_file_path somewhere safe and give it to an R script to convert]]]
  
    ## Upload excel file and save it to new screen directory ##
    foreach my $excel_filefield ('uploaded_excel_file', 'uploaded_excel_file2', 'uploaded_excel_file3')
    { 
    	my $lightweight_fh  = $q -> upload ( $excel_filefield );	
		my $tmpfile = $file_path . "/tmpfile.xls";
    	
    	# undef may be returned if it's not a valid file handle  
    	if ( defined $lightweight_fh ) 
    	{
    		my $excelFile = $q->param( $excel_filefield );
    		if ( !($excelFile =~ /xls$/) ){
				print "<div id=\"Message\"><p>ERROR: You uploaded $excelFile. Please upload a valid excel file.</p></div>";
				rmtree $file_path;
				return;
			}
		
    		# Upgrade the handle to one compatible with IO::Handle:
      		my $io_handle = $lightweight_fh->handle;
 			my $fh = undef;
      		open ( $fh, '>', $tmpfile )
        		or die "Cannot upload $excelFile:$!\n";
      
      		my $bytesread = undef;
      		my $buffer = undef;
    
      		while ( $bytesread = $io_handle -> read ( $buffer,1024 ) ) 
      		{
        		print $fh $buffer
          		or die "Error writing '$tmpfile' : $!";
      		}
      		close $fh
        		or die "Error writing '$tmpfile' : $!";
        		 
      		## rename uploaded excel file ##
      		my $new_excel_filename_wo_spaces = $excelFile;
    		$new_excel_filename_wo_spaces =~ s/\s+/_/g;
    		my $target = $file_path . "/". $new_excel_filename_wo_spaces;
      		move ($tmpfile, $target) or die "Cannot rename $tmpfile :$!";
      		if (!defined($xls_files))
      		{
      			$xls_files = $new_excel_filename_wo_spaces;
      		}
      		else
      		{
      			$xls_files = $xls_files . " " . $new_excel_filename_wo_spaces;
      		}
    	}
    }
    
    #print "<p>";
    #print "<p><div id=\"Note\">Renamed excel file(s) saved in the screen directory...</div></p>";
    #print "</p>"; 
    
  ###############################################[[[either copy the platelist/palteconf/library etc to the new screen folder or use symlinks to point to the templates]]]
  
    ## write $notes to a 'Description.txt' file ##
  
    my $descripFile = $file_path."/".$screen_dir_name."_Description.txt";
    open NOTES, "> $descripFile" 
      or die "Cannot write notes to $descripFile:$!\n";
    if (($notes eq "write notes for Description.txt") || ($notes eq "")){
      $notes = "$screen_dir_name\n$operator\t$date_of_run";
    }
    print NOTES $notes;
    $screenDescription_filename = $screen_dir_name."_Description.txt";
    close NOTES;
    
    #print "<p><div id=\"Note\">Created 'Description.txt' file in the new screen directory...</div></p>";  
  
    ## Add new screen info to Guide file ##
  
    $guide_file = $screen_dir_name."_guide_file.txt";
  
    open GUIDEFILE, '>', $file_path."/".$guide_file 
      or die "Cannot open $file_path:$!\n";
    
    print GUIDEFILE 
      "Cell_line\t", 
      "Datapath\t", 
      "Compound_library_file\t", 
      "Platelist_file\t", 
      "Plateconf_file\t", 
      "Descrip_file\t", 
      "report_html1\t", 
      "report_html2\t", 
      "zscore_file\t",
      "pocscore_file\t", 
      "summary_file1\t", 
      "summary_file2\t", 
      "summary_file_with_rep_zscores\t", 
      "summary_file_with_rep_pocscores\t", 
      "zprime_file\t", 
      "reportdir_file1\t", 
      "reportdir_file2\t", 
      "xls_file\t", 
      "qc_file\t", 
      "plot_1_file\t", 
      "plot_2_file\t",
      "plot_3_file\t",
      "corr_file\t",
      "separate_zprime_file\t",
      "drc_file\t",
      "drc_figures\n"; 
  
    print GUIDEFILE 
      "$cell_line_name\t", 
      "$file_path\t", 
      "$templib_target\t", 
      "$platelist_target\t", 
      "$plateconf_target\t", 
      "$screenDescription_filename\t", 
      "TRUE\t", 
      "TRUE\t", 
      "$screen_dir_name"."_zscores.txt\t", 
      "$screen_dir_name"."_pocscores.txt\t",
      "$screen_dir_name"."_zscores_summary.txt\t",
      "$screen_dir_name"."_pocscores_summary.txt\t", 
      "$screen_dir_name"."_zscores_summary_with_rep_zscores.txt\t",
      "$screen_dir_name"."_pocscores_summary_with_rep_pocscores.txt\t", 
      "$screen_dir_name"."_zprime.txt\t", 
      "$screen_dir_name"."_zscores_reportdir\t", 
      "$screen_dir_name"."_pocscores_reportdir\t", 
      "$xls_files\t", 
      "$screen_dir_name"."_controls_qc.png\t",
      "$screen_dir_name"."_qc_plot_file_1.png\t",
      "$screen_dir_name"."_qc_plot_file_2.png\t",
      "$screen_dir_name"."_qc_plot_file_3.png\t", 
      "$screen_dir_name"."_corr.txt\t",
      "$screen_dir_name"."_separate_zprime.txt\t",
      "$screen_dir_name"."_pocscores_drugresponse.txt\t",
      "$screen_dir_name"."_pocscore_figures.pdf\n";  
      
    print "<p><div id=\"Note\">Analysing...</div></p>"; 
    
    close (GUIDEFILE);
    
  }
  my $guide = $guide_file;
  
  ##  run RNAi screen analysis scripts by calling R ##  
  
  my $run_analysis_scripts = `cd $file_path && R --vanilla < $configures{'run_analysis_script'}`;
   
  ####[[[Alternatively :- my $run_analysis_scripts = system("R --vanilla < /home/agulati/scripts/run_analysis_script.R"); ####]]]

  ## rename index.html file and copy it to the /var/www/html/RNAi_screen_analysis_report_folders ##

  my $rnai_screen_z_report_original_path = $file_path."/".$screen_dir_name."_zscores_reportdir";
  my $rnai_screen_z_report_original_file = $rnai_screen_z_report_original_path."/"."index.html";
  
  my $rnai_screen_poc_report_original_path = $file_path."/".$screen_dir_name."_pocscores_reportdir";
  my $rnai_screen_poc_report_original_file = $rnai_screen_poc_report_original_path."/"."index.html";
  
  my $rnai_screen_z_report_renamed_file = $rnai_screen_z_report_original_path."/".$screen_dir_name."_index.html";
  `cp $rnai_screen_z_report_original_file $rnai_screen_z_report_renamed_file`;
  
   my $rnai_screen_poc_report_renamed_file = $rnai_screen_poc_report_original_path."/".$screen_dir_name."_index.html";
  `cp $rnai_screen_poc_report_original_file $rnai_screen_poc_report_renamed_file`;
  
  my $rnai_screen_z_report_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_report_new_path'};
  `cp -r $rnai_screen_z_report_original_path $rnai_screen_z_report_new_path`;
  
  my $rnai_screen_poc_report_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_report_new_path'};
  `cp -r $rnai_screen_poc_report_original_path $rnai_screen_poc_report_new_path`;
  
  ## Display the link to screen analysis report on the save new screen page ##
  
  my $rnai_screen_link_to_z_report = $configures{'hostname'} . $configures{'rnai_screen_report_new_path'} . $screen_dir_name."_zscores_reportdir/";
  
  my $rnai_screen_link_to_poc_report = $configures{'hostname'} . $configures{'rnai_screen_report_new_path'} . $screen_dir_name."_pocscores_reportdir/";
 
  ## copy the file with rep1 vs rep2 scatter plots to the /usr/local/www/html/RNAi_screen_analysis_qc_plots ##
  
  my $scatter_plot_1_original_path = $file_path."/".$screen_dir_name."_qc_plot_file_1.png"; 
  my $rnai_screen_qc_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_qc_new_path'};
  `cp -r $scatter_plot_1_original_path $rnai_screen_qc_new_path`;
  
  ## copy the file with rep2 vs rep3 scatter plots to the /usr/local/www/html/RNAi_screen_analysis_qc_plots ##
  
  my $scatter_plot_2_original_path = $file_path."/".$screen_dir_name."_qc_plot_file_2.png"; 
  $rnai_screen_qc_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_qc_new_path'};
  `cp -r $scatter_plot_2_original_path $rnai_screen_qc_new_path`;
  
  ## copy the file with rep1 vs rep3 scatter plots to the /usr/local/www/html/RNAi_screen_analysis_qc_plots ##
  
  my $scatter_plot_3_original_path = $file_path."/".$screen_dir_name."_qc_plot_file_3.png"; 
  $rnai_screen_qc_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_qc_new_path'};
  `cp -r $scatter_plot_3_original_path $rnai_screen_qc_new_path`;
  
  ## copy the file with correlation coefficients for the reps to the /usr/local/www/html/RNAi_screen_analysis_correlation_folder ##
  
  my $rnai_screen_corr_original_path = $file_path."/".$screen_dir_name."_corr.txt"; 		
  my $rnai_screen_corr_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_corr_new_path'}; 		
  `cp -r $rnai_screen_corr_original_path $rnai_screen_corr_new_path`;
  
  my $drc_figs_original_path = $file_path."/".$screen_dir_name."_pocscore_figures.pdf"; 		
  my $drc_figs_new_path = $configures{'WebDocumentRoot'} . $configures{'drug_screen_drc_figs_new_path'}; 		
  `cp -r $drc_figs_original_path $drc_figs_new_path`;
  
  my $drc_file_original_path = $file_path."/".$screen_dir_name."_pocscores_drugresponse.txt"; 		
  my $drc_file_new_path = $configures{'WebDocumentRoot'} . $configures{'drug_screen_drc_figs_new_path'}; 		
  `cp -r $drc_file_original_path $drc_file_new_path`;
  
  my $rep_zscores_file_original_path = $file_path."/".$screen_dir_name."_zscores_summary_with_rep_zscores.txt"; 		
  my $rep_zscores_file_new_path = $configures{'WebDocumentRoot'} . $configures{'reps_summary'}; 		
  `cp -r $rep_zscores_file_original_path $rep_zscores_file_new_path`;

  my $rep_pocscores_file_original_path = $file_path."/".$screen_dir_name."_pocscores_summary.txt"; 		
  my $rep_pocscores_file_new_path = $configures{'WebDocumentRoot'} . $configures{'reps_summary'}; 		
  `cp -r $rep_pocscores_file_original_path $rep_pocscores_file_new_path`;
  
  my $rnai_screen_link_to_qc_plots = "NA";
  
  my $drug_screen_link_to_drc_plots = $configures{'hostname'} . $configures{'drug_screen_drc_figs_new_path'} . $screen_dir_name . "_pocscore_figures.pdf";
  my $drug_screen_link_to_drc_file = $configures{'hostname'} . $configures{'drug_screen_drc_figs_new_path'} . $screen_dir_name . "_pocscores_drugresponse.txt";
  
  my $drug_screen_link_to_rep_zscores = $configures{'hostname'} . $configures{'reps_summary'} . $screen_dir_name . "_zscores_summary_with_rep_zscores.txt";
  my $drug_screen_link_to_rep_pocscores = $configures{'hostname'} . $configures{'reps_summary'} . $screen_dir_name . "_pocscores_summary.txt";
  
  
  ## 2. Store new isogenic set entered by the user into the database ##
  
  #first check if the screen is isogenic and then check if the user hasn't selected a set from the drop down menu
  
  my $is_isogenic_screen;
  
  if ($is_isogenic eq 'ON') {
    $is_isogenic_screen = "Yes";
  }
  else {
    $is_isogenic_screen = "No";
    $gene_name_if_isogenic = "";
    $isogenic_mutant_description = "";
    $method_of_isogenic_knockdown = "";
  }
  
  if ($is_drug_screen eq 'ON')
  {
  	$is_drug_screen = "True";
  }
  else
  {
  	$is_drug_screen = "False";
  	$compound = "";
	$compound_concentration = "";
	$dosing_regime = "";
  }
  
  ## Add screen metadata to Guide file ##
  
    my $info_file = $screen_dir_name."_screen_details.txt";
  
    open INFOFILE, '>', $file_path."/".$info_file 
      or die "Cannot open $file_path:$!\n";
    
    print INFOFILE 
      "SCREEN DETAILS:\n\n",
	  "Drug_screen_name:  $screen_dir_name\n",
	  "Tissue_of_origin:  $tissue_type\n",
	  "Cell_line:  $cell_line_name\n",
	  "Date_of_run:  $date_of_run\n",
	  "Operator:  $operator\n",
	  "Collaborator:  $collaborator\n",
	  "Cells_per_well:  $cells_per_well\n",
	  "Length_of_assay:  $length_of_assay\n",
	  "Instrument_name:  $instrument\n",
	  "Compound_library_name:  $templib\n",
	  "Plate_list_file_name:  $platelist\n",
	  "Plate_conf_file_name:  $plateconf\n",
	  "Is_isogenic:  $is_isogenic_screen\n",
	  "Gene_name_if_isogenic:  $gene_name_if_isogenic\n",
	  "Isogenic_mutant_description:  $isogenic_mutant_description\n",
	  "Method_of_isogenic_knockdown:  $method_of_isogenic_knockdown\n",
	  "Compound:  $compound\n",
	  "Compound_concentration:  $compound_concentration\n",
	  "Dosing_regime:  $dosing_regime\n",
	  "Reanalysis_details:  \n";
	  
    print "<p><div id=\"Note\">Analysing...</div></p>"; 
    
    close (INFOFILE);  

   my $info_file_original_path = $file_path."/".$screen_dir_name."_screen_details.txt";
   my $info_file_new_path = $configures{'WebDocumentRoot'} . $configures{'info_file'};
   `cp -r $info_file_original_path $info_file_new_path `;
   my $drug_screen_link_to_metadata = $configures{'hostname'} . $configures{'info_file'} . $screen_dir_name . "_screen_details.txt";
  
  # save summary file path and dose response file path in a variable so that it can be stored in Drug_screen_info table
  my $summary_file_complete = $file_path."/".$screen_dir_name."_pocscores_summary.txt"; 
  my $summary_zscores_file_complete = $file_path."/".$screen_dir_name."_zscores_summary.txt";
  my $drc_file_complete = $file_path."/".$screen_dir_name."_pocscores_drugresponse.txt"; 
  
  ## 3. Store new Rnai screen metadata in the database ##
  my $zp_value;
  $query = "INSERT INTO 
  			  Drug_screen_info (      
			  Cell_line,    
			  Drug_screen_name,    
			  Date_of_run,    
			  Operator,  
			  Collaborator,
			  Cells_per_well,
			  Length_of_assay,  
			  Is_isogenic,    
			  Gene_name_if_isogenic,    
			  Isogenic_mutant_description,    
			  Method_of_isogenic_knockdown,
			  Compound,
			  Compound_concentration,   
			  Dosing_regime,
			  Compound_library_name,    
			  Plate_list_file_name,    
			  Plate_conf_file_name,   
			  Drug_screen_link_to_z_report,
			  Drug_screen_link_to_poc_report,
			  Drug_screen_link_to_qc_plots,
			  Drug_screen_link_to_drc_plots,
			  Drug_screen_link_to_drc_file,
			  Drug_screen_link_to_rep_zscores,
			  Drug_screen_link_to_rep_pocscores,
			  Drug_screen_link_to_metadata,
			  Zprime,
			  QC,
			  Summary_file_path,
			  Summary_pocscores_file_path,
			  Notes,
			  Reanalysis_details,   
			  Instrument_used_Instrument_used_ID,   
			  Tissue_type_Tissue_type_ID,    
			  Compound_library_file_path_Compound_library_file_path_ID,
			  Plateconf_file_path_Plateconf_file_path_ID,
			  Platelist_file_path_Platelist_file_path_ID,
			  Compound_library_Compound_library_ID 
			  ) 
			  SELECT
				'$cell_line_name',
				'$screen_dir_name',
				'$date_of_run', 
				'$operator',
				'$collaborator',
				'$cells_per_well',
				'$length_of_assay',
				'$is_isogenic_screen',
				'$gene_name_if_isogenic',
				'$isogenic_mutant_description',
				'$method_of_isogenic_knockdown',
				'$compound',
				'$compound_concentration',
				'$dosing_regime',
				'$templib',
				'$platelist',
				'$plateconf',
				'$rnai_screen_link_to_z_report',
				'$rnai_screen_link_to_poc_report',
				'$rnai_screen_link_to_qc_plots',
				'$drug_screen_link_to_drc_plots',
				'$drug_screen_link_to_drc_file',
				'$drug_screen_link_to_rep_zscores',
				'$drug_screen_link_to_rep_pocscores',
				'$drug_screen_link_to_metadata',
				'NA',
				'-TBC',
				'$summary_zscores_file_complete',
				'$summary_file_complete',
				'$notes', 
				'', 
				( SELECT Instrument_used_ID FROM Instrument_used WHERE Instrument_name = '$instrument' ),
				( SELECT Tissue_type_ID FROM Tissue_type WHERE Tissue_of_origin = '$tissue_type' ), 
				( SELECT Compound_library_file_path_ID FROM Compound_library_file_path WHERE Compound_library_file_location = '$templib_file_path' ),
				( SELECT Plateconf_file_path_ID FROM Plateconf_file_path WHERE Plateconf_file_location = '$plateconf_file_path' AND Plateconf_file_path_ID > '37' ),
				( SELECT Platelist_file_path_ID FROM Platelist_file_path WHERE Platelist_file_location = '$platelist_file_path' AND Platelist_file_path_ID > '18' ),
				( SELECT Compound_library_ID FROM Compound_library WHERE Compound_library_name = '$templib' )";  
 
  $query_handle = $dbh->prepare( $query );
   					    #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute(); 
    #or die "SQL Error: " . $query_handle -> errstr();
  #if ($test) {
    #print "works";
  #}
  #else {
   # print "error";
  #}
  #capture the last row ID for the rnai screen info table in the database
  my $last_rnai_screen_info_id = $dbh -> { mysql_insertid };
  #$query_handle -> finish();
  
  open (FILE, $summary_file_complete);
  my $line1 = <FILE>; #skip the header
  while ( $line1 = <FILE> ) {
    chomp $line1;
    my ($plate_number_for_summary, 
    $position, 
    $zscore_summary, 
    $well_number_for_summary, 
    $well_anno, 
    $final_well_anno, 
    $raw_r1_ch1, 
    $raw_r2_ch1, 
    $raw_r3_ch1, 
    $median_ch1, 
    $average_ch1, 
    $raw_plate_median_r1_ch1, 
    $raw_plate_median_r2_ch1, 
    $raw_plate_median_r3_ch1, 
    $normalized_r1_ch1, 
    $normalized_r2_ch1, 
    $normalized_r3_ch1, 
    $compound_summary,
    $compound_func,
    $cas_summary,
    $layout_summary,
    $conc_summary) = split(/\t/, $line1);
  
    my $query = "INSERT INTO Summary_of_result(
    Plate_number_for_summary, 
    Position, 
    Zscore_summary, 
    Well_number_for_summary, 
    Well_anno, 
    Final_well_anno, 
    Raw_r1_ch1, 
    Raw_r2_ch1, 
    Raw_r3_ch1, 
    Median_ch1, 
    Average_ch1, 
    Raw_plate_median_r1_ch1, 
    Raw_plate_median_r2_ch1, 
    Raw_plate_median_r3_ch1, 
    Normalized_r1_ch1, 
    Normalized_r2_ch1, 
    Normalized_r3_ch1, 
    Compound_summary, 
    Compound_func, 
    CAS_summary,
    Layout_summary,
    Conc_summary,
    Drug_screen_info_Drug_screen_info_ID,  
    Compound_library_Compound_library_ID
    ) 
    SELECT 
    '$plate_number_for_summary', 
    '$position', 
    '$zscore_summary',  
    '$well_number_for_summary',  
    '$well_anno', 
    '$final_well_anno', 
    '$raw_r1_ch1', 
    '$raw_r2_ch1', 
    '$raw_r3_ch1', 
    '$median_ch1', 
    '$average_ch1', 
    '$raw_plate_median_r1_ch1', 
    '$raw_plate_median_r2_ch1', 
    '$raw_plate_median_r3_ch1', 
    '$normalized_r1_ch1', 
    '$normalized_r2_ch1', 
    '$normalized_r3_ch1', 
    '$compound_summary', 
    '$compound_func',
    '$cas_summary',
    '$layout_summary',
    '$conc_summary',
    '$last_rnai_screen_info_id', 
    (SELECT Compound_library.Compound_library_ID FROM Compound_library WHERE Compound_library_name = '$templib')";
	
    my $query_handle = $dbh -> prepare($query);
    $query_handle -> execute();
  }
  
  close FILE;
  
  ## populate database with screen drc result file
  
  open (FILE, $drc_file_complete);
  my $line2 = <FILE>; #skip the header
  while ( $line2 = <FILE> ) {
    chomp $line2;
    my ($drug, 
    $layout, 
    $sf80, 
    $sf50, 
    $sf20, 
    $auc100, 
    $slope, 
    $slope_pval, 
    $einf, 
    $ec50, 
    $lof_pval, 
    $auc100_actual) = split(/\t/, $line2);
  
    my $query = "INSERT INTO Doseresponse_result(
    Drug, 
    Layout, 
    SF80, 
    SF50, 
    SF20, 
    AUC100, 
    Slope, 
    Slope_pval, 
    Einf, 
    EC50, 
    LOF_pval, 
    AUC100_actual, 
    Drug_screen_info_Drug_screen_info_ID,  
    Compound_library_Compound_library_ID
    ) 
    SELECT 
    '$drug', 
    '$layout', 
    '$sf80',  
    '$sf50',  
    '$sf20', 
    '$auc100', 
    '$slope', 
    '$slope_pval', 
    '$einf', 
    '$ec50', 
    '$lof_pval', 
    '$auc100_actual', 
    '$last_rnai_screen_info_id', 
    (SELECT Compound_library.Compound_library_ID FROM Compound_library WHERE Compound_library_name = '$templib')";
	
    my $query_handle = $dbh -> prepare($query);
    $query_handle -> execute();
  }
  
  close FILE;
  
  print "<p>";
  print "<p><div id=\"Note\">Stored screen results in the database...</div></p>";
  print "</p>";
 
  print "<p></p>";
 
  print "<p><b>ANALYSIS DONE</b></p>";
  
  print "<b>Drug screen name: $screen_dir_name</b>";
  
  print "<p></p>";
  
  print "<p>";
  print "<a href = \"$rnai_screen_link_to_z_report\">View cellHTS2 analysis report based on Z-scores</a>";
  print "<p>";
  
  print "<p>";
  print "<a href = \"$rnai_screen_link_to_poc_report\">View cellHTS2 analysis report based on POC-scores</a>";
  print "<p>";
  
  print "<p>";
  print "<a href=" . $configures{'hostname'} . "cgi-bin/$script_name?show_qc=1\&screen_dir_name=$screen_dir_name\&plate_conf=$plateconf>QC</a>";
  print "</p>"; 
  
  print "<p>";
  print "<a href = \"$drug_screen_link_to_drc_plots\">View dose response curves</a>";
  print "<p>";
  
  print "<p>";
  print "<a href = \"$drug_screen_link_to_drc_file\">View DRC result file</a>";
  print "<p>";
    
  print "<p>";
  print "<a href = \"$drug_screen_link_to_rep_zscores\">View topTable with replicate Z-scores</a>";
  print "<p>";

  print "<p>";
  print "<a href = \"$drug_screen_link_to_rep_pocscores\">View topTable with replicate POC-scores</a>";
  print "<p>";

  print "$page_footer";
  print $q -> end_html;
}

  ############### TO DO:
  ############### enter data into SQL database 
  ############### store URL for HTML report in database
  ############### store z-score and QC in database
  ############### print a done message and re-direct to another page


  # ================================
  # Save new uploaded plateconf file
  # ================================

sub save_new_uploaded_plateconf_file {
  
  	my $lightweight_fh = $q -> upload ( 'new_uploaded_plateconf_file' );
  	my $new_uploaded_plateconf_file = $q -> param( "new_uploaded_plateconf_file" );
  	my $plateconf_folder = $configures{'WebDocumentRoot'} . $configures{'plateconf_folder'};
  	my $target= "";
  	my $new_plateconf_file_renamed; 
  	#my $new_plateconf_filename = $q -> param ( "new_plateconf_filename" );
  
  	if ( !$new_uploaded_plateconf_file ) {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: Please upload a plateconf file.";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	return;
  	}
  	
  	if ( !($new_uploaded_plateconf_file =~ /\.txt$/) ) {
    	my $message = "ERROR: You uploaded $new_uploaded_plateconf_file. Please upload a valid text file with extension .txt.";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
  
    my $new_plateconf_filename_wo_spaces = $new_uploaded_plateconf_file;
    $new_plateconf_filename_wo_spaces =~ s/\.txt$//;
    $new_plateconf_filename_wo_spaces =~ s/\s+/_/g;
    my $new_plateconf_file_basename = $new_plateconf_filename_wo_spaces;
    $new_plateconf_file_basename =~ s/[^A-Za-z0-9_-]*//g;
    $new_plateconf_file_renamed = $new_plateconf_file_basename.".txt";
    
    $target = $plateconf_folder.$new_plateconf_file_renamed;
    if (-e $target)
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
    	my $message = "The plate configuration file name has been used previously. Please check!";
		print "<div id=\"Message\"><p><b>$message</b></p></div>";		  
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
  		return; 
    }
    
    my $query = "SELECT Plateconf_file_path.Plateconf_file_path_ID FROM Plateconf_file_path  WHERE Plateconf_file_location = '$target'";
    my $query_handle = $dbh->prepare( $query );
	$query_handle->execute() or die "Cannot execute mysql statement: $DBI::errstr";
	my $plateconf_file_path_id = $query_handle->fetchrow_array();
	if(defined($plateconf_file_path_id))
	{
		my $message = "The plate configure file name $new_plateconf_file_basename has been used before. Please give a different name.";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
    	print "$page_footer";
    	print $q -> end_html;
    	return;
	}
    
    my $tmpfile_path1 = $plateconf_folder."tmpfile1.txt";
    my $tmpfile_path2 = $plateconf_folder."tmpfile2.txt";
        
    # undef may be returned if it's not a valid file handle
    if ( !defined $lightweight_fh ) {
    	my $message = "ERROR: The plate configure file cannot be loaded";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
            
   	# Upgrade the handle to one compatible with IO::Handle
	my $io_handle = $lightweight_fh->handle;
    
	#save the uploaded file on the server
	my $fh = undef;
	open ( $fh,'>', $tmpfile_path1 )
        	or die "Cannot upload the plate configure file:$!\n";
	if ( !$fh ) {
    	my $message = "ERROR: Cannot open temporary file $tmpfile_path1";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<div id=\"Message\"><p><b>$message</b></p></div>"; 
    	print "$page_footer";
    	print $q -> end_html;
		return;
	}
		    
	my $bytesread = undef;
	my $buffer = undef;
	while ( $bytesread = $io_handle -> read ( $buffer,1024 ) ) {
     	my $print_plateconf = print $fh $buffer;
     	if ( !$print_plateconf ) {  
    		print $q -> header ( "text/html" );
    		print "$page_header";
  			my $message = "ERROR: Error writing temporary file $tmpfile_path1";
    		print "<div id=\"Message\"><p><b>$message</b></p></div>";
    		print "$page_footer";
    		print $q -> end_html;
    		return;
      	}
 	}
	close $fh;
    
    #reformat the uploaded file
    `tr '\r' '\n'  < $tmpfile_path1  > $tmpfile_path2`;
    unlink $tmpfile_path1;
    
    open IN, "<$tmpfile_path2"
      or die "Cannot open $tmpfile_path2:$!\n";
    
    my $firstLine = <IN>;
    if( !($firstLine =~ "^Wells") )
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The first line of the plate configure file should begin with \"Wells\"";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2;
  		return;  	
    }
    
    my $secondLine = <IN>;
    if( !($secondLine =~ "^Plates") )
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The second line of the plate configure file should begin with \"Plates\"";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2;
  		return;  	
    }
    
    my $thirdLine = <IN>;
  	my $OK = ($thirdLine =~ "^Plate\t") && ($thirdLine =~ "\tWell\t") && ($thirdLine =~ "\tContent") ;
    if( !$OK )
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The third line of the plate configure file should be \"Plate\", \"Well\", \"Content\"";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2;
  		return;  	
    }
    
    close IN;
   	    
    $query = "INSERT INTO Plateconf_file_path (
      					  Plateconf_file_location )
     					  VALUES (
      					  '$target' )";
   	$query_handle = $dbh -> prepare ( $query );
       					 #or die "Cannot prepare: " . $dbh -> errstr();
    $query_handle -> execute();
      #or die "SQL Error: ".$query_handle -> errstr();
    if ( !$query_handle ) {  
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: Couldn't execute sql statement for adding new plateconf file location to the database";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>"; 
    	print "$page_footer";
    	print $q -> end_html;
    	unlink $tmpfile_path2;
    	return;
    }
    
    move $tmpfile_path2, $target;
    
    my $message = "Plate configururation file uploaded successfully! It can now be selected for analysis from the drop down menu.";    
    print $q -> header ( "text/html" );
    print "$page_header"; 
    print "<div id=\"Message\"><p><b>$message</b></p></div>";
  	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    print "$page_footer";
    print $q -> end_html;
    return;
    
   	# $query_handle -> finish();
    #print $q->redirect (-uri=>"http://www.gft.icr.ac.uk/cgi-bin/$script_name?add_new_screen=1"); 
  	#my $file_upload_message = $q -> param ( -name => 'file_upload_message',
  	#		  							  -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' ); 
   	#&add_new_screen( $file_upload_message );  
  	#print $q -> hidden ( -name => 'file_upload_message',
  	#				   -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
} #end of save_new_uploaded_plateconf_file subroutine 
  
  
  # ================================
  # Save new uploaded platelist file
  # ================================

sub save_new_uploaded_platelist_file {
  	my $lightweight_fh  = $q -> upload ( 'new_uploaded_platelist_file' );
  	my $new_uploaded_platelist_file = $q -> param( "new_uploaded_platelist_file" );
  	my $platelist_folder = $configures{'WebDocumentRoot'} . $configures{'platelist_folder'};
  	my $target = "";
  	my $new_platelist_file_renamed;
  
  	if ( !$new_uploaded_platelist_file) {
  		my $message = "ERROR: Please upload a platelist file";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;
  	}
  	
  	if ( !($new_uploaded_platelist_file =~ /\.txt$/) ) {
    	my $message = "ERROR: You uploaded $new_uploaded_platelist_file. Please upload a valid text file with extension .txt.";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
  
    my $tmpfile_path1 = $platelist_folder."tmpfile1.txt";
    my $tmpfile_path2 = $platelist_folder."tmpfile2.txt";
      
    if ( !defined $lightweight_fh ) {
    	my $message = "ERROR: The platelist file cannot be loaded";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
		
	# Upgrade the handle to one compatible with IO::Handle:
    my $io_handle = $lightweight_fh -> handle;

	#save the uploaded file in tmpfile.txt on the server
	my $fh = undef;
	open ( $fh, '>', $tmpfile_path1 )
        	or die "Cannot upload the platelist file:$!\n";
	if ( !defined($fh) ) {
    	my $message = "ERROR: Cannot open temporary file tmpfile1.txt";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>"; 
    	print "$page_footer";
    	print $q -> end_html;
    	unlink $tmpfile_path1;
    	return;
    }	    
	
	my $bytesread = undef;
	my $buffer = undef;
	while ( $bytesread = $io_handle -> read ( $buffer,1024 )) {
		my $print_platelist = print $fh $buffer;
		my $message = "ERROR: Error writing temporary file tmpfile1.txt";
       	if ( !$print_platelist ) {  
    		print $q -> header ( "text/html" );
    		print "$page_header"; 
    		print "<div id=\"Message\"><p><b>$message</b></p></div>";
  			print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>"; 
    		print "$page_footer";
    		print $q -> end_html;
    		close $fh;
    		unlink $tmpfile_path1;
  			return;
        }  
    }
    close $fh;
    
    #reformat the uploaded file
    `tr '\r' '\n'  < $tmpfile_path1  > $tmpfile_path2`;
    unlink $tmpfile_path1;

    open IN, "<$tmpfile_path2"
      or die "Cannot open $tmpfile_path2:$!\n";
    
    my $firstLine = <IN>;
    my $number_of_plates = 0;
    if( ($firstLine =~ "^Filename\t") && ($firstLine =~ "\tPlate\t") &&($firstLine =~ "\tReplicate") )
    {
    	$number_of_plates = 0;
    }
    else
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The column names of the plate list file should be \"Filename\", \"Plate\", \"Replicate\"";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2; 
  		return;  	
    }
    
    my $secondLine = <IN>;
    chomp $secondLine;
    my $thirdLine = <IN>;
    chomp $thirdLine;
    my @secondLine = split(/\t/,$secondLine);
    my @thirdLine = split(/\t/,$thirdLine);
	my $version = 0;
	if ($secondLine[1]==$thirdLine[1])
	{
		$version = 1;
	}
	
	if ($secondLine[2]==$thirdLine[2])
	{
		$version = 2;
	}
	
    if( ($secondLine =~ "^P1.txt\t") && ($thirdLine =~ "^P2.txt\t") )
    {
    	$number_of_plates = $number_of_plates + 2;
    }
    else
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The filenames of the plate list file should be P1.txt, P2.txt, etc.";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2;
  		return;  	
    }
        
    while ( <IN> ) {
      if( /\S/ ) {
      		$number_of_plates = $number_of_plates + 1;
        }
      }
    close IN;
    
     my $new_platelist_filename_wo_spaces = $new_uploaded_platelist_file;
    $new_platelist_filename_wo_spaces =~ s/\.txt$//;
    $new_platelist_filename_wo_spaces =~ s/\s+/_/g;
    my $new_platelist_file_basename = $new_platelist_filename_wo_spaces;
    $new_platelist_file_basename =~ s/[^A-Za-z0-9_-]*//g;
    $new_platelist_file_renamed = $new_platelist_file_basename.".txt";
   
    $target = $platelist_folder.$new_platelist_file_renamed;
    
    if (-e $target)
    {
    	unlink $tmpfile_path2;
    	print $q -> header ( "text/html" );
    	print "$page_header";
    	my $message = "The platelist file has " . $number_of_plates . " plates.";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	$message = "It is probably identical to " . $new_platelist_file_renamed . ". Please check!";
		print "<div id=\"Message\"><p><b>$message</b></p></div>";		  
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
  		return; 
    }
  	   
    my $query = "INSERT INTO Platelist_file_path (Platelist_file_location ) VALUES ('$target' )";
    my $query_handle = $dbh -> prepare ( $query );
    $query_handle -> execute();
    if ( !$query_handle ) {   	
    	my $message = "ERROR: Couldn't execute sql statement for adding new plate list file location to the database";    
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
  		print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	unlink $tmpfile_path2;
      	return;
    }
    
    move $tmpfile_path2, $target;
    
    my $message = "Plate list file uploaded successfully! It is renamed as ". $new_platelist_file_renamed . ". It can now be selected for analysis from the drop down menu.";    
    print $q -> header ( "text/html" );
    print "$page_header"; 
    print "<div id=\"Message\"><p><b>$message</b></p></div>";
  	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    print "$page_footer";
    print $q -> end_html;
    return;
    
	#my $file_upload_message = $q -> param ( -name => 'file_upload_message',
  	#		  							  -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
  
	#&add_new_screen($file_upload_message);
  	#print $q -> hidden ( -name => 'file_upload_message',
  	#				   -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
} #end of save_new_uploaded_platelist_file subroutine
  
  
  # ================================
  # Save new uploaded library file
  # ================================
       
sub save_new_uploaded_templib_file {
  	my $lightweight_fh  = $q -> upload( 'new_uploaded_templib_file' );
  	my $new_uploaded_templib_file = $q -> param( "new_uploaded_templib_file" );
  	my $templib_folder = $configures{'WebDocumentRoot'} . $configures{'templib_folder'};
  	my $target = "";
  	my $new_templib_file_renamed;
  
  	if ( !$new_uploaded_templib_file ) {
  		my $message = "ERROR: Please upload a template library file"; 
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
    	print "$page_footer";
    	print $q -> end_html;
    	return;
  	}
  	
  	if ( !($new_uploaded_templib_file =~ /\.txt$/) ) {
    	my $message = "ERROR: You uploaded $new_uploaded_templib_file. Please upload a valid text file with extension .txt.";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
  	  	 	
  	my $tmpfile_path1 = $templib_folder . "tmpfile1.txt";
    my $tmpfile_path2 = $templib_folder . "tmpfile2.txt";

    my $new_templib_filename_wo_spaces = $new_uploaded_templib_file;
    $new_templib_filename_wo_spaces =~ s/\.txt$//;
    $new_templib_filename_wo_spaces =~ s/\s+/_/g;
    my $new_templib_file_basename = $new_templib_filename_wo_spaces;
    $new_templib_file_basename =~ s/[^A-Za-z0-9_-]*//g;
    $new_templib_file_renamed = $new_templib_file_basename.".txt";
       
    $target = $templib_folder . $new_templib_file_renamed;
    
    my $query = "SELECT Compound_library.Compound_library_ID FROM Compound_library WHERE Compound_library_name = '$new_templib_file_basename'";
    my $query_handle = $dbh->prepare( $query );
	$query_handle->execute() or die "Cannot execute mysql statement: $DBI::errstr";
	my $template_library_id = $query_handle->fetchrow_array();
	if(defined($template_library_id))
	{
		my $message = "The compound library name $new_templib_file_basename has been used before. Please give a different name.";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
    	print "$page_footer";
    	print $q -> end_html;
    	return;
	}
	
	if (-e $target)
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
    	my $message = "The compound library file name has been used before. Please give a different name.";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";	  
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
  		return; 
    }

    if ( !defined $lightweight_fh ) {
    	my $message = "ERROR: The compound library file cannot be loaded";
    	print $q -> header ( "text/html" );
    	print "$page_header";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
    
   	# Upgrade the handle to one compatible with IO::Handle:
	my $io_handle = $lightweight_fh->handle;
      
	#save the uploaded file in tmpfile1.txt on the server
	my $fh = undef;
	open ( $fh,'>', $tmpfile_path1 )
      	or die "Cannot upload the compound library file:$!\n";
  	if ( !$fh ) 
  	{    
    	my $message = "ERROR: Cannot open temporary file $tmpfile_path1";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<p><b><div id=\"Message\">$message</b></p></div>"; 
    	print "$page_footer";
    	print $q -> end_html;
		return;
	}	     
	 
	my $bytesread = undef;
	my $buffer = undef;
	while ( $bytesread = $io_handle->read( $buffer,1024 ) ) 
	{
		my $print_templib = print $fh $buffer;
     	if ( !$print_templib ) {
          	my $message = "ERROR: Error writing temporary file $tmpfile_path1";
    		print $q -> header ( "text/html" );
    		print "$page_header"; 
    		print "<div id=\"Message\"><p><b>$message</b></p></div>"; 
    		print "$page_footer";
    		print $q -> end_html;
    		return;
       	} 
   	}
	close $fh;
	
	#reformat the uploaded file
    `tr '\r' '\n'  < $tmpfile_path1  > $tmpfile_path2`;
    unlink $tmpfile_path1;

   	open IN, "<$tmpfile_path2"
      or die "Cannot open $tmpfile_path2:$!\n";
    
   	my $firstLine = <IN>;
   	my $OK = ($firstLine =~ "^Plate\t") && ($firstLine =~ "\tWell\t") && ($firstLine =~ "\tGeneID\t") && ($firstLine =~ "\tFunction\t") && ($firstLine =~ "\tCAS\t") && ($firstLine =~ "\tLayout\t")&& ($firstLine =~ "\tConcentration_pM");
    if( !$OK )
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The column names of the template library file should be \"Plate\", \"Well\", \"GeneID\", \"Function\", \"CAS\", \"Layout\"  and \"Concentration_pM\" ";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";     	 
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2;
  		return;  	
    }
    		
 	$query = "INSERT INTO Compound_library_file_path (Compound_library_file_location) VALUES ('$target' )";
    $query_handle = $dbh->prepare( $query );
    $query_handle -> execute();
      #or die "SQL Error: " . $query_handle -> errstr();
    if ( !$query_handle ) {
      	my $message = "ERROR: Couldn't execute sql statement for adding new compound library file location to the database";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";  
    	print "$page_footer";
    	print $q -> end_html;
    	unlink $tmpfile_path2;
    	return;
    }
    
    $query = "INSERT INTO Compound_library (Compound_library_name) VALUES ('$new_templib_file_basename')";
   	$query_handle = $dbh->prepare( $query );
    $query_handle -> execute();
    if ( !$query_handle ) {
      	my $message = "ERROR: Couldn't execute sql statement for adding new compound library name to the database";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<div id=\"Message\"><p><b>$message</b></p></div>"; 
    	print "$page_footer";
    	print $q -> end_html;
    	unlink $tmpfile_path2;
    	return;
    }
    
    $query = "SELECT Compound_library.Compound_library_ID FROM Compound_library WHERE Compound_library_name = '$new_templib_file_basename'";
    $query_handle = $dbh->prepare( $query );
	$query_handle->execute() or die "Cannot execute sql statement: $DBI::errstr";
	$template_library_id = $query_handle->fetchrow_array();
    		
    # follow http://stackoverflow.com/questions/13671195/working-perl-ascript-now-says-dbdmysqldb-do-failed-you-have-an-error-in-yo
    $query = "INSERT INTO Compound_library_file (
							  Plate_complib, 
							  Well_complib,
							  Compound,
							  Function_of_compound,
							  CAS,
							  Layout,
							  Concentration_pM,
							  Compound_library_Compound_library_ID
							  ) VALUES(
							   ?, ?, ?, ?, ?, ?, ?, ?
							  )";
							  
    $query_handle = $dbh->prepare($query);
    my $line3 = undef;
    while ( <IN> ) 
    {
		if( /\S/ ) 
		{
			$line3 = $_;
        	chomp $line3;
    		my ($plate, $well, $compound, $function_of_compound, $CAS, $layout, $concentration_pM) = split(/\t/,$line3);  
    		
    		$query_handle -> execute($plate, $well, $compound, $function_of_compound, $CAS, $layout, $concentration_pM, $template_library_id);
    		if ( !$query_handle ) {
      			my $message = "ERROR: Couldn't execute sql statement for adding new compound library data to the database";
    			print $q -> header ( "text/html" );
    			print "$page_header";  
    			print "<div id=\"Message\"><p><b>$message</b></p></div>";
    			print "<p> Plate: $plate</p>";
    			print "<p> Well: $well</p>";
    			print "<p> Compound: $compound</p>";
    			if(!defined($compound))
    			{
    				print "<p> variable compound not defined</p>";
    			}
    			else
    			{
    				print "<p> variable compound is defined</p>";
    			}
    			print "<p> Function_of_compound: $function_of_compound</p>";
    			if(!defined($function_of_compound))
    			{
    				print "<p> variable function_of_compound not defined</p>";
    			}
    			else
    			{
    				print "<p> variable function_of_compound is defined</p>";
    			}
  				print "<p> CAS: $CAS</p>";
  				if(!defined($CAS))
    			{
    				print "<p> variable CAS not defined</p>";
    			}
    			else
    			{
    				print "<p> variable CAS is defined</p>";
    			}
    			print "<p> Layout: $layout</p>";
  				if(!defined($layout))
    			{
    				print "<p> variable Layout not defined</p>";
    			}
    			else
    			{
    				print "<p> variable layout is defined</p>";
    			}
    			print "<p> Concentration in pM: $concentration_pM</p>";
  				if(!defined($CAS))
    			{
    				print "<p> variable concentration_pM not defined</p>";
    			}
    			else
    			{
    				print "<p> variable concentration_pM is defined</p>";
    			}
  				print "<p> Compound library name: $new_templib_file_basename</p>";
    			print "$page_footer";
    			print $q -> end_html;
    			unlink $tmpfile_path2;
    			return;
    		}        	
        }
    }
    close IN;
    move $tmpfile_path2, $target;
    
    my $message = "Compound library file uploaded successfully! It can now be selected for analysis from the drop down menu.";    
    print $q -> header ( "text/html" );
    print "$page_header"; 
    print "<div id=\"Message\"><p><b>$message</b></p></div>";
  	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    print "$page_footer";
    print $q -> end_html;
    return;
    
  	#my $file_upload_message = $q -> param( -name => 'file_upload_message',
  	#		  							-value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
  			  							
    #&add_new_screen( $file_upload_message ); 
  	#print $q -> hidden ( -name => 'file_upload_message',
  	#				   -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
} #end of save_new_uploaded_templib_file subroutine
  
# ==================================
# Subroutine for showing all screens
# ==================================
						  
sub show_all_screens {

my $show_all_screens_page_header = "<html>
				  				    <head>
									<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />
									<title>GFT DRUG database</title>
									<link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"/css/rnaidb.css\" />
									<meta name=\"viewport\" content=\"width=1000, initial-scale=0.5, minimum-scale=0.45\" />
								    <script src=\"http://code.jquery.com/jquery-1.4.1.min.js\"></script>
								    <script type=\"text/javascript\">
								      \$(document).ready(function() {
								      \$(\"#searchInput\").keyup(function(){
								   //hide all the rows
								      \$(\"#fbody\").find(\"tr\").hide();   
								  //split the current value of searchInput
								      var data = this.value.split(\" \");
								 //create a jquery object of the rows
								    var jo = \$(\"#fbody\").find(\"tr\");
		   
							     //Recusively filter the jquery object to get results.
								    \$.each(data, function(i, v){
								   jo = jo.filter(function(){
									 return (this.innerHTML.toUpperCase().indexOf(v.toUpperCase())!=-1);
								     }); 
								  });
							     //show the rows that match.
								   jo.show();
							     //Removes the placeholder text  
   
							       }).focus(function(){
							       this.value=\"\";
							       \$(this).css({\"color\":\"black\"});
							       \$(this).unbind('focus');
							     }).css({\"color\":\"#C0C0C0\"});  
						      });
						      </script>
							  </head>
							  <body>
							  <div id=\"Box\"></div><div id=\"MainFullWidth\">
									<a href=$configures{'hostname'}><img src=\"http://gft.icr.ac.uk/images/ICR_GFT_drugDB_logo_placeholder.png\" width=415px height=160px></a>
									<p>
									<a href=\"/cgi-bin/$script_name?add_new_screen=1\">Add new screen</a>\&nbsp;\&nbsp;
									<a href=\"/cgi-bin/$script_name?show_all_screens=1\">Show all screens</a>\&nbsp;\&nbsp;
									<a href=\"/cgi-bin/$script_name?compute_drug_effect=1\">Drug effect analysis</a>\&nbsp;\&nbsp;
									<a href=\"/cgi-bin/$script_name?show_all_drug_effect_screens=1\">Drug effect results</a>\&nbsp;\&nbsp;
									<a href=\"/cgi-bin/$script_name?limma_analysis=1\">Limma analysis</a>\&nbsp;\&nbsp;
									<a href=\"/cgi-bin/$script_name?show_all_limma_screens=1\">Limma results</a>\&nbsp;\&nbsp;
									<a href=\"/cgi-bin/$script_name?configure_export=1\">Configure export</a>\&nbsp;\&nbsp;
									</p>
									<h1>Available screens:</h1>
									<p></p><p></p>
									Filter screens:
							  <input id=\"searchInput\" value=\"Enter keywords\"><br/><p></p><p></p>";
							  

				  
my $show_all_screens_page_footer = "<!-- end Box -->
								  </tbody>
								</table>
							  </div> <!-- end Main --></div>
							</body>
						  </html>";
 
  print $q -> header ( "text/html" );
  print "$show_all_screens_page_header";
  print $q -> start_multipart_form ( -method => "POST",
  									 -name => "showAllScreens"); 
  
#  my $check_screens = $q -> param ( "check_screens" );
#  my $remove_screens = $q -> param ( "Remove_screens" );
 
  my $query = "SELECT
  			  r.QC,
  			  r.Cell_line,
  			  t.Tissue_of_origin,
  			  r.Compound_library_name,
			  r.Date_of_run,
			  r.Operator,
			  r.Compound,
			  r.Compound_concentration,
			  r.Gene_name_if_isogenic,
			  r.Isogenic_mutant_description,
			  r.Drug_screen_link_to_z_report,
			  r.Drug_screen_link_to_poc_report,
			  r.Plate_conf_file_name,
			  r.Drug_screen_link_to_drc_plots,
			  r.Drug_screen_link_to_drc_file,
			  r.Drug_screen_link_to_rep_zscores, 
			  r.Drug_screen_link_to_rep_pocscores,
			  r.Drug_screen_link_to_metadata,
			  r.Drug_screen_name,
			  r.Drug_screen_info_ID,
			  r.Is_isogenic,
			  r.Has_drug_arm FROM
			  Drug_screen_info r, 
			  Tissue_type t WHERE
			  r.Tissue_type_Tissue_type_ID = t.Tissue_type_ID GROUP BY 
			  r.Drug_screen_info_ID ORDER BY
			  Cell_line ASC";
    
  my $query_handle = $dbh -> prepare ( $query );
   					   #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute();
   # or die "SQL Error: ".$query_handle -> errstr();


								 
			
# print "<table border=\"1\" style=\"width:100%\">";
 ####print "<table border=\"1\" style=\"border-collapse: collapse\">";

   
  print "<table border=\"1\" style=\"width:100%\"><thead><tr>\n";
    
  print "<th align=left>";
  print "Screen no.";
  print "</th>";
  
  print "<th align=left>";
  print "QC";
  print "</th>";
  
  print "<th align=left>";
  print "Cell line";
  print "</th>";
  
  print "<th align=left>";
  print "Tissue";
  print "</th>";
  
  print "<th align=left>";
  print "Library";
  print "</th>";
  
  print "<th align=left>";
  print "Date";
  print "</th>";
  
  print "<th align=left>";
  print "Operator";
  print "</th>";
  
  print "<th align=left>";
  print "Has drug arm";
  print "</th>";
  
  print "<th align=left>";
  print "Compound*Conc";
  print "</th>";
   
  print "<th align=left>";
  print "Is isogenic";
  print "</th>";
  
  print "<th align=left>";
  print "Isogenic gene*Description";
  print "</th>";
  
  print "<th align=left>";
  print "Link to cellHTS2 analysis Z-score report";
  print "</th>"; 
  
  print "<th align=left>";
  print "Link to cellHTS2 analysis POC-score report";
  print "</th>";
  
  print "<th align=left>";
  print "View/Download QC plots";
  print "</th>";
  
  print "<th align=left>";
  print "View/Download DRC plots";
  print "</th>";
  
  print "<th align=left>";
  print "View/Download DRC file";
  print "</th>";
  
  print "<th align=left>";
  print "View/Download rep Z-scores";
  print "</th>";
  
  print "<th align=left>";
  print "View/Download rep POC-scores";
  print "</th>";
    
  print "<th align=left>";
  print "View/Download screen details";
  print "</th>";
  
#  print "<th align=left>";
#  print "Remove screens";
#  print "</th>";
  print " </tr></thead><tbody id=\"fbody\">";  

  my $row;
  while ( my @row = $query_handle -> fetchrow_array ) {
  
    print "<tr>";
       
    print "<td>";
    print "gft-D$row[19]";
    print "</td>";
    
    print "<td>";
    print "$row[0]";
    print "</td>";
    
    print "<td>";
    print "$row[1]";
    print "</td>";
    
    print "<td>";
    print "$row[2]";
    print "</td>"; 
    
    print "<td>";
    print "$row[3]";
    print "</td>";
    
    print "<td>";
    print "$row[4]";
    print "</td>";
    
    print "<td>";
    print "$row[5]";
    print "</td>";
    
    print "<td>";
    print "$row[21]";
    print "</td>";
    
    print "<td>";
    print "$row[6]*$row[7]";
    print "</td>"; 
    
    print "<td>";
    print "$row[20]";
    print "</td>";
    
    print "<td>";
    print "$row[8]*$row[9]";
    print "</td>"; 
   
    print "<td>";
    print "<a href=\"$row[10]\" >Z-score report</a>";
    print "</td>"; 
    
    print "<td>";
    print "<a href=\"$row[11]\" >POC-score report</a>";
    print "</td>"; 
    
    print "<td>";
    print "<a href=" . $configures{'hostname'} . "cgi-bin/$script_name?show_qc=1\&screen_dir_name=$row[18]\&plate_conf=$row[12]>QC plots</a>";
    print "</td>"; 
    
    print "<td>";
    print "<a href=\"$row[13]\" >DRC plots</a>";
    print "</td>"; 
    
    print "<td>";
    print "<a href=\"$row[14]\" >AUC/SF scores</a>";
    print "</td>"; 
    
    print "<td>";
    print "<a href=\"$row[15]\" >Rep Z-scores</a>";
    print "</td>";
    
    print "<td>";
    print "<a href=\"$row[16]\" >Rep POC-scores</a>";
    print "</td>";

    print "<td>";
    print "<a href=\"$row[17]\" >Screen details</a>";
    print "</td>";
 
    print "<td>";
#    print $q -> checkbox( -name=>'check_screens',
#    					  -checked=>0,
#   	 				      -value=>'ON',
#    					  -label=>'',
#    					  -id=>$row[19]);
#    if ($check_screens eq 'ON') {
#  	  $query = "UPDATE Drug_screen_info set QC = 'F' WHERE Drug_screen_info_ID = $row[18]";
#	  $query_handle = $dbh -> prepare ( $query );
#	  $query_handle->execute();
#    } 						  
    
#    print "</td>"; 
    print "</tr>";

  } #end of while loop

  print "</table>";
  
  print "<p></p><p></p>";

#  print "<b>";
 # print "<input type=\"submit\" id=\"Remove_screens\" value=\"Remove_screens\" name=\"Remove_screens\"/>";
 # print "</b>";
  
  print $q -> end_multipart_form(); 

  print "$show_all_screens_page_footer";
  print $q -> end_html;

} #end of show_all_screens subroutine

# ==================================================
# Subroutine for configuring export (second version)
# ==================================================

sub configure_export {
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Configure export:</h1>";
  
    # the list of paths above includes some screens we don't want to export
  # but cannot delete until we get sudo rights. get the subset we do want
  # to use by querying the mysql db.
  
  my @all_summary_files;
  
  my $query = "SELECT
			  Summary_file_path FROM
			  Drug_screen_info WHERE
			  Compound_library_name like '%p11%' AND
			  Drug_screen_info_ID > '3947'";

  my $query_handle = $dbh -> prepare ( $query );
   					   #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute();
  
  while (my $sum_file_path = $query_handle -> fetchrow_array){
  
    push(@all_summary_files, $sum_file_path);
  }
  
  # write the list of cleaned up paths to a file that can be read by R to
  # find the summary files to process
  my $summary_file_list_file = $configures{'WebDocumentRoot'} . $configures{'configure_export_new_file_path'} . "z_summary_file_list_p-11_12_180321.txt";
  open FILESTOPROC, "> $summary_file_list_file" or die "Can't write file $summary_file_list_file: $!\n";
  foreach my $path (@all_summary_files){
    my $modified_path = $path;
    $modified_path =~ s/\.txt$/_with_rep_zscores.txt/;
   # if (! -e $modified_path){
    print FILESTOPROC "$path\n";
   # }
  }
  close FILESTOPROC;
  
  my $dir = $configures{'WebDocumentRoot'}.$configures{'configure_export_new_file_path'};
  
  # call an R script to process each summary file and 
  # write out a file with the replicate and summarised Z-scores
  # save this to :
  # /path/to/screen1/summary.txt ... write summary_with_score_reps.txt in same folder
  # /path/to/screen2/summary.txt ... write summary_with_score_reps.txt in same folder
  # if a processed summary file already exists in the folder, no need to remake

  `cd $dir && R --vanilla < $configures{'get_replicate_zscores_script'}`;
  
  # when all summary files are processed, read each one and create a hash for all Z-scores
  # $some_hash{$screen.$gene.$rep/'median'} = zscore
  
  my %colname_sirna_info_seen;
  my %median_zscores;
  my %replicate_zscores;
  my @rowname_filenames = ();
  my @colname_sirna_info = ();
  print "<p>@all_summary_files</p>";  
  foreach my $path (@all_summary_files){
    my $modified_path = $path;
    $modified_path =~ s/\.txt$/_with_rep_zscores.txt/;
    open SUMMARY, "< $modified_path" or die "Can't read summary file $modified_path: $!\n";
    my $header = <SUMMARY>;
    chomp $header;
    my @col_names = split(/\t/, $header);
    my ($plate_col, $pos_col, $score_col, $geneid_col, $conc_col, $rep1_col, $rep2_col, $rep3_col);
    for(my $i = 0; $i <= $#col_names; $i ++){
    
      if($col_names[$i] eq 'plate'){
        $plate_col= $i;
      }
      elsif($col_names[$i] eq 'position'){
        $pos_col = $i;
      }
      elsif($col_names[$i] eq 'score'){
        $score_col = $i;
      }
      elsif($col_names[$i] eq 'GeneID'){
        $geneid_col = $i;
      }
      elsif($col_names[$i] eq 'Concentration_pM' | $col_names[$i] eq 'Concentration.pM.'){
        $conc_col = $i;
      }
      elsif($col_names[$i] eq 'zscore_rep1' | $col_names[$i] eq '1.Channel 1'){
        $rep1_col = $i;
      }
      elsif($col_names[$i] eq 'zscore_rep2' | $col_names[$i] eq '2.Channel 1'){
        $rep2_col = $i;
      }
      elsif($col_names[$i] eq 'zscore_rep3' | $col_names[$i] eq '3.Channel 1'){
        $rep3_col = $i;
      }
    }
    defined($plate_col) or die "plate_col not defined";
    defined($pos_col) or die "pos_col not defined";
    defined($score_col) or die "score_col not defined";
    defined($geneid_col) or die "geneid_col not defined";
    defined($conc_col) or die "conc_col not defined";
    defined($rep1_col) or die "rep1_col not defined";
    defined($rep2_col) or die "rep2_col not defined";
    defined($rep3_col) or die "rep3_col not defined";
    
    # make a hash key from:
    # summary_file_name + plate + pos + geneID/- rep
    my $filename = $modified_path;
    $filename =~ s/^.*\///;
    $filename =~ s/_with_rep_zscores.txt$//;
	push(@rowname_filenames, $filename); 
	while(<SUMMARY>){
	  my $line = $_;
	  chomp $line;
	  my @fields = split(/\t/, $line);
	  my ($plate, $pos, $score, $geneid, $conc, $zrep1, $zrep2, $zrep3) = @fields[$plate_col,$pos_col,$score_col,$geneid_col,$conc_col,$rep1_col,$rep2_col,$rep3_col];
	  $geneid = uc($geneid);
	  if ($score ne "NA"){
	    my $score_key = $filename . "_" . $geneid . "_" . $conc;
	    unless (exists $colname_sirna_info_seen{$geneid . "_" . $conc}){
          push(@colname_sirna_info, $geneid . "_" . $conc);
        }
        $colname_sirna_info_seen{$geneid . "_" . $conc} = 1;
	    $median_zscores{$score_key} = $score;
	    $replicate_zscores{$score_key . "_rep1"} = $zrep1;
	    $replicate_zscores{$score_key . "_rep2"} = $zrep2;
	    $replicate_zscores{$score_key . "_rep3"} = $zrep3;
	  }
	}
    close SUMMARY;
  }
  
  # get array of each screen and array of each zscore*rep/median and write out
  # a table as was done for the configure_export sub previously
  
  my $median_zscores_file_path = $configures{'WebDocumentRoot'} . $configures{'configure_export_new_file_path'} . "median_drug_zscores_export_file_complete_p-11_12_180321.txt";
  my $replicate_zscores_file_path = $configures{'WebDocumentRoot'} . $configures{'configure_export_new_file_path'} . "replicate_drug_zscores_export_file_complete_p-11_12_180321.txt";
  
  open MEDOUT, "> $median_zscores_file_path" or die "Can't write to median zscores export file: $!\n";
  open REPSOUT, "> $replicate_zscores_file_path" or die "Can't write to replicate zscores export file: $!\n";
  
  # write out the column headings (siRNA info etc)
  print MEDOUT "screen";
  print REPSOUT "screen";
  foreach my $colname (@colname_sirna_info){
     print MEDOUT "\t$colname"; 
     print REPSOUT "\t$colname"; 
  }
  print MEDOUT "\n"; 
  print REPSOUT "\n"; 
  
  # now write the data for each screen as a separate row
  foreach my $rowname (@rowname_filenames){
    print MEDOUT "$rowname";
    foreach my $colname (@colname_sirna_info){
      if(exists $median_zscores{$rowname."_".$colname}){
        print MEDOUT "\t$median_zscores{$rowname.'_'.$colname}";
      }
      else{
        print MEDOUT "\tNA";
      }
    }
    print MEDOUT "\n";

    print REPSOUT "$rowname";
    print REPSOUT "_rep1";
    foreach my $colname (@colname_sirna_info){
      if(exists $replicate_zscores{$rowname."_".$colname."_rep1"}){
        print REPSOUT "\t$replicate_zscores{$rowname.'_'.$colname.'_rep1'}";
      }
      else{
        print REPSOUT "\tNA";
      }
    }
    print REPSOUT "\n";

    print REPSOUT "$rowname";
    print REPSOUT "_rep2";
    foreach my $colname (@colname_sirna_info){
      if(exists $replicate_zscores{$rowname."_".$colname."_rep2"}){
        print REPSOUT "\t$replicate_zscores{$rowname.'_'.$colname.'_rep2'}";
      }
      else{
        print REPSOUT "\tNA";
      }
    }
    print REPSOUT "\n";

    print REPSOUT "$rowname";
    print REPSOUT "_rep3";
    foreach my $colname (@colname_sirna_info){
      if(exists $replicate_zscores{$rowname."_".$colname."_rep3"}){
        print REPSOUT "\t$replicate_zscores{$rowname.'_'.$colname.'_rep3'}";
      }
      else{
        print REPSOUT "\tNA";
      }
    }
    print REPSOUT "\n";
  }
  
  my $link_for_median_zscores = $configures{'hostname'} . $configures{'configure_export_new_file_path'} . "median_drug_zscores_export_file_complete_p-11_12_180321.txt";
  my $link_for_replicate_zscores = $configures{'hostname'} . $configures{'configure_export_new_file_path'} . "replicate_drug_zscores_export_file_complete_p-11_12_180321.txt";
  
  print "<a href=\"$link_for_median_zscores\">Download exported plate 11-12-13-14 median Z-score data </a></br>";
  print "<p></p>";
  print "<a href=\"$link_for_replicate_zscores\">Download exported plate 11-12-13-14 replicate Z-score data </a>";
  
  ############
  ## export pocscores - median/per replicate 
  ############

  # find the list of all summary files - blob
  my @all_poc_summary_files;
  
  $query = "SELECT
			  Summary_pocscores_file_path FROM
			  Drug_screen_info WHERE
			  Compound_library_name like '%p11%' AND
			  Drug_screen_info_ID > '3947'";

  $query_handle = $dbh -> prepare ( $query );
   					   #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute();
  
  while (my $poc_sum_file_path = $query_handle -> fetchrow_array){
  
    push(@all_poc_summary_files, $poc_sum_file_path);
  }
  
  # the list of paths above includes some screens we don't want to export
  # but cannot delete until we get sudo rights. get the subset we do want
  # to use by querying the mysql db.
  
  # write the list of cleaned up paths to a file that can be read by R to
  # find the summary files to process
  my $poc_summary_file_list_file = $configures{'WebDocumentRoot'} . $configures{'configure_export_new_file_path'} . "poc_summary_file_list_p-11_12_180321.txt";
  open FILESTOPROC, "> $poc_summary_file_list_file" or die "Can't write file $poc_summary_file_list_file: $!\n";
  foreach my $poc_path (@all_poc_summary_files){
    my $poc_modified_path = $poc_path;
   # $poc_modified_path =~ s/\.txt$/_with_rep_pocscores.txt/;
   # if (! -e $poc_modified_path){
    print FILESTOPROC "$poc_path\n";
   # }
  }
  close FILESTOPROC;
  
  `cd $dir && R --vanilla < $configures{'get_replicate_zscores_script'}`;
  
  # when all summary files are processed, read each one and create a hash for all Z-scores
  # $some_hash{$screen.$gene.$rep/'median'} = zscore
  
  my %poc_colname_sirna_info_seen;
  my %poc_median_zscores;
  my %poc_replicate_zscores;
  my @poc_rowname_filenames = ();
  my @poc_colname_sirna_info = ();  
  foreach my $poc_path (@all_poc_summary_files){
    my $poc_modified_path = $poc_path;
   # $poc_modified_path =~ s/\.txt$/_with_rep_pocscores.txt/;
    open SUMMARY, "< $poc_modified_path" or die "Can't read summary file $poc_modified_path: $!\n";
    my $poc_header = <SUMMARY>;
    chomp $poc_header;
    my @poc_col_names = split(/\t/, $poc_header);
    my ($poc_plate_col, $poc_pos_col, $poc_score_col, $poc_geneid_col, $poc_conc_col, $poc_rep1_col, $poc_rep2_col, $poc_rep3_col);
    for(my $i = 0; $i <= $#poc_col_names; $i ++){
    
      if($poc_col_names[$i] eq 'plate'){
        $poc_plate_col= $i;
      }
      elsif($poc_col_names[$i] eq 'position'){
        $poc_pos_col = $i;
      }
      elsif($poc_col_names[$i] eq 'score'){
        $poc_score_col = $i;
      }
      elsif($poc_col_names[$i] eq 'GeneID'){
        $poc_geneid_col = $i;
      }
      elsif($poc_col_names[$i] eq 'Concentration_pM' | $poc_col_names[$i] eq 'Concentration.pM.'){
        $poc_conc_col = $i;
      }
      elsif($poc_col_names[$i] eq 'normalized_r1_ch1'){
        $poc_rep1_col = $i;
      }
      elsif($poc_col_names[$i] eq 'normalized_r2_ch1'){
        $poc_rep2_col = $i;
      }
      elsif($poc_col_names[$i] eq 'normalized_r3_ch1'){
        $poc_rep3_col = $i;
      }
    }
    defined($poc_plate_col) or die "poc_plate_col not defined";
    defined($poc_pos_col) or die "poc_pos_col not defined";
    defined($poc_score_col) or die "poc_score_col not defined";
    defined($poc_geneid_col) or die "poc_geneid_col not defined";
    defined($poc_conc_col) or die "poc_conc_col not defined";
    defined($poc_rep1_col) or die "poc_rep1_col not defined";
    defined($poc_rep2_col) or die "poc_rep2_col not defined";
    defined($poc_rep3_col) or die "poc_rep3_col not defined";
    
    # make a hash key from:
    # summary_file_name + plate + pos + geneID/- rep
    my $poc_filename = $poc_modified_path;
    $poc_filename =~ s/^.*\///;
   # $poc_filename =~ s/_with_rep_pocscores.txt$//;
	push(@poc_rowname_filenames, $poc_filename); 
	while(<SUMMARY>){
	  my $poc_line = $_;
	  chomp $poc_line;
	  my @poc_fields = split(/\t/, $poc_line);
	  my ($poc_plate, $poc_pos, $poc_score, $poc_geneid, $poc_conc, $pocrep1, $pocrep2, $pocrep3) = @poc_fields[$poc_plate_col,$poc_pos_col,$poc_score_col,$poc_geneid_col,$poc_conc_col,$poc_rep1_col,$poc_rep2_col,$poc_rep3_col];
	  $poc_geneid = uc($poc_geneid);
	  if ($poc_score ne "NA"){
	    my $poc_score_key = $poc_filename . "_" . $poc_geneid . "_" . $poc_conc;
	    unless (exists $poc_colname_sirna_info_seen{$poc_geneid . "_" . $poc_conc}){
          push(@poc_colname_sirna_info, $poc_geneid . "_" . $poc_conc);
        }
        $poc_colname_sirna_info_seen{$poc_geneid . "_" . $poc_conc} = 1;
	    $poc_median_zscores{$poc_score_key} = $poc_score;
	    $poc_replicate_zscores{$poc_score_key . "_rep1"} = $pocrep1;
	    $poc_replicate_zscores{$poc_score_key . "_rep2"} = $pocrep2;
	    $poc_replicate_zscores{$poc_score_key . "_rep3"} = $pocrep3;
	  }
	}
    close SUMMARY;
  }
  
  # get array of each screen and array of each zscore*rep/median and write out
  # a table as was done for the configure_export sub previously
  
  my $median_pocscores_file_path = $configures{'WebDocumentRoot'} . $configures{'configure_export_new_file_path'} . "median_pocscores_export_file_complete_p-11_12_180321.txt";
  my $replicate_pocscores_file_path = $configures{'WebDocumentRoot'} . $configures{'configure_export_new_file_path'} . "replicate_pocscores_export_file_complete_p-11_12_180321.txt";
  
  open MEDOUT, "> $median_pocscores_file_path" or die "Can't write to median pocscores export file: $!\n";
  open REPSOUT, "> $replicate_pocscores_file_path" or die "Can't write to replicate pocscores export file: $!\n";
  
  # write out the column headings (siRNA info etc)
  print MEDOUT "screen";
  print REPSOUT "screen";
  foreach my $poc_colname (@poc_colname_sirna_info){
     print MEDOUT "\t$poc_colname"; 
     print REPSOUT "\t$poc_colname"; 
  }
  print MEDOUT "\n"; 
  print REPSOUT "\n"; 
  
  # now write the data for each screen as a separate row
  foreach my $poc_rowname (@poc_rowname_filenames){
    print MEDOUT "$poc_rowname";
    foreach my $poc_colname (@poc_colname_sirna_info){
      if(exists $poc_median_zscores{$poc_rowname."_".$poc_colname}){
        print MEDOUT "\t$poc_median_zscores{$poc_rowname.'_'.$poc_colname}";
      }
      else{
        print MEDOUT "\tNA";
      }
    }
    print MEDOUT "\n";

    print REPSOUT "$poc_rowname";
    print REPSOUT "_rep1";
    foreach my $poc_colname (@poc_colname_sirna_info){
      if(exists $poc_replicate_zscores{$poc_rowname."_".$poc_colname."_rep1"}){
        print REPSOUT "\t$poc_replicate_zscores{$poc_rowname.'_'.$poc_colname.'_rep1'}";
      }
      else{
        print REPSOUT "\tNA";
      }
    }
    print REPSOUT "\n";

    print REPSOUT "$poc_rowname";
    print REPSOUT "_rep2";
    foreach my $poc_colname (@poc_colname_sirna_info){
      if(exists $poc_replicate_zscores{$poc_rowname."_".$poc_colname."_rep2"}){
        print REPSOUT "\t$poc_replicate_zscores{$poc_rowname.'_'.$poc_colname.'_rep2'}";
      }
      else{
        print REPSOUT "\tNA";
      }
    }
    print REPSOUT "\n";

    print REPSOUT "$poc_rowname";
    print REPSOUT "_rep3";
    foreach my $poc_colname (@poc_colname_sirna_info){
      if(exists $poc_replicate_zscores{$poc_rowname."_".$poc_colname."_rep3"}){
        print REPSOUT "\t$poc_replicate_zscores{$poc_rowname.'_'.$poc_colname.'_rep3'}";
      }
      else{
        print REPSOUT "\tNA";
      }
    }
    print REPSOUT "\n";
  }
  
  my $link_for_median_pocscores = $configures{'hostname'} . $configures{'configure_export_new_file_path'} . "median_pocscores_export_file_complete_p-11_12_180321.txt";
  my $link_for_replicate_pocscores = $configures{'hostname'} . $configures{'configure_export_new_file_path'} . "replicate_pocscores_export_file_complete_p-11_12_180321.txt";
  
  print "<p></p>";
  print "<a href=\"$link_for_median_pocscores\">Download exported plate 11-12-13 median POC-score data </a></br>";
  print "<p></p>";
  print "<a href=\"$link_for_replicate_pocscores\">Download exported plate 11-12-13 replicate POC-score data </a>"; 
  
  my $collected_pocscores_dr_path = $configures{'WebDocumentRoot'} . $configures{'configure_export_new_file_path'};
  my $collected_pocscores_dr_file_path = $configures{'WebDocumentRoot'} . $configures{'configure_export_new_file_path'} . "collected_pocscores_drugresponse_export_file_p-11_12_180321.txt";
  
  my $dr_file_path;
  open ALLDRFILES, "> $collected_pocscores_dr_file_path" or die "collected_pocscores_dr_file_path: $!\n";
  print ALLDRFILES "screen\tdrug\tlayout\tsf80\tsf50\tsf20\tauc100\tslope\tslope_pval\teInf\tec50\tLOF_pval\tauc100_raw\n";
  foreach my $fpath (@all_summary_files){
    $dr_file_path = $fpath;
    $dr_file_path =~ s/_zscores_summary.txt/_pocscores_drugresponse.txt/;
    $dr_file_path =~ /([^\/]+)[\n\r]?$/;
    my $dr_file_name = $1;
    $dr_file_name =~ s/_pocscores_drugresponse.txt//;
    open DRFILE, "< $dr_file_path" or die "Can't read drug response file $dr_file_path: $!\n";
    while (<DRFILE>) {
      if($_ =~ /drug/) {
        next;
      }
      else {
        print ALLDRFILES "$dr_file_name\t$_"; 
      }
    }
    close DRFILE;  
  }   
  close ALLDRFILES;  
  
  ## script not working
  
 # `cd $collected_pocscores_dr_path && R --vanilla < $configures{'get_auc_sf_scores_script'}`;
  
  print "$page_footer";
  print $q -> end_html;
  
} #end of configure_export subroutine


# ======================
# Subroutine for show_qc
# ======================

sub show_qc {

  print $q -> header ( "text/html" );
  print "$page_header";
 
  print $q -> start_multipart_form ( -method=>"POST" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<h1>Drug screen quality:</h1>";
  
  my $screen_dir_name = $q -> param ( "screen_dir_name" );
  my $plateconf = $q -> param ( "plate_conf" );
  
  print "<b>Screen name: $screen_dir_name</b>";
 
  my $query = "SELECT QC FROM Drug_screen_info WHERE Drug_screen_name = '$screen_dir_name'";	
  my $query_handle = $dbh -> prepare ( $query );
  $query_handle -> execute();
  
  my $qc_col = undef;
  while ( $qc_col = $query_handle -> fetchrow_array ) {
    print "<p></p>";
    if ($qc_col eq "Pass") {
      print "<p></p>";
      print "<div id=\"Message2\"><b>QC: Pass</b></div>";
    }
    elsif ($qc_col eq "Fail") {
      print "<p></p>";
      print "<div id=\"Message\"><b>QC: Fail</b></div>";
    }
    elsif ($qc_col eq "-TBC") {
      print "<p></p>";
	  print "<div id=\"Message3\"><b>Assign QC status:</b></div>";
	  print "<p></p>";
	  
	  print "&nbsp;&nbsp;";

	  print $q -> checkbox( -name=>'Pass',
							-checked=>0,
							#-onclick=>"enableText()",
							-value=>'ON',
							-label=>'Pass' );
				  
	  print "&nbsp;&nbsp;";  
					  
	  print $q -> checkbox( -name=>'Fail',
							-checked=>0,
							#-onclick=>"enableText()",
							-value=>'ON',
							-label=>'Fail');
			
	  my $Pass = $q -> param ( "Pass" );
	  my $Fail = $q -> param ( "Fail" );

	  print "<p></p>";
	  print "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input type=\"submit\" id=\"save_qc_status\" value=\"Submit\" name=\"save_qc_status\" onClick=\"return confirm ('You are about to assign the selected QC status to the screen')\"/>"; 
    }
  }
  print "<p></p>";
  print "<b>Note:- Zprime for controls will be displayed soon</b>";

###########  my $show_qc_page = $configures{'hostname'} . $configures{'rnai_screen_qc_new_path'} . $screen_dir_name . "_controls_qc.png";
  my $scatter_plot_1 = $configures{'hostname'} . $configures{'rnai_screen_qc_new_path'} . $screen_dir_name . "_qc_plot_file_1.png";
  my $scatter_plot_2 = $configures{'hostname'} . $configures{'rnai_screen_qc_new_path'} . $screen_dir_name . "_qc_plot_file_2.png";
  my $scatter_plot_3 = $configures{'hostname'} . $configures{'rnai_screen_qc_new_path'} . $screen_dir_name . "_qc_plot_file_3.png";
  my $drc_figs = $configures{'hostname'} . $configures{'drug_screen_drc_figs_new_path'} . $screen_dir_name . "_pocscore_figures.pdf";
  
 ########### zprime stuff commented out by Aditi 150912 #############
 
 # print "<p>";
 # print "<img src=\"$show_qc_page\" alt=\"QC plots:\">";
 # print "</p>"; 
  print "</td>";
  
	##display separate zprime values
	#print "<td align=left valign=top>\n";
  
	#my $sep_zprime_file = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_sep_zprime_new_path'} . $screen_dir_name . "_separate_zprime.txt";
	#print "<p></p>";
	#print "<p></p>";
	#print "<h2>Zprimes with sicon1, sicon2 or allstar as negative and plk1 as positive controls:</h2>";
	#print "<p></p>";
  
##	print "<table>";
##	print "<th>";
##	print "Replicates";
##	print "</th>";
    
##	print "<th>";
##	print "sicon1";
##	print "</th>";
	
##	print "<th>";
##	print "sicon2";
##	print "</th>";
 ##   
##	print "<th>";
##	print "allstar";
##	print "</th>"; 
  
  #	open ( IN, "< $sep_zprime_file" )
  #  	or die "Cannot open $sep_zprime_file:$!\n";
  #	while ( <IN> ) {
    #	if ($_ =~ /zp_sicon1/) {
    #  		next;
    #	}
    #	my $line = $_;
    	
	#	my( $replicates, $zp_sicon1, $zp_sicon2, $zp_allstar ) = split(/\t/, $line);
    #	$zp_sicon1 = sprintf "%.2f", $zp_sicon1;
    #	$zp_sicon2 = sprintf "%.2f", $zp_sicon2;
    #	$zp_allstar = sprintf "%.2f", $zp_allstar;
      
    #	print "<tr>";
    
    #	print "<td>";
    #	$replicates=~ s/\"//g;
    #	print $replicates;
    #	print "</td>";
    
    #	print "<td align=right>";
    ##	print $zp_sicon1;
    	print "</td>";
    
    #	print "<td align=right>";
    #	print $zp_sicon2;
    #	print "</td>";
    
    #	print "<td align=right>";
    #	print $zp_allstar;
    #	print "</td>";
    
    #	print "</tr>";
  	#}
  	#close IN;
  	
  ###################################	
  	
   	print "</table>";
   	
   	print "<p></p>";
  	print "<p></p>";
  	print "<p></p>";
  	print "<p></p>";
  	print "<p></p>";
  	print "<p></p>";
  	print "<p></p>";
  	
    
    print "<h2>Scatterplots showing correlation between replicates:</h2>";
    
    print "<p></p>";
     
    print "<table>";
    
    print "<img src=\"$scatter_plot_1\" alt=\"Rep1 vs Rep2:\"> &nbsp;&nbsp;&nbsp;&nbsp;";
   
    print "<img src=\"$scatter_plot_2\" alt=\"Rep2 vs Rep3:\"> &nbsp;&nbsp;&nbsp;&nbsp;";
   
    print "<img src=\"$scatter_plot_3\" alt=\"Rep1 vs Rep3:\">";
    
    print "</td>";
    
    print "<p></p>";
  	print "<p></p>";
  	print "<p></p>";
    
 #   print "<h2>Dose response curves:</h2>";
    
  #  print "<p></p>";
     
 #   print "<table>";
    
  #  print "<img src=\"$drc_figs\" > &nbsp;&nbsp;&nbsp;&nbsp;";
    
    print "</td>";
    
  #print "<td align=left valign=top>\n";
  #print "<p>";
  #print "<h1>Reanalysis:</h1>";
  #print "<b>Modify plateconf file for reanalysis:</b>";
  #print "</p>";
  
  ## replace 'siCON1' with 'empty' ##

  #print "<p><p>";
  
  #print $q -> checkbox( -name => 'sicon1_empty',
  #  					-checked => 0,
  # 					    -value => 'ON',
  #  					-label => 'remove siCON1' );

  #print "</p></p>";
  
  ## replace 'siCON2' with 'empty' ##
  
  #print "<p>";
  
  #print $q -> checkbox( -name => 'sicon2_empty',
  #  					-checked => 0,
  # 					    -value => 'ON',
  #  					-label => 'remove siCON2' );

  #print "</p>";
  
  ## replace 'allstar' with 'empty' ##
  
  #print "<p>";
  
  #print $q -> checkbox( -name => 'allstar_empty',
  #  					-checked => 0,
  # 					    -value => 'ON',
  #  					-label => 'remove allstar' );

  #print "</p>";
  
  print $q -> hidden ( -name => 'screen_dir_name',
  					   -value => $screen_dir_name );
  					  
  print $q -> hidden ( -name => 'plate_conf',
  					   -value => $plateconf );				  
  
 ## submit the updated plateconf file for re-analysis ##
                                                
  #print "<p>";
  #print "<input type=\"submit\" id=\"save_new_screen\" value=\"Reanalyse\" name=\"save_new_screen\"/>";
  #print "</p>"; 
  
  #print "</td>";
  print "</tr>\n";
  print "</table>";
  
  
  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html;
  
} #end of show_qc subroutine 

# ===============================
# Subroutine for saving QC status
# ===============================

sub save_qc_status {
  print $q -> header ( "text/html" );
  print "$page_header";
  
  my $screen_dir_name = $q -> param ( "screen_dir_name" );
  my $plateconf = $q -> param ( "plate_conf" );
  my $Pass = $q -> param ( "Pass" );
  my $Fail = $q -> param ( "Fail" );

  print "<p></p>";
  print "<p></p>";
  
   if($Pass eq 'ON'){
  
    my $query_p = "UPDATE
				Drug_screen_info SET
				QC = 'Pass' WHERE
				Drug_screen_name = '$screen_dir_name'";
				
	my $query_handle_p = $dbh -> prepare ( $query_p );
	$query_handle_p->execute();
	
	print "<div id=\"Message3\"><p><b>QC status for $screen_dir_name - 'Pass'</b></p></div>";
	}
	 if($Fail eq 'ON'){
  
    my $query_f = "UPDATE
				Drug_screen_info SET
				QC = 'Fail' WHERE
				Drug_screen_name = '$screen_dir_name'";
				
	my $query_handle_f = $dbh -> prepare ( $query_f );
	$query_handle_f->execute();
	
	print "<div id=\"Message3\"><p><b>QC status for $screen_dir_name - 'Fail'</b></p></div>";
  	}
  
  print "$page_footer";
  print $q -> end_html;
  
} #end of save_qc_status subroutine


# ====================================
# Subroutine for computing drug effect
# ====================================

sub compute_drug_effect { 
  print $q -> header ( "text/html" );
   my $page_header_for_computing_drug_effect = "<html>
   												  <head>
													<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />
													<title>GFT DRUG database</title>
													<link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"/css/rnaidb.css\" />
													<meta name=\"viewport\" content=\"width=1000, initial-scale=0.5, minimum-scale=0.45\" />
				   						  			<link rel=\"stylesheet\" href=\"http://code.jquery.com/ui/1.11.1/themes/smoothness/jquery-ui.css\">
				    					  			<script src=\"http://code.jquery.com/jquery-1.10.2.js\"></script>
				   						  			<script src=\"http://code.jquery.com/ui/1.11.1/jquery-ui.js\"></script>
				   						  			 <script>
				   						   function make_dmsoID_Blank() {
										    var b = document.getElementById( \"DMSO_id\" );
										    if (b.value ==\"Enter screen ID\")
										    {
										    	b.value = \"\";
										    }
										  }
										   function make_drugID_Blank() {
										    var b = document.getElementById( \"DRUG_id\" );
										    if (b.value ==\"Enter screen ID\")
										    {
										    	b.value = \"\";
										    }
										  }
										  function checkForm ( form ) {
										   if (( form[\"dmso_id\"].value == \"Enter screen ID\") || ( form[\"dmso_id\"].value == \"\")) {
										      alert ( \"Please enter Drug screen ID 1\" );
										      return false;
										    }
										     if (( form[\"drug_id\"].value == \"Enter screen ID\") || ( form[\"drug_id\"].value == \"\")) {
										      alert ( \"Please enter Drug screen ID 2\" );
										      return false;
										    }
										        var answer = confirm(\"Click 'Cancel' if you are not sure that you selected the correct screen IDs for computing drug effect\")
										  	return answer;
										  }
										  </script>   
				   						  		</head>
				   						  	<body>
				   						  <div id=\"Box\"></div><div id=\"MainFullWidth\">
				   						  <a href=$configures{'hostname'}><img src=\"http://gft.icr.ac.uk/images/ICR_GFT_drugDB_logo_placeholder.png\" width=415px height=160px></a>
				   						  <p>
				   						  <a href=\"/cgi-bin/$script_name?add_new_screen=1\">Add new screen</a>\&nbsp;\&nbsp;
				    					  <a href=\"/cgi-bin/$script_name?show_all_screens=1\">Show all screens</a>\&nbsp;\&nbsp;
				    					  <a href=\"/cgi-bin/$script_name?compute_drug_effect=1\">Drug effect analysis</a>\&nbsp;\&nbsp;
								    	  <a href=\"/cgi-bin/$script_name?show_all_drug_effect_screens=1\">Drug effect results</a>\&nbsp;\&nbsp;
								    	  <a href=\"/cgi-bin/$script_name?limma_analysis=1\">Limma analysis</a>\&nbsp;\&nbsp;
								    	  <a href=\"/cgi-bin/$script_name?show_all_limma_screens=1\">Limma results</a>\&nbsp;\&nbsp;
				   						  <a href=\"/cgi-bin/$script_name?configure_export=1\">Configure export</a>\&nbsp;\&nbsp;
				   						  </p>";
				   						  
  print "$page_header_for_computing_drug_effect";
  print "<p></p>"; 
  print "<p></p>"; 
  print "<p></p>"; 
  print "<p></p>"; 

  print "<h1>Drug effect analysis:</h1>";
    
  print $q -> start_multipart_form ( -method => "POST",
  									 -name => "computeDrugEffect",
  									 -onSubmit => "return checkForm( this )" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";
  
  ##
  ## add main screen info here ##
  ## 
  
 print "Drug screen 1:<br />";
   						   
  print $q -> textfield ( -name => "dmso_id",
                         -value => 'Enter screen ID',
                         -size => "30",
                         -maxlength => "40",
                         -onClick => "make_dmsoID_Blank()",
                         -id => "DMSO_id" );
 
  print "<p></p>"; 
                                                  
  print "Drug screen 2:<br />";
  
  print $q -> textfield ( -name => "drug_id",
                         -value => 'Enter screen ID',
                         -size => "30",
                         -maxlength => "40",
                         -onClick => "make_drugID_Blank()",
                         -id => "DRUG_id" );
                         
  my $dmso_id = $q -> param( "dmso_id" );
  my $drug_id = $q -> param( "drug_id" );
  
  print "<p></p>";

  print "<input type=\"submit\" id=\"save_drug_effect_screens\" value=\"Compute drug effect\" name=\"save_drug_effect_screens\" />";
  print "</p>";
  
  print "<td>\n";
  print "</tr>\n";
  print "</table>\n";
  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html; 
  
} #end of compute_drug_effect subroutine


# ========================================
# Subroutine for saving drug effect screen
# ========================================

sub save_drug_effect_screens {
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Saving screens analysed for drug effect:</h1>";
  
  my $dmso_id = $q -> param( "dmso_id" );
  my $drug_id = $q -> param( "drug_id" );
  
  my $short_dmso_id = $dmso_id;
  $short_dmso_id =~ s/gft-D//g;
  
  my $summary_file_path_1;
  my $summary_file_dest_1;
  my $summary_file_name_1;
  my $dmso_file;

  my $query = "SELECT 
     Summary_file_path FROM 
  	 Drug_screen_info WHERE 
  	 Drug_screen_info_ID = $short_dmso_id";
  	
  my $query_handle = $dbh -> prepare ( $query );
     				#or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle->execute();
  while ( $summary_file_path_1 = $query_handle -> fetchrow_array ) {
  $summary_file_dest_1 = $summary_file_path_1;
  $summary_file_dest_1 =~ s/.*\///;
  $dmso_file = $summary_file_dest_1;
  #$summary_file_name =~ s{\.[^.]+$}{};
  $dmso_file =~ s/_zscores_summary.*$//g;
  }
  
  my $short_drug_id = $drug_id;
  $short_drug_id =~ s/gft-D//g;
  
  my $summary_file_path_2;
  my $summary_file_dest_2;
  my $summary_file_name_2;
  my $drug_file;
  
  $query = "SELECT 
     Summary_file_path FROM 
  	 Drug_screen_info WHERE 
  	 Drug_screen_info_ID = $short_drug_id";
  	
  $query_handle = $dbh -> prepare ( $query );
     				#or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle->execute();
  while ( $summary_file_path_2 = $query_handle -> fetchrow_array ) {
  $summary_file_dest_2 = $summary_file_path_2;
  $summary_file_dest_2 =~ s/.*\///;
  $drug_file = $summary_file_dest_2;
  #$summary_file_name =~ s{\.[^.]+$}{};
  $drug_file =~ s/_zscores_summary.*$//g;
  }
  
  my $scrDir_path = $configures{'screenDir_path'};
  my $screen_DE_dir_name = $q -> param( "screen_DE_dir_name" );
    
  if ( not defined ( $screen_DE_dir_name ) ) {
  
    $screen_DE_dir_name = "drugEffect_" . $dmso_file . "_and_" . $drug_file;
  }
  my $DE_file_path = "$scrDir_path/$screen_DE_dir_name/";
  
  if ( ! -e $DE_file_path ) {
  
    mkdir( "$DE_file_path" ); 
    
    `chmod -R 777 $DE_file_path`;
    `chown -R agulati:agulati $DE_file_path`;
    
  my $dmsoFile =  $dmso_file . "_zscores_summary_with_rep_zscores.txt";
  my $drugFile =  $drug_file . "_zscores_summary_with_rep_zscores.txt";
  
  my $dmsoSummaryFile =  $dmso_file . "_zscores_summary.txt";
  my $drugSummaryFile =  $drug_file . "_zscores_summary.txt";
  
  my $dmsoSummaryFilePath = $scrDir_path . "/" . $dmso_file . "/". $dmsoSummaryFile;
  my $drugSummaryFilePath = $scrDir_path . "/" . $drug_file . "/". $drugSummaryFile;
  
  my $summaryFile1 = "summaryFile1_" . $dmsoFile;
  my $summaryFile2 = "summaryFile2_" . $drugFile;
    
  my $dmsoFilePath = $scrDir_path . "/" . $dmso_file . "/". $dmsoFile;
  my $drugFilePath = $scrDir_path . "/" . $drug_file . "/". $drugFile;
  
  `cp $dmsoFilePath $DE_file_path`;
  `cp $drugFilePath $DE_file_path`;

#  print $configures{ 'compute_drug_effect' };
#  while(my ($key, $value) = each %configures){
 #   print "key is $key<br>";
 #   print "value is $value<br>";
 # }

  my $run_de_analysis_script = `cd $DE_file_path && mv $dmsoFile $summaryFile1 && mv $drugFile $summaryFile2 && R --vanilla < $configures{'compute_drug_effect'}`;
  
  my $drugEffectFilePath = $DE_file_path.$screen_DE_dir_name.".txt";
  
  my $drug_effect_result_new_path = $configures{'WebDocumentRoot'} . $configures{'drug_effect_new_path'};

  `cp $drugEffectFilePath $drug_effect_result_new_path`;
  
  my $link_to_drug_effect_folder = $configures{'hostname'} . $configures{'drug_effect_new_path'} . $screen_DE_dir_name.".txt";
  
  print "<p></p>";
  
  print "<p></p>";
  
  print "<p>Calculated drug effect for:</p>";
  print "<p><b>Screen 1:- $dmso_file</b></p>";
  print "<p><b>Screen 2:- $drug_file</b></p>";
  
  print "<p></p>";
  
  print "<a href = \"$link_to_drug_effect_folder\">View drug effect results</a>";
  
  my $query = "INSERT INTO 
				 Drug_effect (
				 Link_to_drug_effect_file,
				 Drug_screen_info_Drug_screen_info_ID_1,
				 Drug_screen_info_Drug_screen_info_ID_2,
				 Drug_screen_name_1,
				 Drug_screen_name_2
				 ) VALUES (
				 '$link_to_drug_effect_folder',
				 '$short_dmso_id',
				 '$short_drug_id',
				 '$dmso_file',
				 '$drug_file'
				 )";
  
  my $query_handle = $dbh->prepare( $query );
   					    #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute(); 


  }
  else {
    my $message = "Cannot make new drug effect directory, $screen_DE_dir_name as it already exists.";
 	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    die "Cannot make new Drug Effect directory $screen_DE_dir_name in $scrDir_path: $!";
    return;
  }
 
  print "$page_footer";
  print $q -> end_html;
  
} #end of save_drug_effect_screens subroutine


# ==========================================================
# Subroutine for displaying screens analysed for drug effect
# ==========================================================

sub show_all_drug_effect_screens { 
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Screens analysed for drug effect:</h1>";
    
  print $q -> start_multipart_form ( -method => "POST" ); 
  
  #print "<table width = 100%>\n";
  print "<table border=\"1\" style=\"width:100%\">";
  print "<tr>\n";
  print "<td align=left valign=top>\n";
  
  my $drug_id = $q -> param( "drug_id" );
  my $screen_dir_name = $q -> param ( "screen_dir_name" );
  
 my $query = "SELECT
   CONCAT('gft-D',Drug_screen_info_Drug_screen_info_ID_1),
   CONCAT('gft-D',Drug_screen_info_Drug_screen_info_ID_2),
   Drug_screen_name_1,
   Drug_screen_name_2,
   Link_to_drug_effect_file FROM
   Drug_effect ORDER BY Drug_effect_ID";
  	
  my $query_handle = $dbh -> prepare ( $query );
  $query_handle -> execute();
  
  print "<th>";
  print "ID1";
  print "</th>";
  
  print "<th>";
  print "ID2";
  print "</th>";
  
  print "<th>";
  print "Drug screen1";
  print "</th>";
  
  print "<th>";
  print "Drug screen2";
  print "</th>";
  
  print "<th>";
  print "View/download drug effect results";
  print "</th>";
 
  while ( my @row = $query_handle -> fetchrow_array ) {
  
    print "<tr>";
    
    print "<td align=left valign=top>\n";
    
    print "<td>";
    print "<a href=" . $configures{'hostname'} . "cgi-bin/$script_name?show_all_screens=1\&screen_dir_name=$row[2]>$row[0]</a>";
    print "</td>"; 
    
    print "<td>";
    print "<a href=" . $configures{'hostname'} . "cgi-bin/$script_name?show_all_screens=1\&screen_dir_name=$row[3]>$row[1]</a>";
    print "</td>"; 
    
    print "<td>";
    print "$row[2]";
    print "</td>"; 
    
    print "<td>";
    print "$row[3]";
    print "</td>"; 
   
    print "<td>";
    print "<a href=\"$row[4]\" >drugEffect</a>";
    print "</td>";  
    
  } #end of while loop
  
  print "</table>"; 
    
  print "<td>\n";
  print "</tr>\n";
  print "</table>\n";
  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html; 
  
} # end of show_all_drug_effect_screens subroutine


# =============================
# Subroutine for Limma analysis
# =============================

sub limma_analysis { 
  print $q -> header ( "text/html" );
   my $page_header_for_limma_analysis = "<html>
   												  <head>
													<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />
													<title>GFT DRUG database</title>
													<link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"/css/rnaidb.css\" />
													<meta name=\"viewport\" content=\"width=1000, initial-scale=0.5, minimum-scale=0.45\" />
				   						  			<link rel=\"stylesheet\" href=\"http://code.jquery.com/ui/1.11.1/themes/smoothness/jquery-ui.css\">
				    					  			<script src=\"http://code.jquery.com/jquery-1.10.2.js\"></script>
				   						  			<script src=\"http://code.jquery.com/ui/1.11.1/jquery-ui.js\"></script>
				   						  			<script>
													  function make_dmsoID_Blank() {
													   var b = document.getElementById( \"DMSO_id\" );
													   if (b.value ==\"Enter screen ID\")
													   {
														   b.value = \"\";
													   }
													 }
													  function make_drugID_Blank() {
													   var b = document.getElementById( \"DRUG_id\" );
													   if (b.value ==\"Enter screen ID\")
													   {
														   b.value = \"\";
													   }
													 }
													 function checkForm ( form ) {
													  if (( form[\"dmso_id\"].value == \"Enter screen ID\") || ( form[\"dmso_id\"].value == \"\")) {
														 alert ( \"Please enter Drug screen ID 1\" );
														 return false;
													   }
														if (( form[\"drug_id\"].value == \"Enter screen ID\") || ( form[\"drug_id\"].value == \"\")) {
														 alert ( \"Please enter Drug screen ID 2\" );
														 return false;
													   }
														var answer = confirm(\"Click 'Cancel' and check if you are not sure that you selected the correct screen IDs for Limma analysis\")
													   return answer;
													 }
												</script>   
				   						  	  </head>
				   						  	<body>
				   						  <div id=\"Box\"></div><div id=\"MainFullWidth\">
				   						  <a href=$configures{'hostname'}><img src=\"http://gft.icr.ac.uk/images/ICR_GFT_drugDB_logo_placeholder.png\" width=415px height=160px></a>
				   						  <p>
				   						  <a href=\"/cgi-bin/$script_name?add_new_screen=1\">Add new screen</a>\&nbsp;\&nbsp;
				    					  <a href=\"/cgi-bin/$script_name?show_all_screens=1\">Show all screens</a>\&nbsp;\&nbsp;
				    					  <a href=\"/cgi-bin/$script_name?compute_drug_effect=1\">Drug effect analysis</a>\&nbsp;\&nbsp;
								    	  <a href=\"/cgi-bin/$script_name?show_all_drug_effect_screens=1\">Drug effect results</a>\&nbsp;\&nbsp;
								    	  <a href=\"/cgi-bin/$script_name?limma_analysis=1\">Limma analysis</a>\&nbsp;\&nbsp;
								    	  <a href=\"/cgi-bin/$script_name?show_all_limma_screens=1\">Limma results</a>\&nbsp;\&nbsp;
				   						  <a href=\"/cgi-bin/$script_name?configure_export=1\">Configure export</a>\&nbsp;\&nbsp;
				   						  </p>";
				   						  
  print "$page_header_for_limma_analysis";
  print "<h1>Limma analysis:</h1>";
    
  print $q -> start_multipart_form ( -method => "POST",
  									 -name => "computeLimma",
  									 -onSubmit => "return checkForm( this )" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";
  
  ##
  ## add main screen info here ##
  ## 
 
 print "Drug isogenic screen 1:<br />";
  
 print $q -> textfield ( -name => "dmso_id",
                         -value => 'Enter screen ID',
                         -size => "30",
                         -maxlength => "40",
                         -onClick => "make_dmsoID_Blank()",
                         -id => "DMSO_id" );
 
  print "<p></p>"; 
                                                  
  print "Drug isogenic screen 2:<br />";
  
  print $q -> textfield ( -name => "drug_id",
                         -value => 'Enter screen ID',
                         -size => "30",
                         -maxlength => "40",
                         -onClick => "make_drugID_Blank()",
                         -id => "DRUG_id" );
                                          
  my $dmso_id = $q -> param( "dmso_id" );
  my $drug_id = $q -> param( "drug_id" );
  
  print "<p></p>";
  
  print "<input type=\"submit\" id=\"save_limma_analysis\" value=\"Run Limma analysis\" name=\"save_limma_analysis\"/>";
  print "</p>";
  
  print "<td>\n";
  print "</tr>\n";
  print "</table>\n";
  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html; 
  
} #end of limma_analysis subroutine

# ===================================
# Subroutine for saving limma results
# ===================================

sub save_limma_analysis {
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Saving limma analysis results:</h1>";
  
   my $dmso_id = $q -> param( "dmso_id" );
  my $drug_id = $q -> param( "drug_id" );
  
  my $short_dmso_id = $dmso_id;
  $short_dmso_id =~ s/gft-D//g;
  
  my $summary_file_path_1;
  my $summary_file_dest_1;
  my $summary_file_name_1;
  my $dmso_file;

  my $query = "SELECT 
     Summary_file_path FROM 
  	 Drug_screen_info WHERE 
  	 Drug_screen_info_ID = $short_dmso_id";
  	
  my $query_handle = $dbh -> prepare ( $query );
     				#or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle->execute();
  while ( $summary_file_path_1 = $query_handle -> fetchrow_array ) {
  $summary_file_dest_1 = $summary_file_path_1;
  $summary_file_dest_1 =~ s/.*\///;
  $dmso_file = $summary_file_dest_1;
  #$summary_file_name =~ s{\.[^.]+$}{};
  $dmso_file =~ s/_zscores_summary.*$//g;
  }
  
  my $short_drug_id = $drug_id;
  $short_drug_id =~ s/gft-D//g;
  
  my $summary_file_path_2;
  my $summary_file_dest_2;
  my $summary_file_name_2;
  my $drug_file;
  
  $query = "SELECT 
     Summary_file_path FROM 
  	 Drug_screen_info WHERE 
  	 Drug_screen_info_ID = $short_drug_id";
  	
  $query_handle = $dbh -> prepare ( $query );
     				#or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle->execute();
  while ( $summary_file_path_2 = $query_handle -> fetchrow_array ) {
  $summary_file_dest_2 = $summary_file_path_2;
  $summary_file_dest_2 =~ s/.*\///;
  $drug_file = $summary_file_dest_2;
  #$summary_file_name =~ s{\.[^.]+$}{};
  $drug_file =~ s/_zscores_summary.*$//g;
  }
  
  
  my $scrDir_path = $configures{'screenDir_path'};
  my $screen_limma_dir_name = $q -> param( "screen_limma_dir_name" );
  
  my $file = $scrDir_path."/".$drug_file."/".$drug_file."_zscores_summary.txt";
  
  my $query_gene = "SELECT 
     Gene_name_if_isogenic,
     Isogenic_mutant_description FROM 
  	 Drug_screen_info WHERE 
  	 Summary_file_path = $file";
  	
  my $query_handle_gene = $dbh -> prepare ( $query_gene );
  $query_handle_gene -> execute();
  my @gene_info=();
  my $gene;
  while ( @gene_info = $query_handle_gene -> fetchrow_array ) {
    $gene = $gene_info[0];
  }

  print"<p>Gene:$gene</p>";
  
  if ( not defined ( $screen_limma_dir_name ) ) {
   
    $screen_limma_dir_name = "limma_" . $dmso_file . "_and_" . $drug_file;
  }
  my $limma_file_path = "$scrDir_path/$screen_limma_dir_name/";
  
  if ( ! -e $limma_file_path ) {
  
    mkdir( "$limma_file_path" ); 
    
    `chmod -R 777 $limma_file_path`;
    `chown -R agulati:agulati $limma_file_path`;
    
  	my $dmsoFile =  $dmso_file . "_zscores_summary_with_rep_zscores.txt";
  	my $drugFile =  $drug_file . "_zscores_summary_with_rep_zscores.txt";
  
  	my $dmsoSummaryFile =  $dmso_file . "_zscores_summary.txt";
  	my $drugSummaryFile =  $drug_file . "_zscores_summary.txt";
  
  	my $dmsoSummaryFilePath = $scrDir_path . "/" . $dmso_file . "/". $dmsoSummaryFile;
  	my $drugSummaryFilePath = $scrDir_path . "/" . $drug_file . "/". $drugSummaryFile;
  
  	my $summaryFile1 = "summaryFile1_" . $dmsoFile;
  	my $summaryFile2 = "summaryFile2_" . $drugFile;
    
  	my $dmsoFilePath = $scrDir_path . "/" . $dmso_file . "/". $dmsoFile;
  	my $drugFilePath = $scrDir_path . "/" . $drug_file . "/". $drugFile;
  
  	`cp $dmsoFilePath $limma_file_path`;
  	`cp $drugFilePath $limma_file_path`;
  	
  	open GENEFILE, '>', $limma_file_path."gene.txt" 
      or die "Cannot open $limma_file_path:$!\n";
     print "$gene\n";
	close GENEFILE;
	
  	my $run_limma_analysis_script = `cd $limma_file_path && mv $dmsoFile $summaryFile1 && mv $drugFile $summaryFile2 && R --vanilla < $configures{'limma_analysis'}`;
  
  	my $limmaFilePath = $limma_file_path.$screen_limma_dir_name.".txt";
  	my $limmaPlotPath = $limma_file_path.$screen_limma_dir_name.".pdf";
  
  	my $limma_result_new_path = $configures{'WebDocumentRoot'} . $configures{'limma_new_path'};

  	`cp $limmaFilePath $limma_result_new_path`;
  	`cp $limmaPlotPath $limma_result_new_path`;
  
  	my $link_to_limma_folder = $configures{'hostname'} . $configures{'limma_new_path'} . $screen_limma_dir_name.".txt";
  	my $link_to_limma_plot = $configures{'hostname'} . $configures{'limma_new_path'} . $screen_limma_dir_name.".pdf";
  	
  	print "<p></p>";
  
  	print "<p></p>";
  
  	print "<p>Limma analysis results for:</p>";
  	print "<p><b>Drug isogenic screen 1:- $dmso_file</b></p>";
  	print "<p><b>Drug isogenic screen 2:- $drug_file</b></p>";
  
  	print "<p></p>";
  
  	print "<a href = \"$link_to_limma_folder\">View limma table</a>";
  	print "<p></p>";
  	print "<a href = \"$link_to_limma_plot\">View limma plot</a>";
  
     my $query = "INSERT INTO 
				   Limma_table (
				   Link_to_limma_file,
				   Link_to_limma_plots,
				   Drug_screen_info_Drug_screen_info_ID_1,
				   Drug_screen_info_Drug_screen_info_ID_2,
				   Drug_screen_name_1,
				   Drug_screen_name_2
				   ) VALUES (
				   '$link_to_limma_folder',
				   '$link_to_limma_plot',
				   '$short_dmso_id',
				   '$short_drug_id',
				   '$dmso_file',
				   '$drug_file'
				   )";
				   	
  my $query_handle = $dbh -> prepare ( $query );
  $query_handle -> execute();
	
  }
  else {
    my $message = "Cannot make new Limma analysis directory, $screen_limma_dir_name as it already exists.";
 	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    die "Cannot make new Limma analysis directory $screen_limma_dir_name in $scrDir_path: $!";
    return;
  }
  
  print "$page_footer";
  print $q -> end_html;
  
} #end of save_limma_analysis subroutine


# =======================================
# Subroutine for displaying limma results
# =======================================

sub show_all_limma_screens { 
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Limma analysis results:</h1>";
    
  print $q -> start_multipart_form ( -method => "POST" ); 
  
  #print "<table width = 100%>\n";
  print "<table border=\"1\" style=\"width:100%\">";
  print "<tr>\n";
  print "<td align=left valign=top>\n";
  
 my $query = "SELECT
				 CONCAT('gft-D',Drug_screen_info_Drug_screen_info_ID_1),
				 CONCAT('gft-D',Drug_screen_info_Drug_screen_info_ID_2),
				 Drug_screen_name_1,
				 Drug_screen_name_2,
				 Link_to_limma_file,
				 Link_to_limma_plots FROM
				 Limma_table ORDER BY Limma_table_ID";
  	
  my $query_handle = $dbh -> prepare ( $query );
  $query_handle -> execute();
 
  print "<th>";
  print "ID1";
  print "</th>";
  
  print "<th>";
  print "ID2";
  print "</th>";
  
  print "<th>";
  print "Drug isogenic screen1";
  print "</th>";
  
  print "<th>";
  print "Drug isogenic screen2";
  print "</th>";
  
  print "<th>";
  print "View/download Limma analysis table";
  print "</th>";
   
  print "<th>";
  print "View/download Limma analysis plots";
  print "</th>";
 
  while ( my @row = $query_handle -> fetchrow_array ) {
  
    print "<tr>";
    
    print "<td align=left valign=top>\n";
    
    print "<td>";
    print "<a href=" . $configures{'hostname'} . "cgi-bin/$script_name?show_all_screens=1\&screen_dir_name=$row[2]>$row[0]</a>";
    print "</td>"; 
    
    print "<td>";
    print "<a href=" . $configures{'hostname'} . "cgi-bin/$script_name?show_all_screens=1\&screen_dir_name=$row[3]>$row[1]</a>";
    print "</td>"; 
    
    print "<td>";
    print "$row[2]";
    print "</td>"; 
    
    print "<td>";
    print "$row[3]";
    print "</td>"; 
   
    print "<td>";
    print "<a href=\"$row[4]\" >LimmaTable</a>";
    print "</td>";  
    
    print "<td>";
    print "<a href=\"$row[5]\" >LimmaPlot</a>";
    print "</td>";  
        
  } #end of while loop

  print "</table>"; 
    
  print "<td>\n";
  print "</tr>\n";
  print "</table>\n";
  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html; 
  
} # end of show_all_drug_effect_screens subroutine

##########################################################################################


sub run_export {
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Your data:</h1>";
  
  # recieve data from configure_export
  # and output data as a text file
  
  print "$page_footer";
  print $q -> end_html;
}


##########################################################################################


sub add_new_user {
  # get user, pass and oneTimePass, hash user.pass and store
  # set a cookie then redirect to view_all_projects
  my $q = shift;
  my $user = $q -> param ('user');
  my $pass = $q -> param ('pass');
#  my $auth_code = $q -> param ('auth_code');
    
#  my $correct_auth_code = md5_hex($user . $auth_code_salt);
#  die "Failed login...\n" unless $auth_code eq $correct_auth_code;
  
  unless($user =~ /^([A-Za-z0-9\._+]{1,1024})$/) {
    &login("username must be alphanumeric (plus dots and underscores) and must not exceed 1024 characters");
    exit(1);
  }
  unless($pass =~ /^.{1,4096}$/) {
    &login("password must not exceed 4096 characters");
  }
  
  my $user_pass_hash = md5_hex($user . $pass . $auth_code_salt);
  for(my $i = 0; $i <= $num_hash_itts; $i ++) {
    my $user_pass_hash = md5_hex($user_pass_hash);
  }
  #open USERS, ">> ./users.txt" or warn "can't append to the file with user names file: $!\n";
  #print "$user\t$user_pass_hash\n";
  #close USERS;

#  &set_cookie($user_pass_hash);

  print $q -> header("text/html");
  print $q -> start_html();
  print "<h1>New User:</h1>";
  print "$user<br>$user_pass_hash<br>";
  print $q -> end_html();
  exit(0);
}
  
sub authenticate_login_key {
  my $login_key = shift;
  open USERS, "< ./users.txt" or die "can't open the file with the list of user names: $!\n";

#
#
#  print "OPENED USERS FILE...<br>";
#
#
#

  my $user = undef;
  while (<USERS>) {
    my ($stored_user, $stored_hash) = split(/[\t ]+/);
    chomp($stored_hash);
    if ($stored_hash eq /$login_key/){$user = $stored_user;}
  }
  close USERS;
  &login() unless defined($user);
  return $user;  
}
 
sub authenticate_user {
  my $q = shift;
  my $user = $q -> param('user');
  my $pass = $q -> param('pass');
  my $login_message = $q -> param('login_message');
  unless($user =~ /^([A-Za-z0-9\._+]{1,1024})$/){
    die "username must be alphanumeric (plus dots and underscores) and must not exceed 1024 characters";
    exit(1);
  }
  unless($pass =~ /^.{1,4096}$/){
    die "password must not exceed 4096 characters";
  }
  my $user_pass_hash = md5_hex($user . $pass . $auth_code_salt);
  for(my $i = 0; $i <= $num_hash_itts; $i ++){
    my $user_pass_hash = md5_hex($user_pass_hash);
  }
  open USERS, "< /usr/lib/cgi-bin/users.txt" or die "can't open the file with the list of user names: $!\n";
  
#
#
#  print "OPENED USERS FILE...<br>";
#
#
#
  
  my $login_OK = 0;
  while (<USERS>){
    my ($stored_user, $stored_hash) = split(/[\t ]+/);
    chomp($stored_hash);
    $login_OK = 1 if $stored_hash =~ /$user_pass_hash/;
  }
  close USERS;
  if ($login_OK == 1){
    &set_cookie($user_pass_hash);
    return $user;
  }
  else{
    $q -> param(
      -name => "login_message",
      -value => "Login failed - please check your username and password are correct"
    );
    &login($q);
    exit(1);
  }
}


sub login{
  my $message = $q -> param('login_message');
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>GFT DRUG Database login:</h1>\n";
  print "<p>$message</p>\n" if defined $message;
  print "<table width = 100%><tr><td align=left valign=top>";
  print $q -> startform (-method=>'POST');
  print "<p>";
  print "<b>Please log in:</b>";
  print "</p>";
  print "Username: &nbsp;&nbsp;";
  print $q -> textfield (-name => "user", -size => 20);
  print "</p>";
  print "<p>";
  print "Password: &nbsp;&nbsp;";
  print $q -> password_field (-name => "pass", -size => 20);
  print "</p>";
  print "<p>Please note - this site uses cookies...</p>\n";
  print $q -> submit (-name => "authenticate_user", -value => "login...");
  print $q -> endform;
  print "<hr />";
  print "<p>";
  print "<b>Or create a new account:</b><br>";
  print "</p>";
  print $q -> startform (-method=>'POST');
  print "<p>";
  print "username: &nbsp;&nbsp;";
  print $q -> textfield (-name => "user", -size => 20);
  print "</p>";
  print "<p>";
  print "Password: &nbsp;&nbsp;";
  print $q -> password_field (-name => "pass", -size => 20);
  print "</p>";
  print "<p>";
  print "Authentication code: &nbsp;&nbsp;";
  print $q -> textfield (-name => "auth_code", -size => 20);
  print "</p>";
  print "&nbsp;";
  print $q -> submit (-name => "add_new_user", -value => "create new account");
  print $q -> endform;
  print "</td></tr></table></div>";
  print $q -> end_html;
  exit(0);
}

sub set_cookie{
  my $login_key = shift;

  my $cookie = $q -> cookie( -name => "login_key",
                             -value => $login_key
                             );

  print $q -> redirect(
    -url => "/cgi-bin/$script_name?add_new_screen=1",
    -cookie => $cookie
    );
  exit(0);
}

sub logout{

  my $cookie = $q -> cookie( -name => "login_key",
                             -value => "Expired",
                             -expires => "-1d"
                             );

  print $q -> redirect(
    -url => "/cgi-bin/$script_name",
    -cookie => $cookie
    );

  exit(0);
}



