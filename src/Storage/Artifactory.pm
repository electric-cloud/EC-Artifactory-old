=head1 NAME

Storage::Artifactory - client module for working with artifactory repository

=head1 SYNOPSIS

    use Storage::Artifactory;
    my $client = Storage::Artifactory->new("http://artifactory/artifactory", "repo");
    $client->download_artifact("activemq:activemq-core", "4.0-M3", ".jar", "/tmp");

=head1 DESCRIPTION

This module provides functions for working with artifactory repository
through REST API

Copyright (c) 2014 Electric Cloud, Inc.
All rights reserved
=cut

package Storage::Artifactory;

use strict;
use warnings;

use URI::URL;
use LWP::UserAgent;
use HTTP::Headers;
use XML::Simple;
use Data::Dumper;

=item new()

Constructs artifactory object.

Input:
        $url - URL of artifactory server
        $repository - repository name
    
Output:
        Artifactory object
=cut
sub new {
    my ($self, $url, $repository)=@_;
    my $class=ref($self) || $self;
    
    my $ua = LWP::UserAgent->new();
    
    $url = URI::URL->new($url);
    
    return bless {
        _ua => $ua,
        _url => $url,
        _path => $url->path(),
        _repository => $repository
    }, $class;
}

=item download_artifact()

Download artifact from server.

Input:
        $artifact - artifact's name in form of "<group:key>"
        $version - artifact's version, undef if latest
        $extension - artifact's extension, e.g., ".jar" 
        $path - path to file on local filesystem where artifact will be stored
        $overwrite - 1 if file should be overwrited, 0 otherwise

Output:
        True if file was successfully downloaded and stored, false otherwise
=cut
sub download_artifact {
    my ($self, $artifact, $version, $extension, $path, $overwrite) = @_;

    my ($group, $name) = split (':', $artifact);
    $group =~ s/\./\//g;

    my %headers = $self->_get_headers();
    
    my $basepath = $self->{_url}."/".$self->{_repository}."/$group/$name";

    if(!defined $version) {
        $version = $self->_get_latest_version($basepath);
    }

    my $filename = "$name-$version$extension";
    $headers{":content_file"} = "$path/$filename";
    my $url = "$basepath/$version/$filename"; 
    
    print "Source: $url\n";
    print "Destination: $path/$filename\n";

    if (!$overwrite && -e $headers{":content_file"}) {
        return 1;
    }
    
    my $response = $self->{_ua}->get($url, %headers);
    
    if ($response->is_success()) {
        return 1;
    }
    
    return 0;
}

=item download_artifact()

Publish artifact to Artifactory server

Input:
        $fname      - artifact's name in form of "pathto/<group:key>"
        $artif_cont - artifact's content
        $auth       - Auth data 'Basic <base64data>'
        $debug      - 1 if we need server response log 

Output:
        True if file was successfully published, false otherwise
=cut
sub deploy_artifact {
    my ($self, $fname, $artif_cont, $auth, $debug) = @_;

    my %headers = $self->_get_headers();    

    my ($group, $name) = split (':', $fname);
    $group =~ s/\./\//g;

    my $basepath = $self->{_url}."/".$self->{_repository}."/$group/$name";
    
    print "Deploing artifact to\n";
    print $basepath, "\n";
    # print $artif_cont, "\n";

    my $url = "$basepath"; 

    my $req_headers = HTTP::Headers->new( %headers );
    my $req = HTTP::Request->new("PUT", $url, $req_headers, $artif_cont);
    $req->header('Authorization' => $auth);

    # PUT
    my $response = $self->{_ua}->request($req);
    
    # debug
    if ($debug) { &dump($req, $response); }

    if ($response->is_success()) {
        print "Delpoy OK\n";
        return 1;
    }
    
    print "Delpoy ERROR\n";
    return 0;    
}

sub dump {
   my ($req,$res) = @_;

   if ($res->is_success) {
      print "\nRESPONSE-HEADERS\n";
      print $res->headers_as_string();
      print "\nRESPONSE-CONTENT\n";
      print $res->content;
   } else {
      print "\nRESPONSE-ERROR\n";
      print $res->error_as_HTML();
   }
   print "\n\n";
}


=item _get_latest_version()

get latest version of artifact

Input:
        $basepath - url to directory, containing maven-metadata.xml
    
Output:
        Latest version, string, or undef in case of error
=cut
sub _get_latest_version {
    my ($self, $basepath) = @_;
    my %headers = $self->_get_headers();
    my $response = $self->{_ua}->get("$basepath/maven-metadata.xml", %headers);
    
    if (!$response->is_success()) {
        return 0;
    }

    my $parser = new XML::Simple();
    my $xml = $parser->XMLin($response->decoded_content());
    
    return $xml->{versioning}->{latest};
}

sub _get_headers {
    my ($self) = @_;

    my $headers = HTTP::Headers->new(Accept => "*/*");
    return %{$headers};    
}

1;