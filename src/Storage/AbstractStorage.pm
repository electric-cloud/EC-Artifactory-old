=head1 NAME

Artifactory::AbstractStorage - Base class for HTTP-based storages (namely, Artifactory and Nexus)

=head1 DESCRIPTION

This module provides basic api for other storage packages

Copyright (c) 2014 Electric Cloud, Inc.
All rights reserved
=cut

package Storage::AbstractStorage;

use strict;
use warnings;

use URI::URL;
use LWP::UserAgent;
use HTTP::Headers;
use JSON;

use vars qw($VERSION);
our $VERSION = '@PLUGIN_VERSION@';

=item new()

Constructs new object.

Input:
        $url - base URL for server
        $repository - repository name, or undef. Multiple repositories
        may be specified in form of 'repo1,repo2'
        $credentials - reference to hash containing username and password
        values used to authenticate with server
    
Output:
        AbstractStorage object
=cut
sub new {
    my ($self, $url, $repository, $credentials)=@_;
    my $class=ref($self) || $self;
    
    my $ua = LWP::UserAgent->new();
    
    $url = URI::URL->new($url);
    
    return bless {
        _ua => $ua,
        _url => $url,
        _path => $url->path(),
        _json => JSON->new()->utf8(),
        _repository => $repository,
        _credentials => $credentials
    }, $class;
}

=item download_artifact()

Download artifact from server.

Input:
        $url - artifact's URL
        $local_file - path to file on local filesystem where artifact willi be stored
    
Output:
        True if file was successfully downloaded and stored, false otherwise
=cut
sub download_artifact {
    my ($self, $url, $local_file) = @_;
    my %headers = $self->_get_headers();
    
    $headers{":content_file"} = $local_file;
    
    my $response = $self->{_ua}->get($url, %headers);
    
    if ($response->is_success()) {
        return 1;
    }
}

=item _api_request()

Calls artifactory server api function.

Input:
        $path - REST function that is called
        $params - reference to hash, containing GET variables
    
Output:
        Array of parsed JSON objects
        Dies in case of any error
=cut
sub _api_request {
    my ($self, $path, $params) = @_;
    my $url = $self->{_url};

    $path or die "Mandatory parameter missing: path";

    if($self->{_path}) {
        $path = "$self->{_path}$path";
    }
    
    $url->path($path);
    $url->query_form(%$params);
    
    my $response = $self->{_ua}->get($url, $self->_get_headers());

    if ($response->is_success()) {
        return $self->{_json}->decode($response->decoded_content());
    }

    die "Storage returned error: ${\$response->status_line()}\n";
}

sub _get_headers {
    my ($self) = @_;

    my $headers = HTTP::Headers->new(Content_type => "application/json", Accept => "application/json");

    my $credentials = $self->{_credentials};
    if($credentials) {
        $headers->authorization_basic($credentials->{username}, $credentials->{password});
    } 

    return %{$headers};    
}

1;