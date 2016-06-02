use strict;
use Test;
BEGIN { plan tests => 3 }

use Edge::Mailer;


ok(Edge::Mailer::encode_mime('aaa'), 'aaa');
ok(Edge::Mailer::encode_mime('�ۤ��ۤ�'), '=?ISO-2022-JP?B?GyRCJFskMiRbJDIbKEI=?=');
ok(Edge::Mailer::encode_mime('�ۤ��ۤ� aaa'), '=?ISO-2022-JP?B?GyRCJFskMiRbJDIbKEI=?= aaa');
