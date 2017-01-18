package Iamport::REST::Client;

use HTTP::Tiny;
use JSON qw/decode_json/;

=encoding utf8

=head1 NAME

Iamport::REST::Client - iamport REST API client

=head1 SYNOPSIS

    my $iamport     = Iamport::REST::Client->new( key => 'xxxx', secret => 'xxxx' );
    my $json_string = $iamport->payment($imp_uid);

=cut

our $IAMPORT_HOST = "https://api.iamport.kr";

=head1 METHODS

=head2 new( key => $key, secret => $secret )

    my $iamport = Iamport::REST::Client->new(key => $key, secret => $secret);

=cut

sub new {
    my ( $class, %args ) = @_;
    return unless $args{key};
    return unless $args{secret};

    my $self = {
        key    => $args{key},
        secret => $args{secret},
        http   => HTTP::Tiny->new(
            default_headers => {
                agent        => __PACKAGE__,
                content_type => 'application/json',
            }
        ),
    };

    bless $self, $class;
    return $self;
}

=head2 token

L<https://api.iamport.kr/#!/authenticate/getToken>

    my $token = $iamport->token;

=cut

sub token {
    my $self = shift;

    return $self->{token} if $self->{token};

    my $url = "$IAMPORT_HOST/users/getToken";
    my $res = $self->{http}->post_form( $url, { imp_key => $self->{key}, imp_secret => $self->{secret} } );
    unless ( $res->{success} ) {
        warn "$res->{status}: $res->{reason}";
        return;
    }

    my $hashref = decode_json( $res->{content} );
    return $self->{token} = $hashref->{response}{access_token};
}

=head2 payments(\%opts)

L<https://api.iamport.kr/#!/payments/getPaymentsByStatus>

    my $json = $iamport->payments({ status => $status, page => $page });

=over

=item status

=over

=item *

all (default) - 전체

=item *

ready - 미결제

=item *

paid - 결제완료

=item *

cancelled - 결제취소

=item *

failed - 결제실패

=back

=item page

page number - (default is C<1>)

=item from

Unix timestamp

=item to

Unix timestamp

=back

=cut

sub payments {
    my ( $self, $opts ) = @_;

    my $status = $opts->{status} || 'all';
    my $page   = $opts->{page}   || 1;
    my $from   = $opts->{from};
    my $to     = $opts->{to};

    my $url = "$IAMPORT_HOST/payments/status/$status?page=$page";
    $url .= "&from=$from" if $from;
    $url .= "&to=$to"     if $to;
    return $self->get($url);
}

=head2 payment($imp_uid)

L<https://api.iamport.kr/#!/payments/getPaymentByImpUid>

    my $json = $self->payment($imp_uid);

=cut

sub payment {
    my ( $self, $imp_uid ) = @_;
    return unless $imp_uid;

    my $url = "$IAMPORT_HOST/payments/$imp_uid";
    return $self->get($url);
}

=head2 find($merchant_uid)

L<https://api.iamport.kr/#!/payments/getPaymentByMerchantUid>

    my $json = $self->find($merchant_uid);

=cut

sub find {
    my ( $self, $merchant_uid ) = @_;
    return unless $merchant_uid;

    my $url = "$IAMPORT_HOST/payments/find/$merchant_uid";
    return $self->get($url);
}

=head2 search($merchant_uid, \%opts)

L<http://api.iamport.kr/#!/payments/getAllPaymentsByMerchantUid>

    my $json = $self->search($merchant_uid, { status => 'paid' });

=over

=item status

=over

=item *

C<undef> - 전체

=item *

ready - 미결제

=item *

paid - 결제완료

=item *

cancelled - 결제취소

=item *

failed - 결제실패

=back

=item page

page number - (default is C<1>)

=back

=cut

sub search {
    my ( $self, $merchant_uid, $opts ) = @_;
    return unless $merchant_uid;

    my $status = $opts->{status} || '';
    my $page   = $opts->{page}   || 1;

    my $url = "$IAMPORT_HOST/payments/findAll/$merchant_uid/$status?page=$page";
    return $self->get($url);
}

=head2 cancel(\%opts)

L<https://api.iamport.kr/#!/payments/cancelPayment>

    my $json = $self->cancel({ imp_uid => $imp_uid });

=over

=item imp_uid

=item merchant_uid

=item amount

=item reason

=item refund_holder

=item refund_bank

=item refund_account

=back

=cut

