use strict;
use warnings;
use Test::More;
use JSON qw/decode_json/;

use Iamport::REST::Client;

my $key    = $ENV{IAMPORT_API_KEY};
my $secret = $ENV{IAMPORT_API_SECRET};
my $client = Iamport::REST::Client->new( key => $key, secret => $secret );

unless ($client) {
    diag "not found IAMPORT_API_KEY and IAMPORT_API_SECRET";
    ok(1); # prevent 'More than one plan found in TAP output'
    done_testing;
    exit;
}

ok( $client,        'new' );
ok( $client->token, 'token' );

my $payments = $client->payments;
ok( $payments, 'payments' );

my $data         = decode_json($payments);
my $imp_uid      = $data->{response}{list}[0]{imp_uid};
my $merchant_uid = $data->{response}{list}[0]{merchant_uid};

ok( $client->payment($imp_uid),     'payment' ) if $imp_uid;
ok( $client->find($merchant_uid),   'find' )    if $merchant_uid;
ok( $client->search($merchant_uid), 'search' )  if $merchant_uid;

done_testing;
