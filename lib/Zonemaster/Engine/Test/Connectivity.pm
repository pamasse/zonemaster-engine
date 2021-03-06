package Zonemaster::Engine::Test::Connectivity;

use version; our $VERSION = version->declare("v1.0.14");

use strict;
use warnings;

use 5.014002;

use Zonemaster::Engine;

use Carp;
use List::MoreUtils qw[uniq];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;
use Zonemaster::Engine::ASNLookup;
use Zonemaster::Engine::Constants qw[:ip];
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Util;

###
### Entry Points
###

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    if ( Zonemaster::Engine::Util::should_run_test( q{connectivity01} ) ) {
        push @results, $class->connectivity01( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{connectivity02} ) ) {
        push @results, $class->connectivity02( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{connectivity03} ) ) {
        push @results, $class->connectivity03( $zone );
    }

    return @results;
}

###
### Metadata Exposure
###

sub metadata {
    my ( $class ) = @_;

    return {
        connectivity01 => [
            qw(
              NAMESERVER_HAS_UDP_53
              NAMESERVER_NO_UDP_53
              IPV4_DISABLED
              IPV6_DISABLED
              )
        ],
        connectivity02 => [
            qw(
              NAMESERVER_HAS_TCP_53
              NAMESERVER_NO_TCP_53
              IPV4_DISABLED
              IPV6_DISABLED
              )
        ],
        connectivity03 => [
            qw(
              NAMESERVERS_IPV4_NO_AS
              NAMESERVERS_IPV4_WITH_MULTIPLE_AS
              NAMESERVERS_IPV4_WITH_UNIQ_AS
              NAMESERVERS_IPV6_NO_AS
              NAMESERVERS_IPV6_WITH_MULTIPLE_AS
              NAMESERVERS_IPV6_WITH_UNIQ_AS
              NAMESERVERS_NO_AS
              NAMESERVERS_WITH_MULTIPLE_AS
              NAMESERVERS_WITH_UNIQ_AS
              IPV4_ASN
              IPV6_ASN
              ASN_INFOS_RAW
              ASN_INFOS_ANNOUNCE_BY
              ASN_INFOS_ANNOUNCE_IN
              IPV4_DISABLED
              IPV6_DISABLED
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    NAMESERVERS_IPV4_WITH_UNIQ_AS => sub {
        __x    # CONNECTIVITY:NAMESERVERS_IPV4_WITH_UNIQ_AS
          'All nameservers IPv4 addresses are in the same AS ({asn}).', @_;
    },
    NAMESERVERS_IPV6_WITH_UNIQ_AS => sub {
        __x    # CONNECTIVITY:NAMESERVERS_IPV6_WITH_UNIQ_AS
          'All nameservers IPv6 addresses are in the same AS ({asn}).', @_;
    },
    NAMESERVERS_WITH_MULTIPLE_AS => sub {
        __x    # CONNECTIVITY:NAMESERVERS_WITH_MULTIPLE_AS
          'Domain\'s authoritative nameservers do not belong to the same AS.', @_;
    },
    NAMESERVERS_WITH_UNIQ_AS => sub {
        __x    # CONNECTIVITY:NAMESERVERS_WITH_UNIQ_AS
          'All nameservers are in the same AS ({asn}).', @_;
    },
    NAMESERVERS_IPV4_NO_AS => sub {
        __x    # CONNECTIVITY:NAMESERVERS_IPV4_NO_AS
          'No IPv4 nameserver address is in an AS.', @_;
    },
    NAMESERVERS_IPV4_WITH_MULTIPLE_AS => sub {
        __x    # CONNECTIVITY:NAMESERVERS_IPV4_WITH_MULTIPLE_AS
          'Authoritative IPv4 nameservers are in more than one AS.', @_;
    },
    NAMESERVERS_IPV6_NO_AS => sub {
        __x    # CONNECTIVITY:NAMESERVERS_IPV6_NO_AS
          'No IPv6 nameserver address is in an AS.', @_;
    },
    NAMESERVERS_IPV6_WITH_MULTIPLE_AS => sub {
        __x    # CONNECTIVITY:NAMESERVERS_IPV6_WITH_MULTIPLE_AS
          'Authoritative IPv6 nameservers are in more than one AS.', @_;
    },
    NAMESERVERS_NO_AS => sub {
        __x    # CONNECTIVITY:NAMESERVERS_NO_AS
          'No nameserver address is in an AS.', @_;
    },
    NAMESERVER_HAS_TCP_53 => sub {
        __x    # CONNECTIVITY:NAMESERVER_HAS_TCP_53
          'Nameserver {ns}/{address} accessible over TCP on port 53.', @_;
    },
    NAMESERVER_HAS_UDP_53 => sub {
        __x    # CONNECTIVITY:NAMESERVER_HAS_UDP_53
          'Nameserver {ns}/{address} accessible over UDP on port 53.', @_;
    },
    NAMESERVER_NO_TCP_53 => sub {
        __x    # CONNECTIVITY:NAMESERVER_NO_TCP_53
          'Nameserver {ns}/{address} not accessible over TCP on port 53.', @_;
    },
    NAMESERVER_NO_UDP_53 => sub {
        __x    # CONNECTIVITY:NAMESERVER_NO_UDP_53
          'Nameserver {ns}/{address} not accessible over UDP on port 53.', @_;
    },
    IPV4_DISABLED => sub {
        __x    # CONNECTIVITY:IPV4_DISABLED
          'IPv4 is disabled, not sending "{rrtype}" query to {ns}/{address}.', @_;
    },
    IPV6_DISABLED => sub {
        __x    # CONNECTIVITY:IPV6_DISABLED
          'IPv6 is disabled, not sending "{rrtype}" query to {ns}/{address}.', @_;
    },
    IPV4_ASN => sub {
        __x    # CONNECTIVITY:IPV4_ASN
          'Name servers have IPv4 addresses in the following ASs: {asn}.', @_;
    },
    IPV6_ASN => sub {
        __x    # CONNECTIVITY:IPV6_ASN
          'Name servers have IPv6 addresses in the following ASs: {asn}.', @_;
    },
    ASN_INFOS_RAW => sub {
        __x    # CONNECTIVITY:ASN_INFOS_RAW
          '[ASN:RAW] {address};{data}', @_;
    },
    ASN_INFOS_ANNOUNCE_BY => sub {
        __x    # CONNECTIVITY:ASN_INFOS_ANNOUNCE_BY
          '[ASN:ANNOUNCE_BY] {address};{asn}', @_;
    },
    ASN_INFOS_ANNOUNCE_IN => sub {
        __x    # CONNECTIVITY:ASN_INFOS_ANNOUNCE_IN
          '[ASN:ANNOUNCE_IN] {address};{prefix}', @_;
    },
);

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

sub version {
    return "$Zonemaster::Engine::Test::Connectivity::VERSION";
}

###
### Tests
###

sub connectivity01 {
    my ( $class, $zone ) = @_;
    my @results;
    my $query_type = q{SOA};

    my %ips;

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        next if $ips{ $local_ns->address->short };

        my $p = $local_ns->query( $zone->name, $query_type, { usevc => 0 } );

        if ( $p ) {
            push @results,
              info(
                NAMESERVER_HAS_UDP_53 => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
        }
        else {
            push @results,
              info(
                NAMESERVER_NO_UDP_53 => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
        }

        $ips{ $local_ns->address->short }++;

    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    return @results;
} ## end sub connectivity01

sub connectivity02 {
    my ( $class, $zone ) = @_;
    my @results;
    my %ips;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        next if $ips{ $local_ns->address->short };

        my $p = $local_ns->query( $zone->name, $query_type, { usevc => 1 } );

        if ( $p ) {
            push @results,
              info(
                NAMESERVER_HAS_TCP_53 => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
        }
        else {
            push @results,
              info(
                NAMESERVER_NO_TCP_53 => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
        }

        $ips{ $local_ns->address->short }++;

    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    return @results;
} ## end sub connectivity02

sub connectivity03 {
    my ( $class, $zone ) = @_;
    my @results;

    my %ips = ( $IP_VERSION_4 => {}, $IP_VERSION_6 => {} );

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) } ) {
        my $addr = $ns->address;
        $ips{ $addr->version }{ $addr->ip } = $addr;
    }

    my @v4ips = values %{ $ips{$IP_VERSION_4} };
    my @v6ips = values %{ $ips{$IP_VERSION_6} };

    my @v4asns;
    my @v6asns;

    foreach my $v4ip ( @v4ips ) {
        my ( $asnref, $prefix, $raw ) = Zonemaster::Engine::ASNLookup->get_with_prefix( $v4ip );
        if ( $raw ) {
            push @results,
              info(
                ASN_INFOS_RAW => {
                    address => $v4ip->short,
                    data    => $raw,
                }
              );
        }
        if ( $asnref ) {
            push @results,
              info(
                ASN_INFOS_ANNOUNCE_BY => {
                    address => $v4ip->short,
                    asn     => join( q{,}, @{$asnref} ),
                }
              );
            push @v4asns, @{$asnref};
        }
        if ( $prefix ) {
            push @results,
              info(
                ASN_INFOS_ANNOUNCE_IN => {
                    address => $v4ip->short,
                    prefix  => sprintf "%s/%d",
                    $prefix->ip, $prefix->prefixlen,
                }
              );
        }
    } ## end foreach my $v4ip ( @v4ips )
    foreach my $v6ip ( @v6ips ) {
        my ( $asnref, $prefix, $raw ) = Zonemaster::Engine::ASNLookup->get_with_prefix( $v6ip );
        if ( $raw ) {
            push @results,
              info(
                ASN_INFOS_RAW => {
                    address => $v6ip->short,
                    data    => $raw,
                }
              );
        }
        if ( $asnref ) {
            push @results,
              info(
                ASN_INFOS_ANNOUNCE_BY => {
                    address => $v6ip->short,
                    asn     => join( q{,}, @{$asnref} ),
                }
              );
            push @v6asns, @{$asnref};
        }
        if ( $prefix ) {
            push @results,
              info(
                ASN_INFOS_ANNOUNCE_IN => {
                    address => $v6ip->short,
                    prefix  => sprintf "%s/%d",
                    $prefix->short, $prefix->prefixlen,
                }
              );
        }
    } ## end foreach my $v6ip ( @v6ips )

    @v4asns = uniq @v4asns;
    @v6asns = uniq @v6asns;
    my @all_asns = uniq( @v4asns, @v6asns );

    if ( @v4asns ) {
        push @results, info( IPV4_ASN => { asn => \@v4asns } );
    }
    if ( @v6asns ) {
        push @results, info( IPV6_ASN => { asn => \@v6asns } );
    }

    if ( @v4asns == 1 ) {
        push @results, info( NAMESERVERS_IPV4_WITH_UNIQ_AS => { asn => $v4asns[0] } );
    }
    elsif ( @v4asns > 1 ) {
        push @results, info( NAMESERVERS_IPV4_WITH_MULTIPLE_AS => { asn => \@v4asns } );
    }
    else {
        push @results, info( NAMESERVERS_IPV4_NO_AS => {} );
    }

    if ( @v6asns == 1 ) {
        push @results, info( NAMESERVERS_IPV6_WITH_UNIQ_AS => { asn => $v6asns[0] } );
    }
    elsif ( @v6asns > 1 ) {
        push @results, info( NAMESERVERS_IPV6_WITH_MULTIPLE_AS => { asn => \@v6asns } );
    }
    else {
        push @results, info( NAMESERVERS_IPV6_NO_AS => {} );
    }

    if ( @all_asns == 1 ) {
        push @results, info( NAMESERVERS_WITH_UNIQ_AS => { asn => $all_asns[0] } );
    }
    elsif ( @all_asns > 1 ) {
        push @results, info( NAMESERVERS_WITH_MULTIPLE_AS => { asn => \@all_asns } );
    }
    else {
        push @results, info( NAMESERVERS_NO_AS => {} );    # Shouldn't pass Basic
    }

    return @results;
} ## end sub connectivity03

1;

=head1 NAME

Zonemaster::Engine::Test::Connectivity - module implementing tests of nameservers reachability

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Connectivity->all($zone);

=head1 METHODS

=over

=item all($zone)

Runs the default set of tests and returns a list of log entries made by the tests

=item metadata()

Returns a reference to a hash, the keys of which are the names of all test methods in the module, and the corresponding values are references to
lists with all the tags that the method can use in log entries.

=item tag_descriptions()

Returns a refernce to a hash with translation functions. Used by the builtin translation system.

=item version()

Returns a version string for the module.

=back

=head1 TESTS

=over

=item connectivity01($zone)

Verify nameservers UDP port 53 reachability.

=item connectivity02($zone)

Verify nameservers TCP port 53 reachability.

=item connectivity03($zone)

Verify that all nameservers do not belong to the same AS.

=back

=cut
