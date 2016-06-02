use strict;
use Test;
BEGIN { plan tests => 10 }

use Edge::Mailer;

my $msg =<<"EOF";
To: Foo <foo\@bar.org>
From: Joo <joo\@aa.com>
Subject: This is a test

Test message.
EOF
    ;

my $m = new Edge::Mailer
    to => 'foo@bar.org',
    sender => 'joo@aa.com',
    message => $msg;

{
    # for Jcode::mime_encode()
    local $SIG{__WARN__} = sub {};
    $m->_prepare_send();
}

ok($m->{_mail_header}->{to}, qr/^Foo <foo\@bar\.org> ?$/);
ok($m->{_mail_header}->{from}, qr/^Joo <joo\@aa\.com> ?$/);
ok($m->{_mail_header}->{subject}, qr/^This is a test ?$/);
ok($m->{_mail_body} eq "Test message.\n");
ok($m->{_mail_to}->[0] eq 'foo@bar.org');

undef $m;

my $j_msg =<<"EOF";
To: てすと <test\@test.org>, 
 test <test\@test.com>
From: てすと <test\@test.org>
Subject: あいうえおかきくけこ
Message-Id: <my-own-message-id\@test.com>

テストです。
テストです。
EOF
    ;

$m = new Edge::Mailer 
    sender => 'test@test.org',
    to => ['test@test.org', 'test@test.com'],
    message => $j_msg;

{
    local $SIG{__WARN__} = sub {};
    $m->_prepare_send();
}

ok($m->{_mail_to}->[0] eq 'test@test.org' and
   $m->{_mail_to}->[1] eq 'test@test.com');
ok($m->{_mail_header}->{to}, qr/\Q=?ISO-2022-JP?B?GyRCJEYkOSRIGyhC?= <test\E\@\Qtest.org>, test <test\E\@\Qtest.com>\Q/);
ok($m->{_mail_header}->{from}, qr/\Q=?ISO-2022-JP?B?GyRCJEYkOSRIGyhC?= <test\E\@\Qtest.org>\E/);
ok($m->{_mail_header}->{subject}, qr/\Q=?ISO-2022-JP?B?GyRCJCIkJCQmJCgkKiQrJC0kLyQxJDMbKEI=?=\E/);
ok($m->{_mail_header}->{'message-id'}, qr/\Q<my-own-message-id\E\@\Qtest.com>\E/);


