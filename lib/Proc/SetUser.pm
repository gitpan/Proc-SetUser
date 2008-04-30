# $Id: SetUser.pm 11 2008-04-30 18:07:14Z dmartin $

package Proc::SetUser;

use warnings;
use strict;
use Carp;

our $verbose = 0;

BEGIN {
	use Exporter ();
	our ($VERSION,@ISA,@EXPORT);
	@ISA    = qw(Exporter);
	@EXPORT = qw(set_user);
	use version; $VERSION = qv('0.1');
}

sub set_user {
	my($user,$group,@sup_groups) = @_;
	my($uid,$gid,%sup_gids);
	my $is_int = qr/^(\d+)$/o;
	if ( !defined($user) ) {
		croak "set_user() called with no arguments";
	}
	# get ids
	if ( $user =~ $is_int ) {
		$uid = $1;
	}
	else {
		# get numeric uid if given non-numeric user name
		$uid = getpwnam($user);
		if ( !defined($uid) ) {
			croak "User '$user' does not exist";
		}
		if ( $uid !~ $is_int ) {
			croak "User id for '$user' is not an int.  "
				."This shouldn't ever happen";
		}
		$uid = $1;
	}
	# get primary gid
	if ( defined($group) && $group =~ $is_int ) {
		$gid = $1;
		if ( !getgrgid($gid) ) {
			croak "Primary group id '$gid' does not exist\n";
		}
	} 
	else {
		# use user's primary group if no primary group specified
		if ( !defined($group) ) {
			$gid = (getpwuid($uid))[3];
			if ( !defined($gid)) {
				croak "Failed to get primary group ID for uid '$uid'";
			}
		} 
		else {
			# get gid from group name 
			$gid = getgrnam($group);
			if ( !defined($gid) ) {
				croak "Primary group '$group' does not exist";
			}

		}
		if ( $gid !~ $is_int ) {
			croak "Primary group ID for '$user' is not an int.  "
				."This shouldn't ever happen";
		}
	}
	# get suppliemental groups
	my @dont_exist;
	foreach my $sup_group (@sup_groups) {
		my $sup_gid;
		if ( !defined($sup_group) ) {
			croak "Supplemental group list contains 'undef'";
		}
		if ( $sup_group =~ $is_int ) {
			$sup_gid = $1;
			if ( $sup_gid == $gid || defined($sup_gids{$sup_gid})) {
				# remove duplicates
				next;
			}
			if ( !getgrgid($sup_gid) ) {
				push(@dont_exist,$sup_group);
				next;
			}
		}
		else { 
			$sup_gid = getgrnam($sup_group);
			if ( !defined($sup_gid) ) {
				push(@dont_exist,$sup_group);
				next;
			}
			if ( $sup_gid !~ $is_int ) {
				croak "Supplemental group id for group '$sup_group' is "
					."not an int.  This shouldn't ever happen";
			}
			if ( $sup_gid == $gid || defined($sup_gids{$sup_gid}) ) {
				# duplicate
				next;
			}
		}
		$sup_gids{$sup_gid} = 1;
	}
	if ( @dont_exist ) {
		croak "Specified supplemental group(s) '".join("', '",@dont_exist)
			."' do(es) not exist(s)";
	} 
	# set gid
	$( = ($gid + 0); # ensure $gid is numeric, we already know it's an int
	# make sure it worked
	if ( $( !~ /^(\d+)/o ) {
		croak "GID is not an int!??!";
	}
	my $now_gid = $1;
	if ( $now_gid != $gid ) {
		croak "Failed to set gid: gid is '$now_gid' not '$gid'\n";
	}
	# set egid
	my $egid_string = $gid;
	if ( keys(%sup_gids) ) {
		$egid_string .= ' '.join(' ',sort(keys(%sup_gids)));
	}
	# $) lists primary group twice if it's your only group
	if ( keys(%sup_gids) == 0 ) {
		$egid_string .= ' '.$gid;
	}
	$) = $egid_string;
	# make sure it worked
	if ( $) ne $egid_string ) {
		# Order doesn't matter, so split, sort and rejoin to test.  
		my $now = join(' ',sort(split(' ',$))));
		my $want = join(' ',sort(split(' ',$egid_string)));
		if ( $now ne $want ) {
			croak "Failed to set egid: egid = '$)', not '$egid_string'";
		}
	}
	# set euid
	$> = $uid;
	# make sure it worked
	if ( $> != $uid ) {
		croak "Failed to set euid: euid = '$>', not '$uid'\n";
	}
	# set uid
	$< = $uid;
	# make sure it worked
	if ( $< != $uid ) {
		croak "Failed to set uid: uid = '$<', not '$uid'\n";
	}
	return undef;
}

