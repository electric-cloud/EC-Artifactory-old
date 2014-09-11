use ElectricCommander;
use ElectricCommander::PropMod qw(/myProject/modules);

use Storage::Artifactory;

use MIME::Base64();

$| = 1;

print "Publish plugin\n";

sub getProperty {
    my ($ec, $name, $mandatory, $default) = @_;
    $ret = $ec->getProperty($name)->findvalue('//value')->string_value;
    
    if(!$ret && $mandatory) {
        die "Missing mandatory parameter '$name'.";
    }
    
    return $ret || $default;
}

# get an EC object
my $ec = ElectricCommander->new();
$ec->abortOnError(0);

my $server 		= getProperty($ec, "server", 1);
my $repository 	= getProperty($ec, "repository", 1);
my $name 		= getProperty($ec, "name", 1);
my $group 		= getProperty($ec, "group", 1);
my $directory 	= getProperty($ec, "directory", 1);
my $login 		= getProperty($ec, "login", 1);
my $password 	= getProperty($ec, "password", 1);
my $debug 	 	= getProperty($ec, "debug", 1);


# Not imolemented yet
my $version 	= 0;


print "Server URL:\t\t$server\n";
print "Repository:\t\t$repository\n\n";
print "Artifact:\t\t$name\n";
print "Source directory:\t$directory\n";

$directory =~ s/\\/\//g;
# reduction to "last slash" form
$directory = join('/', split('/', $directory)) . "/";
my $artif_source = $directory.$name;

# Open artifact
open FL, "<", $artif_source or die $!;
local undef $/; $artif_cont = <FL>; close FL;

my $client = Storage::Artifactory->new($server, $repository);

# Prepere artifact name for repo
# Looks like gid:aid/0/aid-0.txt
@a = split('\.', $name);
$name_wo_ext 	= ''; # name of artifact w/o extention
$ext 			= ''; # extention

if ($a[-1] eq $name) { # for files w/o extention
	$res = $name . "-" .$version;
	$name_wo_ext = $name;	
}
else {
	$res = join('.', @a) . "-" .$version;	
	$extention = "." . pop @a;
	$name_wo_ext = join('.', @a);
}

$fname = $group.":".$name_wo_ext."/".$version."/".$name_wo_ext."-".$version.$extention;
print "Artifact path: ", $fname, "\n";

# Prepare authentication string for Artifactory
my $auth = MIME::Base64::encode("$login:$password");
$auth = 'Basic ' . $auth;

print "Publishing artifact...\n";
$client->deploy_artifact($fname, $artif_cont, $auth, $debug);

1;