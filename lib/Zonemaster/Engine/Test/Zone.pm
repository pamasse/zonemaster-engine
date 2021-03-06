package Zonemaster::Engine::Test::Zone;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare( "v1.0.12" );

use Zonemaster::Engine;

use Carp;
use List::MoreUtils qw[none];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Constants qw[:soa :ip];
use Zonemaster::Engine::Recursor;
use Zonemaster::Engine::Nameserver;
use Zonemaster::Engine::Test::Address;
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Util;

###
### Entry Points
###

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    push @results, $class->zone01( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone01} );
    if ( none { $_->tag eq q{NO_RESPONSE_SOA_QUERY} } @results ) {
        push @results, $class->zone02( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone02} );
        push @results, $class->zone03( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone03} );
        push @results, $class->zone04( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone04} );
        push @results, $class->zone05( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone05} );
        push @results, $class->zone06( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone06} );
        if ( none { $_->tag eq q{MNAME_RECORD_DOES_NOT_EXIST} } @results ) {
            push @results, $class->zone07( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone07} );
        }
    }
    if ( none { $_->tag eq q{MNAME_RECORD_DOES_NOT_EXIST} } @results ) {
        push @results, $class->zone08( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone08} );
        if ( none { $_->tag eq q{NO_RESPONSE_MX_QUERY} } @results ) {
            push @results, $class->zone09( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone09} );
        }
    }
    if ( none { $_->tag eq q{NO_RESPONSE_SOA_QUERY} } @results ) {
        push @results, $class->zone10( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone10} );
    }
    return @results;
} ## end sub all

###
### Metadata Exposure
###

