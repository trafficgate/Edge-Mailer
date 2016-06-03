use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	       => 'Edge::Mailer',
    'VERSION_FROM' => 'lib/Edge/Mailer.pm', # finds $VERSION
    'PREREQ_PM'    => {
        Test::More => 0.32,
        Socket     => 0,
    },
);