1; # Magic true value required at end of module
__END__

=head1 NAME

B<Proc::SetUser> - carefully drop root privileges 

=head1 SYNOPSIS

	use Proc::SetUser;

	if ( $> != 0 ) {
		die "Run this as root!\n";
	}
	
	# do something with root privileges

	set_user('nobody');

	# do stuff without root privileges

  
=head1 DESCRIPTION

Dropping privileges is something that needs to be done right and can 
easily be done wrong.  Even if you know how to do it right, it takes a 
lot of boring code.  

=head1 USAGE

set_user(I<new_user>, [I<primary_group>] , [I<supplemental_group> ... ]);

This is the only function provided by B<Proc::SetUser>.  It is exported by 
default.  

B<set_user()> switches the uid, euid, gid, egid and reduces the suppliemental 
groups to those specified if any.

I<new_user> is the user name or numeric user id of the user whom 
you wish the process to run as.

I<primary_group> is the group name or numeric group id of the primary group.
If undefined, the primary group of the user I<new_user> is used.

I<suppliemental_group> is any group which you'd like the process to be a member of.  If undefined, all supplimental group memberships are dropped.

All names and groups are assumed to be numeric uids and numeric gids if 
they are integers.  Otherwise they are assumed to be user names or group names.

=head1 EXAMPLES

=over 4

=item *

set_user('jdoe');

Switch the uid and euid to 'jdoe'.
Switch the gid and egid to jdoe's primary group (probably 'jdoe' 
or 'users' but maybe not.)
Drop membership in any other groups.

=item * 

set_user('jdoe','users,'tape');

Switch the uid and euid to 'jdoe'.
Switch the gid and egid to 'users'. 
Add membership in the 'tape' group and drop membership in any other groups.

=item * 

set_user('jdoe',undef,'tape');

Switch the uid and euid to 'jdoe'.
Switch the gid and egid to jdoe's primary group (probably 'jdoe' 
or 'users' but maybe not.)
Add membership in the 'tape' group and drop membership in any other groups.

=back

=head1 DIAGNOSTICS

B<set_user()> returns undef on success and croaks on failure.


=head1 DISCUSSION

I've written code that drops privileges many times and here's some
of things I've forgotten to do at one time or another. Hence this module.

=over 4

=item Make sure you drop group membership as well as changing user id.

=item Handle suppliemental groups as well as the users primary group.

=item Check to make sure uids/gids really did change.

=item Check group membership without getting hung up about the order 
the groups are listed in.

=back

=head1 PORTABILITY

Obviously this module is pointless on an OS that doesn't have multiple users.
It I<should> work on any OS where $<,$>,$(,$) behave as expected.  

At this time this module is known to work on linux only.  

If you use this module on a different OS and it works, please email me at 
C<dmartin@cpan.org>.  If it doesn't work, please file a bug as described below

=head1 BUGS AND LIMITATIONS

This has only been tested on Linux.  
It probably works in most unixes.
It probably doesn't work in Windows.

I assume you want euid == uid and egid == gid.  If you don't I'd love 
to know why.

Please report any bugs or feature requests to
C<bug-process-dropprivs@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Dylan Martin  C<< <dmartin@cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008, Dylan Martin & Seattle Central Community College 
C<< <dmartin@cpan.org> >>. 

Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

=head1 DISCLAIMER

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.


