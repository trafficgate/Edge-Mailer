use strict;
use Test;
BEGIN { plan tests => 5 }

use Edge::Mailer;

my $m = new Edge::Mailer;

ok(ref($m) eq 'Edge::Mailer');
ok($m->{timeout} == Edge::Mailer::TIMEOUT_DEFAULT);
ok($m->{smtphost} eq Edge::Mailer::SMTPHOST_DEFAULT);

$m = new Edge::Mailer to => 'foo@bar.org', sender => 'bar@bax.com';

ok($m->{to} eq 'foo@bar.org');
ok($m->{sender} eq 'bar@bax.com');