sub metadata {
    my ( $class ) = @_;

    return {
        zone01 => [
            qw(
              MNAME_RECORD_DOES_NOT_EXIST
              MNAME_NOT_AUTHORITATIVE
              MNAME_NO_RESPONSE
              MNAME_NOT_IN_GLUE
              MNAME_IS_AUTHORITATIVE
              NO_RESPONSE_SOA_QUERY
              )
        ],
        zone02 => [
            qw(
              REFRESH_MINIMUM_VALUE_LOWER
              REFRESH_MINIMUM_VALUE_OK
              NO_RESPONSE_SOA_QUERY
              )
        ],
        zone03 => [
            qw(
              REFRESH_LOWER_THAN_RETRY
              REFRESH_HIGHER_THAN_RETRY
              NO_RESPONSE_SOA_QUERY
              )
        ],
        zone04 => [
            qw(
              RETRY_MINIMUM_VALUE_LOWER
              RETRY_MINIMUM_VALUE_OK
              NO_RESPONSE_SOA_QUERY
              )
        ],
        zone05 => [
            qw(
              EXPIRE_MINIMUM_VALUE_LOWER
              EXPIRE_LOWER_THAN_REFRESH
              EXPIRE_MINIMUM_VALUE_OK
              NO_RESPONSE_SOA_QUERY
              )
        ],
        zone06 => [
            qw(
              SOA_DEFAULT_TTL_MAXIMUM_VALUE_HIGHER
              SOA_DEFAULT_TTL_MAXIMUM_VALUE_LOWER
              SOA_DEFAULT_TTL_MAXIMUM_VALUE_OK
              NO_RESPONSE_SOA_QUERY
              )
        ],
        zone07 => [
            qw(
              MNAME_IS_CNAME
              MNAME_IS_NOT_CNAME
              NO_RESPONSE_SOA_QUERY
              MNAME_HAS_NO_ADDRESS
              )
        ],
        zone08 => [
            qw(
              MX_RECORD_IS_CNAME
              MX_RECORD_IS_NOT_CNAME
              NO_RESPONSE_MX_QUERY
              )
        ],
        zone09 => [
            qw(
              NO_MX_RECORD
              MX_RECORD_EXISTS
              NO_RESPONSE_MX_QUERY
              )
        ],
        zone10 => [
            qw(
              MULTIPLE_SOA
              NO_RESPONSE
              NO_SOA_IN_RESPONSE
              ONE_SOA
              WRONG_SOA
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    RETRY_MINIMUM_VALUE_LOWER => sub {
        __x    # ZONE:RETRY_MINIMUM_VALUE_LOWER
          'SOA \'retry\' value ({retry}) is less than the recommended one ({required_retry}).', @_;
    },
    RETRY_MINIMUM_VALUE_OK => sub {
        __x    # ZONE:RETRY_MINIMUM_VALUE_OK
          'SOA \'retry\' value ({retry}) is more than the minimum recommended value ({required_retry}).', @_;
    },
    MNAME_NO_RESPONSE => sub {
        __x    # ZONE:MNAME_NO_RESPONSE
          'SOA \'mname\' nameserver {ns}/{address} does not respond.', @_;
    },
    MNAME_IS_CNAME => sub {
        __x    # ZONE:MNAME_IS_CNAME
          'SOA \'mname\' value ({mname}) refers to a NS which is an alias (CNAME).', @_;
    },
    MNAME_IS_NOT_CNAME => sub {
        __x    # ZONE:MNAME_IS_NOT_CNAME
          'SOA \'mname\' value ({mname}) refers to a NS which is not an alias (CNAME).', @_;
    },
    NO_MX_RECORD => sub {
        __x    # ZONE:NO_MX_RECORD
          'No target (MX, A or AAAA record) to deliver e-mail for the domain name.', @_;
    },
    MX_RECORD_EXISTS => sub {
        __x    # ZONE:MX_RECORD_EXISTS
          'Target ({info}) found to deliver e-mail for the domain name.', @_;
    },
    REFRESH_MINIMUM_VALUE_LOWER => sub {
        __x    # ZONE:REFRESH_MINIMUM_VALUE_LOWER
          'SOA \'refresh\' value ({refresh}) is less than the recommended one ({required_refresh}).', @_;
    },
    REFRESH_MINIMUM_VALUE_OK => sub {
        __x    # ZONE:REFRESH_MINIMUM_VALUE_OK
          'SOA \'refresh\' value ({refresh}) is higher than the minimum recommended value ({required_refresh}).', @_;
    },
    EXPIRE_LOWER_THAN_REFRESH => sub {
        __x    # ZONE:EXPIRE_LOWER_THAN_REFRESH
          'SOA \'expire\' value ({expire}) is lower than the SOA \'refresh\' value ({refresh}).', @_;
    },
    SOA_DEFAULT_TTL_MAXIMUM_VALUE_HIGHER => sub {
        __x    # ZONE:SOA_DEFAULT_TTL_MAXIMUM_VALUE_HIGHER
          'SOA \'minimum\' value ({minimum}) is higher than the recommended one ({highest_minimum}).', @_;
    },
    SOA_DEFAULT_TTL_MAXIMUM_VALUE_LOWER => sub {
        __x    # ZONE:SOA_DEFAULT_TTL_MAXIMUM_VALUE_LOWER
          'SOA \'minimum\' value ({minimum}) is less than the recommended one ({lowest_minimum}).', @_;
    },
    SOA_DEFAULT_TTL_MAXIMUM_VALUE_OK => sub {
        __x    # ZONE:SOA_DEFAULT_TTL_MAXIMUM_VALUE_OK
          'SOA \'minimum\' value ({minimum}) is between the recommended ones ({lowest_minimum}/{highest_minimum}).', @_;
    },
    MNAME_NOT_AUTHORITATIVE => sub {
        __x    # ZONE:MNAME_NOT_AUTHORITATIVE
          'SOA \'mname\' nameserver {ns}/{address} is not authoritative for \'{zone}\' zone.', @_;
    },
    MNAME_RECORD_DOES_NOT_EXIST => sub {
        __x    # ZONE:MNAME_RECORD_DOES_NOT_EXIST
          'SOA \'mname\' field does not exist', @_;
    },
    EXPIRE_MINIMUM_VALUE_LOWER => sub {
        __x    # ZONE:EXPIRE_MINIMUM_VALUE_LOWER
          'SOA \'expire\' value ({expire}) is less than the recommended one ({required_expire}).', @_;
    },
    MNAME_NOT_IN_GLUE => sub {
        __x    # ZONE:MNAME_NOT_IN_GLUE
          'SOA \'mname\' nameserver ({mname}) is not listed in "parent" NS records for tested zone ({nss}).', @_;
    },
    REFRESH_LOWER_THAN_RETRY => sub {
        __x    # ZONE:REFRESH_LOWER_THAN_RETRY
          'SOA \'refresh\' value ({refresh}) is lower than the SOA \'retry\' value ({retry}).', @_;
    },
    REFRESH_HIGHER_THAN_RETRY => sub {
        __x    # ZONE:REFRESH_HIGHER_THAN_RETRY
          'SOA \'refresh\' value ({refresh}) is higher than the SOA \'retry\' value ({retry}).', @_;
    },
    MX_RECORD_IS_CNAME => sub {
        __x    # ZONE:MX_RECORD_IS_CNAME
          'MX record for the domain is pointing to a CNAME.', @_;
    },
    MX_RECORD_IS_NOT_CNAME => sub {
        __x    # ZONE:MX_RECORD_IS_NOT_CNAME
          'MX record for the domain is not pointing to a CNAME.', @_;
    },
    MNAME_IS_AUTHORITATIVE => sub {
        __x    # ZONE:MNAME_IS_AUTHORITATIVE
          'SOA \'mname\' nameserver ({mname}) is authoritative for \'{zone}\' zone.', @_;
    },
    MULTIPLE_SOA => sub {
        __x    # ZONE:MULTIPLE_SOA
          'Nameserver {ns}/{address} responds with multiple ({count}) SOA records on SOA queries.', @_;
    },
    NO_RESPONSE => sub {
        __x    # ZONE:NO_RESPONSE
          'Nameserver {ns}/{address} did not respond.', @_;
    },
    NO_RESPONSE_SOA_QUERY => sub {
        __x    # ZONE:NO_RESPONSE_SOA_QUERY
          'No response from nameserver(s) on SOA queries.';
    },
    NO_RESPONSE_MX_QUERY => sub {
        __x    # ZONE:NO_RESPONSE_MX_QUERY
          'No response from nameserver(s) on MX queries.';
    },
    NO_SOA_IN_RESPONSE => sub {
        __x    # ZONE:NO_SOA_IN_RESPONSE
          'Response from nameserver {ns}/{address} on SOA queries does not contain SOA record.';
    },
    MNAME_HAS_NO_ADDRESS => sub {
        __x    # ZONE:MNAME_HAS_NO_ADDRESS
          'No IP address found for SOA \'mname\' nameserver ({mname}).', @_;
    },
    ONE_SOA => sub {
        __x    # ZONE:ONE_SOA
          'A unique SOA record is returned by all nameservers of the zone.', @_;
    },
    EXPIRE_MINIMUM_VALUE_OK => sub {
        __x    # ZONE:EXPIRE_MINIMUM_VALUE_OK
          'SOA \'expire\' value ({expire}) is higher than the minimum recommended value ({required_expire}) '
          . 'and not lower than the \'refresh\' value ({refresh}).',
          @_;
    },
    WRONG_SOA => sub {
        __x    # ZONE:WRONG_SOA
          'Nameserver {ns}/{address} responds with a wrong owner name ({owner} instead of {name}) on SOA queries.', @_;
    },
);

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

sub version {
    return "$Zonemaster::Engine::Test::Zone::VERSION";
}

sub zone01 {
    my ( $class, $zone ) = @_;
    my @results;

    my $p = _retrieve_record_from_zone( $zone, $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_mname = $soa->mname;
        $soa_mname =~ s/[.]\z//smx;
        if ( not $soa_mname ) {
            push @results, info( MNAME_RECORD_DOES_NOT_EXIST => {} );
        }
        else {
            foreach my $ip_address ( Zonemaster::Engine::Recursor->get_addresses_for( $soa_mname ) ) {

                my $ns = Zonemaster::Engine::Nameserver->new( { name => $soa_mname, address => $ip_address->short } );

                if ( _is_ip_version_disabled( $ns ) ) {
                    next;
                }

                my $p_soa = $ns->query( $zone->name, q{SOA} );
                if ( $p_soa and $p_soa->rcode eq q{NOERROR} ) {
                    if ( not $p_soa->aa ) {
                        push @results,
                          info(
                            MNAME_NOT_AUTHORITATIVE => {
                                ns      => $soa_mname,
                                address => $ip_address->short,
                                zone    => $zone->name,
                            }
                          );
                    }
                }
                else {
                    push @results,
                      info(
                        MNAME_NO_RESPONSE => {
                            ns      => $soa_mname,
                            address => $ip_address->short,
                        }
                      );
                }
            } ## end foreach my $ip_address ( Zonemaster::Engine::Recursor...)
            if ( none { $_ eq $soa_mname } @{ Zonemaster::Engine::TestMethods->method2( $zone ) } ) {
                push @results,
                  info(
                    MNAME_NOT_IN_GLUE => {
                        mname => $soa_mname,
                        nss   => join( q{;}, @{ Zonemaster::Engine::TestMethods->method2( $zone ) } ),
                    }
                  );
            }
        } ## end else [ if ( not $soa_mname ) ]
        if ( not scalar @results ) {
            push @results,
              info(
                MNAME_IS_AUTHORITATIVE => {
                    mname => $soa_mname,
                    zone  => $zone->name,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, info( NO_RESPONSE_SOA_QUERY => {} );
    }

    return @results;
} ## end sub zone01

sub zone02 {
    my ( $class, $zone ) = @_;
    my @results;

    my $p = _retrieve_record_from_zone( $zone, $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_refresh = $soa->refresh;
        if ( $soa_refresh < $SOA_REFRESH_MINIMUM_VALUE ) {
            push @results,
              info(
                REFRESH_MINIMUM_VALUE_LOWER => {
                    refresh          => $soa_refresh,
                    required_refresh => $SOA_REFRESH_MINIMUM_VALUE,
                }
              );
        }
        else {
            push @results,
              info(
                REFRESH_MINIMUM_VALUE_OK => {
                    refresh          => $soa_refresh,
                    required_refresh => $SOA_REFRESH_MINIMUM_VALUE,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, info( NO_RESPONSE_SOA_QUERY => {} );
    }

    return @results;
} ## end sub zone02

sub zone03 {
    my ( $class, $zone ) = @_;
    my @results;

    my $p = _retrieve_record_from_zone( $zone, $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_retry   = $soa->retry;
        my $soa_refresh = $soa->refresh;
        if ( $soa_retry >= $soa_refresh ) {
            push @results,
              info(
                REFRESH_LOWER_THAN_RETRY => {
                    retry   => $soa_retry,
                    refresh => $soa_refresh,
                }
              );
        }
        else {
            push @results,
              info(
                REFRESH_HIGHER_THAN_RETRY => {
                    retry   => $soa_retry,
                    refresh => $soa_refresh,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, info( NO_RESPONSE_SOA_QUERY => {} );
    }

    return @results;
} ## end sub zone03

sub zone04 {
    my ( $class, $zone ) = @_;
    my @results;

    my $p = _retrieve_record_from_zone( $zone, $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_retry = $soa->retry;
        if ( $soa_retry < $SOA_RETRY_MINIMUM_VALUE ) {
            push @results,
              info(
                RETRY_MINIMUM_VALUE_LOWER => {
                    retry          => $soa_retry,
                    required_retry => $SOA_RETRY_MINIMUM_VALUE,
                }
              );
        }
        else {
            push @results,
              info(
                RETRY_MINIMUM_VALUE_OK => {
                    retry          => $soa_retry,
                    required_retry => $SOA_RETRY_MINIMUM_VALUE,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, info( NO_RESPONSE_SOA_QUERY => {} );
    }

    return @results;
} ## end sub zone04

sub zone05 {
    my ( $class, $zone ) = @_;
    my @results;

    my $p = _retrieve_record_from_zone( $zone, $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_expire  = $soa->expire;
        my $soa_refresh = $soa->refresh;
        if ( $soa_expire < $SOA_EXPIRE_MINIMUM_VALUE ) {
            push @results,
              info(
                EXPIRE_MINIMUM_VALUE_LOWER => {
                    expire          => $soa_expire,
                    required_expire => $SOA_EXPIRE_MINIMUM_VALUE,
                }
              );
        }
        if ( $soa_expire < $soa_refresh ) {
            push @results,
              info(
                EXPIRE_LOWER_THAN_REFRESH => {
                    expire  => $soa_expire,
                    refresh => $soa_refresh,
                }
              );
        }
        if ( not scalar @results ) {
            push @results,
              info(
                EXPIRE_MINIMUM_VALUE_OK => {
                    expire          => $soa_expire,
                    refresh         => $soa_refresh,
                    required_expire => $SOA_EXPIRE_MINIMUM_VALUE,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, info( NO_RESPONSE_SOA_QUERY => {} );
    }

    return @results;
} ## end sub zone05

sub zone06 {
    my ( $class, $zone ) = @_;
    my @results;

    my $p = _retrieve_record_from_zone( $zone, $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_minimum = $soa->minimum;
        if ( $soa_minimum > $SOA_DEFAULT_TTL_MAXIMUM_VALUE ) {
            push @results,
              info(
                SOA_DEFAULT_TTL_MAXIMUM_VALUE_HIGHER => {
                    minimum         => $soa_minimum,
                    highest_minimum => $SOA_DEFAULT_TTL_MAXIMUM_VALUE,
                }
              );
        }
        elsif ( $soa_minimum < $SOA_DEFAULT_TTL_MINIMUM_VALUE ) {
            push @results,
              info(
                SOA_DEFAULT_TTL_MAXIMUM_VALUE_LOWER => {
                    minimum        => $soa_minimum,
                    lowest_minimum => $SOA_DEFAULT_TTL_MINIMUM_VALUE,
                }
              );
        }
        else {
            push @results,
              info(
                SOA_DEFAULT_TTL_MAXIMUM_VALUE_OK => {
                    minimum         => $soa_minimum,
                    highest_minimum => $SOA_DEFAULT_TTL_MAXIMUM_VALUE,
                    lowest_minimum  => $SOA_DEFAULT_TTL_MINIMUM_VALUE,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, info( NO_RESPONSE_SOA_QUERY => {} );
    }

    return @results;
} ## end sub zone06

sub zone07 {
    my ( $class, $zone ) = @_;
    my @results;

    my $p = _retrieve_record_from_zone( $zone, $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_mname = $soa->mname;
        $soa_mname =~ s/[.]\z//smx;
        my $addresses_nb = 0;
        foreach my $address_type ( q{A}, q{AAAA} ) {
            my $p_mname = Zonemaster::Engine::Recursor->recurse( $soa_mname, $address_type );
            if ( $p_mname ) {
                if ( $p_mname->has_rrs_of_type_for_name( $address_type, $soa_mname ) ) {
                    $addresses_nb++;
                }
                if ( $p_mname->has_rrs_of_type_for_name( q{CNAME}, $soa_mname ) ) {
                    push @results,
                      info(
                        MNAME_IS_CNAME => {
                            mname => $soa_mname,
                        }
                      );
                }
                else {
                    push @results,
                      info(
                        MNAME_IS_NOT_CNAME => {
                            mname => $soa_mname,
                        }
                      );
                }
            } ## end if ( $p_mname )
        } ## end foreach my $address_type ( ...)
        if ( not $addresses_nb ) {
            push @results,
              info(
                MNAME_HAS_NO_ADDRESS => {
                    mname => $soa_mname,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, info( NO_RESPONSE_SOA_QUERY => {} );
    }

    return @results;
} ## end sub zone07

sub zone08 {
    my ( $class, $zone ) = @_;
    my @results;

    my $p = $zone->query_auth( $zone->name, q{MX} );
    if ( $p ) {
        my @mx = $p->get_records_for_name( q{MX}, $zone->name );
        for my $mx ( @mx ) {
            my $p2 = $zone->query_auth( $mx->exchange, q{CNAME} );
            if ( $p2 ) {
                if ( $p2->has_rrs_of_type_for_name( q{CNAME}, $mx->exchange ) ) {
                    push @results, info( MX_RECORD_IS_CNAME => {} );
                }
                else {
                    push @results, info( MX_RECORD_IS_NOT_CNAME => {} );
                }
            }
        }
    }
    else {
        push @results, info( NO_RESPONSE_MX_QUERY => {} );
    }

    return @results;
} ## end sub zone08

sub zone09 {
    my ( $class, $zone ) = @_;
    my @results;
    my $info;

    my $p = $zone->query_auth( $zone->name, q{MX} );

    if ( $p ) {
        if ( not $p->has_rrs_of_type_for_name( q{MX}, $zone->name ) ) {
            my $p_a    = _retrieve_record_from_zone( $zone, $zone->name, q{A} );
            my $p_aaaa = _retrieve_record_from_zone( $zone, $zone->name, q{AAAA} );
            if (
                ( not defined $p_a and not defined $p_aaaa )
                or (    ( not defined $p_a or not $p_a->has_rrs_of_type_for_name( q{A}, $zone->name ) )
                    and ( not defined $p_aaaa or not $p_aaaa->has_rrs_of_type_for_name( q{AAAA}, $zone->name ) ) )
              )
            {
                push @results, info( NO_MX_RECORD => {} );
            }
            else {
                my @as = defined $p_a ? $p_a->get_records_for_name( q{A}, $zone->name ) : ();
                my @aaas = defined $p_aaaa ? $p_aaaa->get_records_for_name( q{AAAA}, $zone->name ) : ();
                $info = join q{/}, map { $_ =~ /:/smx ? q{AAAA=} . $_->address : q{A=} . $_->address } ( @as, @aaas );
            }
        }
        else {
            my @mx = $p->get_records_for_name( q{MX}, $zone->name );
            for my $mx ( @mx ) {
                my $tmp = q{MX=};
                $tmp .= $mx->exchange;
                $tmp =~ s/[.]\z//smx;
                $info .= $tmp . q{/};
            }
            chop $info;
        }
        if ( not scalar @results ) {
            push @results, info( MX_RECORD_EXISTS => { info => $info } );
        }
    } ## end if ( $p )
    else {
        push @results, info( NO_RESPONSE_MX_QUERY => {} );
    }

    return @results;
} ## end sub zone09

sub zone10 {
    my ( $class, $zone ) = @_;
    my $name = name( $zone );
    my @results;

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) } ) {

        if ( _is_ip_version_disabled( $ns ) ) {
            next;
        }

        my $p = $ns->query( $name, q{SOA} );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                }
              );
            next;
        }
        else {
            my @soa = $p->get_records( q{SOA}, q{answer} );
            if ( scalar @soa ) {
                if ( scalar @soa > 1 ) {
                    push @results,
                      info(
                        MULTIPLE_SOA => {
                            ns      => $ns->name->string,
                            address => $ns->address->short,
                            count   => scalar @soa,
                        }
                      );
                }
                elsif ( lc( $soa[0]->owner ) ne lc( $name->fqdn ) ) {
                    push @results,
                      info(
                        WRONG_SOA => {
                            ns      => $ns->name->string,
                            address => $ns->address->short,
                            owner   => lc( $soa[0]->owner ),
                            name    => lc( $name->fqdn ),
                        }
                      );
                }
            } ## end if ( scalar @soa )
            else {
                push @results,
                  info(
                    NO_SOA_IN_RESPONSE => {
                        ns      => $ns->name->string,
                        address => $ns->address->short,
                    }
                  );
            }
        } ## end else [ if ( not $p ) ]
    } ## end foreach my $ns ( @{ Zonemaster::Engine::TestMethods...})
    if ( not scalar @results ) {
        push @results, info( ONE_SOA => {} );
    }

    return @results;
} ## end sub zone10

sub _retrieve_record_from_zone {
    my ( $zone, $name, $type ) = @_;

    # Return response from the first authoritative server that gives one
    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method5( $zone ) } ) {

        if ( _is_ip_version_disabled( $ns ) ) {
            next;
        }

        my $p = $ns->query( $name, $type );

        if ( defined $p and scalar $p->get_records( $type, q{answer} ) > 0 ) {
            return $p if $p->aa;
        }
    }

    return;
}

sub _is_ip_version_disabled {
    my $ns = shift;

    if ( not Zonemaster::Engine::Profile->effective->get( q{net.ipv4} ) and $ns->address->version == $IP_VERSION_4 ) {
        Zonemaster::Engine->logger->add( SKIP_IPV4_DISABLED => { ns => "$ns" } );
        return 1;
    }

    if ( not Zonemaster::Engine::Profile->effective->get( q{net.ipv6} ) and $ns->address->version == $IP_VERSION_6 ) {
        Zonemaster::Engine->logger->add( SKIP_IPV6_DISABLED => { ns => "$ns" } );
        return 1;
    }

    return;
}

1;

=head1 NAME

Zonemaster::Engine::Test::Zone - module implementing tests of the zone content in DNS, such as SOA and MX records

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Zone->all($zone);

=head1 METHODS

=over

=item all($zone)

Runs the default set of tests and returns a list of log entries made by the tests

=item tag_descriptions()

Returns a refernce to a hash with translation functions. Used by the builtin translation system.

=item metadata()

Returns a reference to a hash, the keys of which are the names of all test methods in the module, and the corresponding values are references to
lists with all the tags that the method can use in log entries.

=item version()

Returns a version string for the module.

=back

=head1 TESTS

=over

=item zone01($zone)

Check that master nameserver in SOA is fully qualified.

=item zone02($zone)

Verify SOA 'refresh' minimum value.

=item zone03($zone)

Verify SOA 'retry' value  is lower than SOA 'refresh' value.

=item zone04($zone)

Verify SOA 'retry' minimum value.

=item zone05($zone)

Verify SOA 'expire' minimum value.

=item zone06($zone)

Verify SOA 'minimum' (default TTL) value.

=item zone07($zone)

Verify that SOA master is not an alias (CNAME).

=item zone08($zone)

Verify that MX records does not resolve to a CNAME.

=item zone09($zone)

Verify that there is a target host (MX, A or AAAA) to deliver e-mail for the domain name.

=item zone10($zone)

Verify that the zone of the domain to be tested return exactly one SOA record.

=back

=cut
