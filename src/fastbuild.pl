#!/usr/bin/env perl

# Aux script for fast building EC-Artifactory without Ant/make/Gradle/mvn etc.

use File::Path 'rmtree';
use File::Copy;
use File::Glob ':bsd_glob';
use Cwd;

use File::Spec;
use XML::XPath;
use XML::XPath::Node::Element;
use XML::XPath::Node::Text;


# Initial values
my $out_base_dir = 'OUT';
my @jar_dirs = qw(htdocs META-INF pages); # Plugin's top level dirs

## Substitution for regex
# (!) Arrays must have same length 
@pats = qw/\@PLUGIN_KEY\@ \@PLUGIN_VERSION\@ \@PLUGIN_NAME\@/;
@spat = qw/EC-Artifactory 0.0.1.12345 EC-Artifactory-0.0.1.12345/;

# work directory
my $plugin_dir = cwd();

# Chech if here is mandatory file
die "[ERR] - There is no mandatory file 'project.xml'\n" if !(-e 'project.xml');

## Creating plugin directory structure

# Cleaning up output directory
if (-d $out_base_dir) {
	print "[INFO] - Temporary directory exist, cleaninig...\n";
	# May warn 'premissin denied' is subdir is busy
	rmtree(["$out_base_dir"]);
	print "[INFO] - Cleaning DONE\n";	
}

# Find files & dirs recursive
sub loopDir {
	 local($dir, $margin, $filter) = @_;
	 chdir($dir) || die "Cannot chdir to $dir\n";
	 local(*DIR);
	 opendir(DIR, ".");
	 while ($f=readdir(DIR)) {
		next if ($f eq "." || $f eq "..");
		
		if (defined $filter) {
			push(@fset, map { Cwd::abs_path($_) } bsd_glob "$f") if ((-f $f)&&($f =~ m/((.*?)\.($filter))/));
		}
		else {
			push(@fset, map { Cwd::abs_path($_) } bsd_glob "$f") if (-f $f);
		}

		# In case when we need dirs also
		push(@jar_dirs, map { $dir."/".$_ } bsd_glob "$f") if (-d $f);      
		
		if (-d $f) { loopDir($f,"", $filter); }
	}
	closedir(DIR);
	chdir("..");
}

# Append subdirs of top-level project dirs to list
foreach (@jar_dirs) {
	loopDir($_, "");

	chdir $plugin_dir;
}

# Adding plugin root dir
push(@dirs, $out_base_dir);
# Final list
foreach (@jar_dirs) { push(@dirs, $out_base_dir."/".$_); }

# Create list of necessary dirs
foreach (@dirs) {
	if (-d) {
		print "[INFO] - File $_ already exist, skipping...\n";
	}
	else {
		mkdir or die $!;	
		print "[INFO] - Created dir $_\n";
	}
}

# Copy files from source dirs to created out dirs
foreach (@jar_dirs) {
	@d = bsd_glob "$_/*.*";
	foreach my $dfile(@d) {
		my $dst = $out_base_dir."/".$dfile;
		if (!(-f $dst)) {
			copy($dfile, $dst) or die $!;
			print "[INFO] - $dst copied\n";				
		}
		else {
			print "[WARN] - File already $dst!\n";
		}
	}
}


### Processing project.xml

# This part based on buildProject-mvn.pl script form SDK. Please refer to it

print "[INFO] - Processing 'project.xml' file...";

# Given a node, name, and value, create a new XML element and attach it to the
# parent node.
sub addXmlElement($$$) {
	my ($node, $name, $value) = @_;
	my $element = XML::XPath::Node::Element->new($name);
	$element->appendChild(XML::XPath::Node::Text->new($value));
	$node->appendChild($element);
}

# Read the manifest of files to merge into the project.xml

my  $manifest = File::Spec->catfile($plugin_dir, 'manifest.pl');
our @files;

unless (my $return = do $manifest) {
	die "couldn't parse $manifest: $@" if $@;
	die "couldn't do $manifest: $!"    unless defined $return;
	die "couldn't run $manifest"       unless $return;
}

