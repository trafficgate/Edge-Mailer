# $Id: Mailer.pm,v 1.13 2003/07/01 09:00:45 miyagawa Exp $
package Edge::Mailer;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(mailer);
$VERSION = '0.16';

use Carp;
use FileHandle;
use Jcode;
use Net::SMTP;
use Sys::Hostname;

use constant TIMEOUT_DEFAULT	=> 30;
use constant SMTPHOST_DEFAULT	=> 'localhost';

use constant RFC_COMPLIANT_VERSION => 0.64;

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self = bless {
	timeout => TIMEOUT_DEFAULT,
	smtphost => SMTPHOST_DEFAULT,
    }, $class;
    $self->_init(@_);
    return $self;
}

sub mailer { __PACKAGE__->new(@_); }

sub _init {
    my $self = shift;
    while (my ($key, $val) = splice(@_, 0, 2)) {
	$self->{$key} = $val;
    }
    return $self;
}

sub _prepare_send {
    my $self = shift;

    # 必須フィールドがなければ warning and return
    foreach my $field (qw( to sender message )) {
	defined $self->{$field} or do {
	    carp __PACKAGE__.":$field is required!";
	    return;
	};
    }

    # RCPT 複数の場合は array reference
    my @rcpt = ref($self->{to}) eq 'ARRAY'
	? @{$self->{to}} : ($self->{to});
    # 最初は EUC にしておく
    my $message = Jcode->new($self->{message})->h2z->euc;

    # Time-Zone diff
    my $date = rfc2822date(localtime());
    my $fqdn = $self->{smtphost} ne SMTPHOST_DEFAULT ?
	$self->{smtphost} : $ENV{SERVER_NAME} || Sys::Hostname::hostname;

    # smtphost で指定した時はIP-addrかもしれない
    # IP-addr の場合は ...@[11.11.11.11] のようにする
    $fqdn =~ s/^(\d+\.\d+\.\d+\.\d+)$/[$1]/;

    my $message_id = sprintf '<%s.%s.%s@%s>', time, $$, random_str(6), $fqdn;

    # デフォルトヘッダ作成
    my %header = (From => $self->{sender},
                  'X-Sender' => $self->{sender},
                  To => join(', ', @rcpt),
		  Subject => '(no-title)',
                  Date => $date,
                  'Message-Id' => $message_id,
                  'X-Mailer' => "Edge Mailer $VERSION",
                  'Content-Type' => 'text/plain; charset="ISO-2022-JP"',
                  'MIME-Version' => '1.0',
                  'Content-Transfer-Encoding' => '7bit');
    %header = map { lc($_) => $header{$_} } keys %header;

    # $message の最初の空行までをヘッダとみなす
    my ($header, $body) = split /\n\n/, $message, 2;

    # フォームの \r\n をカット
    $body =~ s/\r\n|\r/\n/g;
    
    # extract headers
    my %orig_hdr;
    my $current_hdr;
    for (split /\n/, $header) {
	if (/^(\S+?):\s+(.+)$/) {
	    $current_hdr = lc($1);
	    $orig_hdr{$current_hdr} = $2;
	} elsif (/^\s+(.+)$/) {
	    $orig_hdr{$current_hdr} .= ' '. $1;
	}
    }

    # merge
    %orig_hdr = (%header, %orig_hdr);

    # MIME-Encode
    my $encoder = Jcode->VERSION >= RFC_COMPLIANT_VERSION
	? sub { Jcode->new($_[0])->mime_encode() }
        : \&encode_mime;
    my %mime_header = map { 
	$_ => _include_multibyte($orig_hdr{$_})
	    ? $encoder->($orig_hdr{$_}) : $orig_hdr{$_};
    } keys %orig_hdr;

    $self->{_mail_header} = \%mime_header;
    $self->{_mail_body} = $body;
    $self->{_mail_to} = \@rcpt;
}

sub send {
    my $self = shift;
    $self->_prepare_send;

    my $smtp = Net::SMTP->new($self->{smtphost}, 
			      Timeout => $self->{timeout},
			      Hello => Sys::Hostname::hostname)
	or do { 
	    carp __PACKAGE__.":$self->{smtphost}: $!";
	    return;
	};

    my($mailheader, $mailbody) = $self->_pretty_print;
    ($smtp->mail($self->{sender}) and
     $smtp->to(@{$self->{_mail_to}}) and
     $smtp->data() and
     $smtp->datasend($mailheader) and
     $smtp->datasend("\n") and
     $smtp->datasend($mailbody) and
     $smtp->dataend() and
     $smtp->quit) or do {
	 carp __PACKAGE__.":SMTP communication failed: $!";
	 return;
     };

    $self->_cleanup_send;
    return 1;
}

