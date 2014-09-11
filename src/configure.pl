=head1 NAME

Configure @PLUGIN_KEY@ plugin

=head1 DESCRIPTION

Step script for managing configuration of @PLUGIN_KEY@ plugin.

Copyright (c) 2014 Electric Cloud, Inc.
All rights reserved
=cut

$| = 1;
use ElectricCommander;

sub getValue {
    my ($xpath, $default) = @_;
    return $xpath->findvalue('//value')->string_value || $default;
}

sub getProperty {
    my ($ec, $name, $default) = @_;
    return getValue($ec->getProperty($name), $default);
}

sub getJobParameter {
    my ($ec, $name, $default) = @_;
    return getValue($ec->getActualParameter($name, {jobId => $ENV{COMMANDER_JOBID}}), $default);
}

sub reportJobError {
    my ($ec, $errMsg) = @_;

    $ec->setProperty("/myJob/configError", $errMsg);
    print "$errMsg\n";
    exit -1;
}

sub createConfiguration {
    my ($ec, $name) = @_;
    
    my $configPath = "/myProject/cfgs/$name";
    
    if($ec->getProperty($configPath)->findvalue("//code") ne "NoSuchProperty") {
        reportJobError($ec, "A configuration named '$name' already exists.");
    }
    
    my $server = getJobParameter($ec, "server");
    my $xpath = $ec->setProperty("$configPath/server", $server);

    return $ec->checkAllErrors($xpath);
}

sub modifyConfiguration {
    my ($ec, $name) = @_;
    
    my $configPath = "/myProject/cfgs/$name";
    
    if($ec->getProperty($configPath)->findvalue("//code")) {
        reportJobError($ec, "A configuration named '$name' does not exists.");
    }
    
    my $server = getJobParameter($ec, "server");
    my $xpath = $ec->setProperty("$configPath/server", $server);

    return $ec->checkAllErrors($xpath);
}

sub deleteConfiguration {
    my ($ec, $name) = @_;

    $ec->deleteCredential("$[/myProject]", $name);
    $ec->deleteProperty("/myProject/cfgs/$name");
}

sub createCredential {
    my ($ec, $name) = @_;
    
    my $xpath = $ec->getFullCredential("credential");
    my $userName = $xpath->findvalue("//userName");
    my $password = $xpath->findvalue("//password");

    $ec->deleteCredential("$[/myProject]", $name);
    $xpath = $ec->createCredential("$[/myProject]", $name, $userName, $password);
    my $errors = $ec->checkAllErrors($xpath);

    # Give job launcher full permissions on the credential
    $xpath = $ec->createAclEntry("user", "$[/myJob/launchedByUser]", {
            projectName => "$[/myProject]",
            credentialName => $name,
            readPrivilege => "allow",
            modifyPrivilege => "allow",
            executePrivilege => "allow",
            changePermissionsPrivilege => "allow"
    });
    $errors .= $ec->checkAllErrors($xpath);

    # Attach credential to steps that will need it
    my $pname = "Retrieve Artifact";
    
    $xpath = $ec->attachCredential("$[/myProject]", $name, {
        procedureName => $pname,
        stepName => $pname
    });
    $errors .= $ec->checkAllErrors($xpath);
    
    return $errors;
}

# get an EC object
my $ec = new ElectricCommander({debug => 1});
$ec->abortOnError(0);

my $operation = getProperty($ec, "operation") || die "Missing mandatory parameter 'operation'.";
my $name = getProperty($ec, "name") || die "Missing mandatory parameter 'name'.";

if ($operation eq "add") {
    my $errors = createConfiguration($ec, $name);

    if ($errors ne "") {
        deleteConfiguration($ec, $name);
        reportJobError($ec, "Error creating configuration $name: $errors");
    }
    
    $errors = createCredential($ec, $name);
    if ($errors ne "") {
        deleteConfiguration($ec, $name);
        reportJobError($ec, "Error creating credential for configuration $name: $errors");
    }
} elsif($operation eq "modify") {
    my $errors = modifyConfiguration($ec, $name);

    if ($errors ne "") {
        reportJobError($ec, "Error altering configuration $name: $errors");
    }
} elsif($operation eq "delete") {
        deleteConfiguration($ec, $name);
} else {
    reportJobError($ec, "Unknown operation: $operation");
}

exit 0;