=head1 NAME

Storage:Nexus - client module for working with nexus repository

=head1 SYNOPSIS

    use Storage:Nexus;
    my $client = Storage:Nexus->new("http://repository.sonatype.org/service", "apache-staging");
    my @search_results = $client->search({a => "activemq"});

=head1 DESCRIPTION

This module provides functions for working with nexus repository
through REST API

Copyright (c) 2014 Electric Cloud, Inc.
All rights reserved
=cut

package Storage::Nexus;

use strict;
use warnings;

use URI::URL;
use LWP::UserAgent;
use HTTP::Headers;
use JSON;
use Data::Dumper;

use base qw(Storage::AbstractStorage);

=item new()

Constructs nexus object.

Input:
        $url - URL of nexus server
        $repository - repository name, or undef. Multiple repositories
        may be specified in form of 'repo1,repo2'
        $credentials - reference to hash containing username and password
        values used to authenticate with artifactory server
    
Output:
        Artifactory object
=cut
sub new {
    my $self= shift;
    my $class=ref($self) || $self;
    
    return $class->SUPER::new(@_);
}

=item search()

Calls nexus server search GAVC function.

Input:
        $params - reference to hash containing search parameters,
        keys are:
            'g' - group name
            'a' - artifact name
            'v' - version
            'c' - classifier, such as 'sources'
    
Output:
        Array of URI::URL's to artifacts metadata
=cut
sub search {
    my ($self, $params) = @_;
    
    my $repository = $self->{_repository};
    
    if($repository && length($repository)) {
        $params->{repos} = $repository;
    }

    my @results = ();
    my @response = @{$self->_api_request("/local/data_index", $params)->{data}};

    foreach (@response) {
        push(@results, URI::URL->new($_->{resourceURI}));
    }
    
    return @results;
}

1;