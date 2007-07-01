use ExtUtils::MakeMaker;

WriteMakefile
(

    NAME            => 'Sub::Autostub',
    VERSION         => 1.01,
    ABSTRACT_FROM   => './lib/Sub/Autostub.pm',
    PREREQ_PM =>
    {
        # standard distro, particular versions 
        # are unlikely to cause pain.

        strict          => 0,
        Carp            => 0,
        Symbol          => 0,
        Scalar::Util    => 0,

    },

);
