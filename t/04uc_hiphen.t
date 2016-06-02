use strict;
use Test;
BEGIN { plan tests => 2 }

use Edge::Mailer;

ok(Edge::Mailer::uc_hiphen('aaa'), 'Aaa');
ok(Edge::Mailer::uc_hiphen('aaa-aaa'), 'Aaa-Aaa');