sub _pretty_print {
    my $self = shift;

    my $filtersub = $self->{filter} || sub { Jcode->new($_[0])->jis; };
    my $mailbody = $filtersub->($self->{_mail_body});

    my $mailheader = join '', map { uc_hiphen($_) . ': ' . $self->{_mail_header}->{$_} ."\n" } keys %{$self->{_mail_header}};
    return $mailheader, $mailbody;
}

sub _cleanup_send {
    my $self = shift;
    delete $self->{_mail_header};
    delete $self->{_mail_body};
    delete $self->{_mail_to};
}

sub send_via_sendmail {
    my($self, $sendmail) = @_;
    $self->_prepare_send;
    my($mailheader, $mailbody) = $self->_pretty_print;
    my $command = sprintf "%s -f %s %s",
	$sendmail, $self->{sender}, join(' ', @{$self->{_mail_to}});
    my $handle = FileHandle->new("| $command");
    $handle->print($mailheader);
    $handle->print("\n");
    $handle->print($mailbody);
    $handle->close;
    $self->_cleanup_send;
}

sub encode_mime {
    my @field = split /\s+/, shift;
    my @encoded = map { _include_multibyte($_)
			    ? _dirty_encode($_) : $_ } @field;
    return join ' ', @encoded;
}

sub _include_multibyte {
    my $twoBytes = '[\x8E\xA1-\xFE][\xA1-\xFE]';
    my $threeBytes = '\x8F[\xA1-\xFE][\xA1-\xFE]';

    return $_[0] =~ /$twoBytes|$threeBytes/;
}

sub _dirty_encode {
    require MIME::Base64;
    my $word = shift;
    return '=?ISO-2022-JP?B?' . MIME::Base64::encode_base64(Jcode->new($word)->iso_2022_jp, '') . '?=';
}

sub uc_hiphen {
    my $word = shift;
    return join '-', map { ucfirst } split /-/, $word;
}


sub random_str($) {
    my ($length) = @_;

    # from perldoc -f srand
    # This statement is something OS specific
    #srand (time ^ $$ ^ unpack "%L*", `ps axww | gzip`);
    
    my @string = (0..9, 'A'..'Z', 'a'..'z');
    return join '', map { $string[rand $#string] } (0..$length-1);
}

sub rfc2822date {
    my @t = @_; # localtime.
    my $diff = calc_diff();
    my @days = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
    my @months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @t;
    return sprintf("%s, %s %s %04d %02d:%02d:%02d $diff", 
		   $days[$wday], $mday, $months[$mon], $year + 1900, $hour, $min, $sec);
}

# gmtime と localtime から time-zone を計算
# '+0900' のような文字列を返す
sub calc_diff {
    use Time::Local;
    my $diff_time = time - timelocal(gmtime(time));

    use integer;
    my $diff_hour = $diff_time / (60 * 60);
    my $diff_min =  abs(($diff_time % (60 * 60)) / 60);
    local $ENV{LANG}; # no LANG=ja
    return sprintf '%+03d%02d', $diff_hour, $diff_min;
}


1;
__END__

=head1 NAME

Edge::Mailer - Standard Mailer of Livin' On The EDGE.

=head1 SYNOPSIS

  use Edge::Mailer;

  my $mailer = Edge::Mailer->new(to => $to,
                                 sender => $sender,
                                 message => $message);
  $mailer->send;

  # Same as above
  mailer(to => $to, sender => $sender, message => $message)->send;

  # specify SMTP server and Timeout
  my $mailer = Edge::Mailer->new(to => $to,
                                 sender => $sender,
                                 message => $message,
                                 smtphost => $smtphost,
                                 timeout => 30);

  # filters message-body before sending.
  # this is invalid for RFC, but sometimes required for i-mode
  my $mailer = Edge::Mailer->new(to => 'someone@docomo.ne.jp',
                                 sender => $sender,
                                 message => $message,
                                 filter => sub { Jcode->new($_[0])->z2h->sjis });

=head1 DESCRIPTION

This module provides easy way for sending mail. Required headers like '
Message-Id', 'Date'... are automatically assigned by this
module. Useful when MTA on your SMTP server is a strict qmail...

=head1 AUTHOR

Tatsuhiko Miyagwa <miyagawa@edge.co.jp>
Livin' On The Edge, Limited. 

=head1 SEE ALSO

perl(1), Net::SMTP.

=cut

