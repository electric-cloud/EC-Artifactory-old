=head1 NAME

Retrieve artifact from Artifactory's repository

=head1 DESCRIPTION

This script searches and retrieves artifacts from Artifactory's repository

Copyright (c) 2014 Electric Cloud, Inc.
All rights reserved
=cut

use ElectricCommander;
use ElectricCommander::PropMod qw(/myProject/modules);

use Storage::Artifactory;
use URI::URL;
use Cwd;
use File::Path;
use Data::Dumper;

$| = 1;

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

my $server = getProperty($ec, "server", 1);
my $repository = getProperty($ec, "repository", 1);

my $group = getProperty($ec, "group", 1);
my $name = getProperty($ec, "name", 1);
my $artifact = $group.":".$name;

my $type = getProperty($ec, "type", 1);


my $version = getProperty($ec, "version", 0);
my $directory = getProperty($ec, "directory", 0, getcwd());
# my $overwrite = getProperty($ec, "overwrite");
my $overwrite = '';

print "Server URL:\t\t$server\n";
print "Repository:\t\t$repository\n\n";
print "Artifact:\t\t$artifact\n";
print "Artifact Version:\t$version\n";
print "Artifact Extension:\t$type\n";
print "Destination directory:\t$directory\n";
print "Overwrite:\t\t$overwrite\n\n";

mkpath($directory, 1);
my $client = Storage::Artifactory->new($server, $repository);

print "Fetching artifact...\n";
$client->download_artifact($artifact, $version, $type, $directory, $overwrite);

1;