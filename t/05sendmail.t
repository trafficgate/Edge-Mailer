# $Id: 05sendmail.t,v 1.1 2002/01/30 10:42:10 miyagawa Exp $
#
# Tatsuhiko Miyagawa <miyagawa@edge.co.jp>
# Livin' On The EDGE, Limited.
#

use strict;
use Test;
plan tests => 3;

use Edge::Mailer;
use FileHandle;

my $mail = Edge::Mailer->new(
    sender => 'miyagawa@bulknews.net',
    to => 'miyagawa@edge.co.jp',
    message => "To: foobar\nSubject: hoge\n\nFoobar\n",
);

$mail->send_via_sendmail('./t/sendmail');

my $out = do { my $in = FileHandle->new("t/output");
	       local $/; <$in> };

ok $out, qr/ARGV:-f,miyagawa\@bulknews\.net,miyagawa\@edge\.co\.jp/;
ok $out, qr/To: foobar/;
ok $out, qr/Subject: hoge/;

unlink 't/output';