sub cancel {
    my ( $self, $opts ) = @_;

    return unless ( !$opts->{imp_uid} && !$opts->{merchant_uid} );

    my $url = "$IAMPORT_HOST/payments/cancel";
    return $self->post( $url, $opts );
}

=head2 create_prepare( $merchant_uid, $amount )

L<https://api.iamport.kr/#!/payments.validation/preparePayment>

    my $json = $iamport->create_prepare($mercharnt_uid, $amount);

=cut

sub create_prepare {
    my ( $self, $merchant_uid, $amount ) = @_;
    return unless $merchant_uid;
    return unless $amount;

    my $url = "$IAMPORT_HOST/payments/prepare";
    return $self->post( $url, { merchant_uid => $merchant_uid, amount => $amount } );
}

=head2 get_prepare( $merchant_uid )

L<https://api.iamport.kr/#!/payments.validation/getPaymentPrepareByMerchantUid>

    my $json = $iamport->get_prepare($merchant_uid);

=cut

sub get_prepare {
    my ( $self, $merchant_uid ) = @_;
    return unless $merchant_uid;

    my $url = "$IAMPORT_HOST/payments/prepare/$merchant_uid";
    return $self->get($url);
}

=head2 create_vbank( \%opts )

L<https://api.iamport.kr/#!/vbanks/createVbank>

    my $json = $iamport->create_vbank(\%opts);

=over

=item B<merchant_uid> - required

가맹점 거래 고유번호. 이미 결제가 이뤄진 적이 있는 merchant_uid로는 추가적인 가상계좌 생성이 불가능합니다.

=item B<amount> - required

결제금액

=item B<vbank_code> - required

은행구분코드

=over

=item 03 - 기업은행

=item 04 - 국민은행

=item 05 - 외환은행

=item 07 - 수협중앙회

=item 11 - 농협중앙회

=item 20 - 우리은행

=item 23 - SC 제일은행

=item 31 - 대구은행

=item 32 - 부산은행

=item 34 - 광주은행

=item 37 - 전북은행

=item 39 - 경남은행

=item 53 - 한국씨티은행

=item 71 - 우체국

=item 81 - 하나은행

=item 88 - 통합신한은행(신한, 조흥은행)

=item D1 - 동양종합금융증권

=item D2 - 현대증권

=item D3 - 미래에셋증권

=item D4 - 한국투자증권

=item D5 - 우리투자증권

=item D6 - 하이투자증권

=item D7 - HMC투자증권

=item D8 - SK증권

=item D9 - 대신증권

=item DA - 하나대투증권

=item DB - 굿모닝신한증권

=item DC - 동부증권

=item DD - 유진투자증권

=item DE - 메리츠증권

=item DF - 신영증권

=back

=item B<vbank_due> - required

가상계좌 입금기한 Unix timestamp

=item B<vbank_holder> - required

가상계좌 예금주명

=item name

주문명

=item buyer_name

주문자명

=item buyer_email

주문자 email

=item buyer_tel

주문자 전화번호

=item buyer_addr

주문자 주소

=item buyer_postcode

주문자 우편번호

=item notice_url

가상계좌 입금시 입금통지받을 URL. 선언되지 않으면 아임포트 관리자 페이지에 정의된 Notification URL값을 사용

=back

=cut

sub create_vbank {
    my ( $self, $opts ) = @_;
    return unless $opts->{merchant_uid};
    return unless $opts->{amount};
    return unless $opts->{vbank_code};
    return unless $opts->{vbank_due};
    return unless $opts->{vbank_holder};

    my $url = "$IAMPORT_HOST/vbanks";
    return $self->post( $url, $opts );
}

=head2 get($url)

    my $json = $iamport->get($url);

=cut

sub get {
    my ( $self, $url ) = @_;
    return unless $url;

    my $res = $self->{http}->get( $url, { headers => { Authorization => $self->token } } );
    unless ( $res->{success} ) {
        warn "$res->{status}: $res->{reason}";
        return;
    }

    return $res->{content};
}

=head2 post($url, \%body)

    my $json = $iamport->post($url, \%body);

=cut

sub post {
    my ( $self, $url, $body ) = @_;
    return unless $url;

    my $res = $self->{http}->post_form( $url, $body, { headers => { Authorization => $self->token } } );

    unless ( $res->{success} ) {
        warn "$res->{status}: $res->{reason}";
        return;
    }

    return $res->{content};
}

1;

__END__

=head1 COPYRIGHT and LICENSE

The MIT License (MIT)

Copyright (c) 2017 열린옷장

=cut