my $xpath = new XML::XPath(filename => File::Spec->catfile($plugin_dir, "project.xml"));

foreach (@files) {
	my ($path, $file) = @{$_};

	$file = File::Spec->catfile($plugin_dir, $file);

	open IN, "<", $file || warn "Couldn't read file '$file': $!\n";

	my $size = -s $file;

	if ($size) {
		my $value = '';

		read(IN, $value, -s $file);
		$xpath->setNodeText($path, $value);

		# Parse the value that we are storing.  If it is a custom form XML,
		# also store it in the "ec_parameterForm" property on the procedure so
		# that the form is displayed by the web UI whenever the parameters to
		# the procedure are accessed.

		my $editorXpath   = new XML::XPath(filename => $file);
		my $procedureName = "";

		eval {$procedureName = $editorXpath->findvalue("/step/procedure");};

		if ($procedureName ne "" && $editorXpath->exists("/step/editor/formElement")) {
			my $procedurePath = "//procedure[procedureName=\"$procedureName\"]";

			if ($xpath->exists($procedurePath)) {
				print "Adding editor XML to procedure $procedureName\n";

				my $sheetPath = "$procedurePath/propertySheet";
				my $formPath = "$sheetPath/property[propertyName=\"ec_parameterForm\"]";

				if ($xpath->exists($formPath)) {
					if ($xpath->exists("$formPath/value")) {
						# The property already exists and has a <value>
						# element; just set its contents.
						$xpath->setNodeText("$formPath/value", $value);
					} else {
						# The property already exists but there is no <value>;
						# add the node.
						addXmlElement($xpath->findnodes($formPath)->get_node(1),
								"value", $value);
					}
				} else {
					# The property doesn't exist; construct its contents.
					my $property = XML::XPath::Node::Element->new("property");

					addXmlElement($property, "propertyName", "ec_parameterForm");
					addXmlElement($property, "value", $value);
					addXmlElement($property, "expandable", 0);

					if ($xpath->exists($sheetPath)) {
						# There is a property sheet on the procedure; add the
						# new property to it.
						$xpath->findnodes($sheetPath)->get_node(1)->appendChild($property);
					} else {
						# There is no property sheet on the procedure; create
						# a node and add the new property to it.
						my $sheet = XML::XPath::Node::Element->new("propertySheet");

						$sheet->appendChild($property);
						$xpath->findnodes($procedurePath)->get_node(1)->appendChild($sheet);
					}
				}
			}
		}
	} else {
		print "Skipping empty $file\n";
	}
	close IN;
}

# Write the result into the project.xml file in the same directory.

open OUT, ">", File::Spec->catfile($out_base_dir."/META-INF", "project.xml") || die $!;
print OUT $xpath->findnodes_as_string('/') || die $!;
close OUT || die $!;
print "DONE\n";


### Regex part

## List of files for regex
@fset = ();
$filter = qr(xml|MF);

$dir = cwd()."/".$out_base_dir;
loopDir($dir, "", $filter);

foreach (@fset) { print $_ , "\n"; }

my $scnt = 0; # Counter for overall changes were made
 
foreach (@fset) {
	next if m/fastmake.pl/;
	next if m/project.xml/;

	open FL, '<', $_ or die $!; undef $/; $file = <FL>; close FL;   
	
	chmod 0777;
	open FL, '>', $_ or die $!; 

	# For all necessary substitutions
	for (my $i = 0; $i < scalar @pats; $i++) {
		my $tcnt = $file =~ s/$pats[$i]/$spat[$i]/g;
		$scnt += $tcnt;
	}

	print FL $file;
	close FL;   
}

print "Changes were made: ", $scnt, "\n";


### Build .jar
print "-"x10, "\n";

print "[INFO] - Building jar...";

chdir $out_base_dir;
$res = `jar cvf ..\\$spat[0].jar *`;
chdir $plugin_dir;

print "DONE\n";


### Cleaning
print "[INFO] - Clean up...";
rmtree(["$out_base_dir"]) or die $!;
print "DONE\n";


### End
print "\nDone\n";