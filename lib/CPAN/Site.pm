use warnings;
use strict;

package CPAN::Site;
use base 'CPAN';

our $reload_orig;
our $config_loader;
BEGIN {
  $reload_orig = \&CPAN::Index::reload;
  eval "require CPAN::HandleConfig";
  $config_loader = $@ ? 'CPAN::Config' : 'CPAN::HandleConfig';
}

# Add "CPAN" to the list of exported items
sub import
{  my $class  = shift;
   unshift @_, 'CPAN';

   my $import = CPAN->can('import');
   goto &$import;
}

$config_loader->load
    if $config_loader->can('load');

if(my $urls = $ENV{CPANSITE})
{   unshift @{$CPAN::Config->{urllist}}, split ' ', $urls;
}

my $last_time = 0;

no warnings 'redefine';
sub CPAN::Index::reload {
   my($cl, $force) = @_;
   my $time = time;

   # Need this code duplication since reload does not return something
   # meaningful

   my $expire = $CPAN::Config->{index_expire};
   $expire = 0.001 if $expire < 0.001;

   return if $last_time + $expire*86400 > $time
          && !$force;

   $last_time = $time;

   $reload_orig->(@_);
   $cl->rd_authindex($cl->reload_x("authors/01mailrc.txt.gz", '', $force));
   $cl->rd_modpacks($cl->reload_x("site/02packages.details.txt.gz",'',$force));
   $cl->rd_modlist($cl->reload_x("modules/03modlist.data.gz", '', $force));
}

1;

__END__

=chapter NAME

CPAN::Site - CPAN.pm subclass for adding site local modules

=chapter SYNOPSIS

  perl -MCPAN::Site -e shell
  cpansite shell                # alternative

  perl -MCPAN::Site -e 'install AnyModule'
  cpansite install AnyModule    # alternative

=chapter DESCRIPTION

This module adds access to site specific modules to the C<CPAN.pm> install
interface; it adds a set of site-specific, non-public domain modules to
the repository of the global CPAN.

The general idea is to have a local (pseudo) CPAN server which is asked
first. If the request fails -which is the usual case, except for own
modules-, CPAN.pm switches to the next URL in the list, which points to
a server in the world-wide CPAN network.

=chapter DETAILS

=section QUICK SETUP EXAMPLE FOR IMPATIENT

This explanation was contributed by Alex Efros.  There is also an
extended explanation in the manual page of the C<cpansite> script.

Let's say your (registered or un-registered) Pause-ID is IMPATIENT, :)
and you have private module in file Private-Module-1.23.tar.gz. You wish
to make it available from your own CPAN mirror (actually it's better to
call it "overlay" instead) on website http://impatient.net/ located in
directory /var/www/impatient.net/.

=subsection Configuring the server

 # cpan CPAN::Site
 # CPANSITE=/var/www/impatient.net/CPAN
 # USERID=I/IM/IMPATIENT
 # PUBLISH=$CPANSITE/authors/id/$USERID
 # mkdir -p $PUBLISH
 # cp Private-Module-1.23.tar.gz $PUBLISH
 # cpansite -vl index $CPANSITE

This nested C<I/IM/IMPATIENT/> directory is CPAN's way of avoiding
one huge directory with 5000 author names.  Your mirror only requires
one level, but it is cleaner to follow CPAN's practice.

You may also wish to add C<cpansite index> to cron and have it run every
hour or so.  This way you can just copy new modules to C<$PUBLISH>
and they become automatically available on your CPAN mirror after a while.
To do this you should run C<crontab -e> and add single line like this:

 CPANSITE=/var/www/impatient.net/CPAN
 0 * * * *   cpansite -l index $CPANSITE &>/dev/null

=subsection Configuring the clients

 # cpan CPAN::Site
 # cpansite shell
 cpan> o conf urllist unshift http://impatient.net/CPAN/
 cpan> o conf commit

Now clients should C<cpansite> command instead of C<cpan> to search,
install or update modules. The C<cpan> command will use the real CPAN's
indexes.

After doing above once, you can copy your C<~/.cpan/CPAN/MyConfig.pm>
file to other systems where you wish to have the same configuration.

=chapter SEE ALSO

The C<cpansite(1)> script.

=chapter AUTHOR

Mark Overmeer E<lt>perl@overmeer.netE<gt>.
Based on the original module by Ulrich Pfeifer E<lt>pfeifer@wait.deE<gt>.

=cut
