eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
    if $running_under_some_shell; # convertRelease.pl
#*************************************************************************
# Copyright (c) 2002 The University of Chicago, as Operator of Argonne
#     National Laboratory.
# Copyright (c) 2002 The Regents of the University of California, as
#     Operator of Los Alamos National Laboratory.
# EPICS BASE Versions 3.13.7
# and higher are distributed subject to a Software License Agreement found
# in file LICENSE that is included with this distribution. 
#*************************************************************************
#
# convertRelease.pl,v 1.14.2.16 2005/11/30 21:44:55 jba Exp
#
# Parse configure/RELEASE file(s) and generate a derived output file.
# Modified for DLS use by Nick Rees, 16 Sep 2005.
#

use Cwd qw(cwd abs_path);
use Getopt::Std;
use strict;

my ($cwd, $arch, $top, $hostarch, $iocroot, $root, $outfile, $relfile, %macros, @apps);
our ($opt_a, $opt_T, $opt_t, $opt_h);

$cwd = UnixPath(cwd());

getopt "ahtT";

if ($opt_a) {
    $arch = $opt_a;
} else {		# Look for O.<arch> in current path
    $_ = $cwd;
    ($arch) = /.*\/O.([\w-]+)$/;
}

$hostarch = $arch;
$hostarch = $opt_h if ($opt_h);

if ($opt_T) {
    $top = $opt_T;
} else {		# Find $top from current path
    # This approach is only possible under iocBoot/* and configure/*
    $top = $cwd;
    $top =~ s/\/iocBoot.*$//;
    $top =~ s/\/configure.*$//;
}

# The IOC may need a different path to get to $top
if ($opt_t) {
    $iocroot = $opt_t;
    $root = $top;
    while (substr($iocroot, -1, 1) eq substr($root, -1, 1)) {
	chop $iocroot;
	chop $root;
    }
}

unless (@ARGV == 1) {
    print "Usage: convertRelease.pl [-a arch] [-h hostarch] [-T top] [-t ioctop] outfile\n";
    print "   where outfile is be one of:\n";
    print "\tcheckRelease - checks consistency with support apps\n";
    print "\tcdCommands - generate cd path strings for vxWorks IOCs\n";
    print "\tenvPaths - generate epicsEnvSet commands for other IOCs\n";
    print "\tmsiPaths - send msi substitutions from RELEASE macros to stdout\n";
    print "\tmsiIncludes - missing docs\n";
    print "\tmsiDataIncludes - missing docs\n";
    print "\tvdctPaths - send vdct paths from RELEASE macros to stdout\n";
    print "\tdataPaths - send data paths from RELEASE macros to stdout\n";
    print "\tCONFIG_APP_INCLUDE - additional build variables\n";
    print "\tRULES_INCLUDE - supports installable build rules\n";
    print "\tcheckDLSRelease - missing docs\n";
    exit 2;
}
$outfile = $ARGV[0];

# TOP refers to this application
%macros = (TOP => LocalPath($top));
@apps   = ("TOP");	# Records the order of definitions in RELEASE file

# Read the RELEASE file(s)
$relfile = "$top/configure/RELEASE";
die "Can't find $relfile" unless (-f $relfile);
&readReleaseFiles($relfile, \%macros, \@apps);
&expandRelease(\%macros, \@apps);


# This is a perl switch statement:
for ($outfile) {
    /CONFIG_APP_INCLUDE/ and do { &configAppInclude;	last; };
    /RULES_INCLUDE/	 and do { &rulesInclude;	last; };
    /cdCommands/	 and do { &cdCommands;		last; };
    /envPaths/  	 and do { &envPaths;		last; };
    /msiPaths/  	 and do { &msiPaths;		last; };
    /msiIncludes/	 and do { &msiIncludes;		last; };
    /msiDataIncludes/	and do { &msiDataIncludes;	last; };
    /dataPaths/  	 and do { &dataPaths;		last; };
    /vdctPaths/  	 and do { &vdctPaths;		last; };
    /checkRelease/	 and do { &checkRelease;	last; };
    /checkDLSRelease/	 and do { &checkDLSRelease;	last; };
    die "Output file type \'$outfile\' not supported";
}

#
# Parse all relevent configure/RELEASE* files and includes
#
sub readReleaseFiles {
    my ($relfile, $Rmacros, $Rapps) = @_;

    return unless (-r $relfile);
    &readRelease($relfile, $Rmacros, $Rapps);
    if ($hostarch) {
	my ($hrelfile) = "$relfile.$hostarch.Common";
	&readRelease($hrelfile, $Rmacros, $Rapps) if (-r $hrelfile);
    }
    if ($arch) {
	my ($crelfile) = "$relfile.Common.$arch";
	&readRelease($crelfile, $Rmacros, $Rapps) if (-r $crelfile);
	if ($hostarch) {
	    my ($arelfile) = "$relfile.$hostarch.$arch";
	    &readRelease($arelfile, $Rmacros, $Rapps) if (-r $arelfile);
	}
    }
}

#
# Parse a configure/RELEASE file and its includes.
#
# NB: This subroutine also appears in base/src/makeBaseApp/makeBaseApp.pl
# If you make changes here, they will be needed there as well.
#
sub readRelease {
    my ($file, $Rmacros, $Rapps) = @_;
    # $Rmacros is a reference to a hash, $Rapps a ref to an array
    my ($pre, $var, $post, $macro, $path);
    local *IN;
    open(IN, $file) or die "Can't open $file: $!\n";
    while (<IN>) {
	chomp;
	s/\r$//;		# Shouldn't need this, but sometimes...
	s/\s*#.*$//;		# Remove trailing comments
	s/\s+$//;		# Remove trailing whitespace
	next if /^\s*$/;	# Skip blank lines
	
	# Expand all already-defined macros in the line:
	# while (my ($pre,$var,$post) = /(.*)\$\((\w+)\)(.*)/) {
	#     last unless (exists $Rmacros->{$var});
	#     $_ = $pre . $Rmacros->{$var} . $post;
	# }

	# Handle "<macro> = <path>"
	my ($macro, $path) = /^\s*(\w+)\s*=\s*(.*)/;
	if ($macro ne "") {
		$macro="TOP" if $macro =~ /^INSTALL_LOCATION/ ;
		if (exists $Rmacros->{$macro}) {
			delete $Rmacros->{$macro};
		} else {
			push @$Rapps, $macro;
		}
	    $Rmacros->{$macro} = $path;
	    next;
	}
	# Handle "include <path>" syntax
	($path) = /^\s*-?include\s+(.*)/;
	&readRelease($path, $Rmacros, $Rapps) if (-r $path);
    }
    close IN;
}

sub expandRelease {
    my ($Rmacros, $Rapps) = @_;
    # Expand any (possibly nested) macros that were defined after use
    while (my ($macro, $path) = each %$Rmacros) {
	while (my ($pre,$var,$post) = $path =~ /(.*)\$\((\w+)\)(.*)/) {
	    $path = $pre . $Rmacros->{$var} . $post;
	    $Rmacros->{$macro} = $path;
	}
    }
}

sub configAppInclude {
    my @includes = grep !/^(TOP|TEMPLATE_TOP)$/, @apps;
    
    unlink($outfile);
    open(OUT,">$outfile") or die "$! creating $outfile";
    print OUT "# Do not modify this file, changes made here will\n";
    print OUT "# be lost when the application is next rebuilt.\n\n";

    my ($app, $path);

    if ($arch) {
	print OUT "export TOP\n";
	foreach $app (@includes) {
	    print OUT "export ${app}\n";
	}
	foreach $app (@includes) {
	    $path = $macros{$app};
	    next unless (-d "$path/bin/$hostarch");
	    print OUT "${app}_HOST_BIN = \$(strip \$($app))/bin/\$(EPICS_HOST_ARCH)\n";
	}
	foreach $app (@includes) {
	    $path = $macros{$app};
	    next unless (-d "$path/lib/$hostarch");
	    print OUT "${app}_HOST_LIB = \$(strip \$($app))/bin/\$(EPICS_HOST_ARCH)\n";
	}
	foreach $app (@includes) {
	    $path = $macros{$app};
	    next unless (-d "$path/bin/$arch");
	    print OUT "${app}_BIN = \$(strip \$($app))/bin/$arch\n";
	}
	foreach $app (@includes) {
	    $path = $macros{$app};
	    next unless (-d "$path/lib/$arch");
	    print OUT "${app}_LIB = \$(strip \$($app))/lib/$arch\n";
	}
	# We can't just include TOP in the foreach list:
	# 1. The lib directory probably doesn't exist yet, and
	# 2. We need an abolute path but $(TOP_LIB) is relative
	foreach $app (@includes) {
	    $path = $macros{$app};
	    next unless (-d "$path/lib/$arch");
	    print OUT "SHRLIB_SEARCH_DIRS += \$(${app}_LIB)\n";
	}
    }
    foreach $app (@includes) {
	$path = $macros{$app};
	next unless (-d "$path/include");
	print OUT "RELEASE_INCLUDES += -I\$(strip \$($app))/include/os/\$(OS_CLASS)\n";
	print OUT "RELEASE_INCLUDES += -I\$(strip \$($app))/include\n";
    }
    foreach $app (@includes) {
	$path = $macros{$app};
	next unless (-d "$path/dbd");
	print OUT "RELEASE_DBDFLAGS += -I \$(strip \$($app))/dbd\n";
    }
    close OUT;
}

sub rulesInclude {
    my @includes = grep !/^(TOP|TEMPLATE_TOP|EPICS_BASE)$/, @apps;
    
    unlink($outfile);
    open(OUT,">$outfile") or die "$! creating $outfile";
    print OUT "# Do not modify this file, changes made here will\n";
    print OUT "# be lost when the application is next rebuilt.\n\n";
    
    foreach my $app (@includes) {
	my $path = $macros{$app};
	next unless (-r "$path/configure/RULES_BUILD");
	print OUT "RULES_TOP:=\$($app)\n";
	print OUT "-include \$(strip \$(RULES_TOP))/configure/RULES_BUILD\n";
    }
    close OUT;
}

sub cdCommands {
    die "Architecture not set (use -a option)" unless ($arch);
    my @includes = grep !/^TEMPLATE_TOP$/, @apps;
    
    unlink($outfile);
    open(OUT,">$outfile") or die "$! creating $outfile";
    
    my $startup = $cwd;
    $startup =~ s/^$root/$iocroot/o if ($opt_t);
    
    print OUT "startup = \"$startup\"\n";
    
    my $ioc = $cwd;
    $ioc =~ s/^.*\///;	# iocname is last component of directory name
    
    print OUT "putenv \"ARCH=$arch\"\n";
    print OUT "putenv \"IOC=$ioc\"\n";
    
    foreach my $app (@includes) {
	my $iocpath = my $path = $macros{$app};
	$iocpath =~ s/^$root/$iocroot/o if ($opt_t);
	my $app_lc = lc($app);
	print OUT "$app_lc = \"$iocpath\"\n" if (-d $path);
	print OUT "putenv \"$app=$iocpath\"\n" if (-d $path);
	print OUT "${app_lc}bin = \"$iocpath/bin/$arch\"\n" if (-d "$path/bin/$arch");
    }
    close OUT;
}

sub envPaths {
    die "Architecture not set (use -a option)" unless ($arch);
    my @includes = grep !/^TEMPLATE_TOP$/, @apps;
    
    unlink($outfile);
    open(OUT,">$outfile") or die "$! creating $outfile";
    
    my $ioc = $cwd;
    $ioc =~ s/^.*\///;	# iocname is last component of directory name
    
    print OUT "epicsEnvSet(ARCH,\"$arch\")\n";
    print OUT "epicsEnvSet(IOC,\"$ioc\")\n";
    
    foreach my $app (@includes) {
	my $iocpath = my $path = $macros{$app};
	$iocpath =~ s/^$root/$iocroot/o if ($opt_t);
	print OUT "epicsEnvSet($app,\"$iocpath\")\n" if (-d $path);
    }
    close OUT;
}

sub checkRelease {
    my $status = 0;
    delete $macros{TOP};
    delete $macros{TEMPLATE_TOP};
    
    while (my ($app, $path) = each %macros) {
	my %check = (TOP => $path);
	my @order = ();
	my $relfile = "$path/configure/RELEASE";
	&readReleaseFiles($relfile, \%check, \@order);
	&expandRelease(\%check, \@order);
	delete $check{TOP};
	
	while (my ($parent, $ppath) = each %check) {
	    if (exists $macros{$parent} &&
		abs_path($macros{$parent}) ne abs_path($ppath)) {
		print "\n" unless ($status);
		print "Definition of $parent conflicts with $app support.\n";
		print "In this application configure/RELEASE defines\n";
		print "\t$parent = $macros{$parent}\n";
		print "but $app at $path has\n";
		print "\t$parent = $ppath\n";
		$status = 1;
	    }
	}
    }
    print "\n" if ($status);
    exit $status;
}

sub msiPaths {
    my @includes = grep !/^TEMPLATE_TOP$/, @apps;

    print "-MINSTALL=\"".abs_path($macros{TOP})."\"";

    foreach my $app (grep !/^TOP$/, @includes) {
      if (-d $macros{$app}) {
	my $iocpath = $macros{$app};
	$iocpath =~ s/^$root/$iocroot/o if ($opt_t);
	print " -M$app=\"$iocpath\"";
      }
    }
}

sub msiIncludes {
    my @includes = grep !/^TEMPLATE_TOP$/, @apps;

    foreach my $app (grep !/^TOP$/, @includes) {
      if (-d "$macros{$app}/db") {
	print " -I$macros{$app}/db";
      }
    }
}

sub msiDataIncludes {
    my @includes = grep !/^TEMPLATE_TOP$/, @apps;

    foreach my $app (grep !/^TOP$/, @includes) {
      if (-d "$macros{$app}/data") {
	print " -I$macros{$app}/data";
      }
    }
}

sub vdctPaths {
    my @includes = grep !/^TEMPLATE_TOP$/, @apps;

    print "-DEPICS_DB_INCLUDE_PATH=.:".abs_path($macros{TOP})."/dbd:".abs_path($macros{TOP})."/db";

    foreach my $app (grep !/^TOP$/, @includes) {
      print ":$macros{$app}/dbd:$macros{$app}/db" if (-d $macros{$app});
    }
}

sub dataPaths {
    my @includes = grep !/^TEMPLATE_TOP$/, @apps;

    print abs_path($macros{TOP})."/data";

    foreach my $app (grep !/^TOP$/, @includes) {
      print ":$macros{$app}/data" if (-d $macros{$app});
    }
}

sub epicsRelease {
  # Find applicable EPICS_RELEASE
  my $epics;

  if ( defined $macros{EPICS_BASE} ) { $epics=$macros{EPICS_BASE}; }
  elsif ( defined $ENV{EPICS_BASE} ) { $epics=$ENV{EPICS_BASE}; }

  $epics =~ s,^.*/(R[1-9]\.[0-9]+\.[0-9]+[^/]*)/.*$,\1,;
  return $epics;
}

sub checkPath {
    my ($app,$path,$epicsRelease) = @_;
    my $status=0;

    foreach my $prefix ("/home/diamond","/dls_sw/prod","/dls_sw/work") {
	if ( $path =~ m,^$prefix, && $path !~ m,^$prefix/$epicsRelease, ) {
	  print "\n" if ($status);
	  print "Definition of $path\n";
	  print "in $app support conflicts with EPICS release of $epicsRelease.\n";
	  $status = 1;
	}
    }

    return $status;
}

           
sub checkDLSRelease {
    my $status = 0;
    my $epicsRelease=&epicsRelease;
    delete $macros{TOP};
    delete $macros{TEMPLATE_TOP};

    while (my ($app, $path) = each %macros) {
	my %check = (TOP => $path);
	my @order = ();
	my $relfile = "$path/configure/RELEASE";
	$relfile = "$path/config/RELEASE" if ( ! -f $relfile );
	&readReleaseFiles($relfile, \%check, \@order);
	&expandRelease(\%check, \@order);
	delete $check{TOP};

        if ( &checkPath( $app, $path, $epicsRelease ) ) {
	  $status = 1;
	}
	
	while (my ($parent, $ppath) = each %check) {
	    if (exists $macros{$parent} &&
		abs_path($macros{$parent}) ne abs_path($ppath)) {
		print "\n" if ($status);
		print "Definition of $parent conflicts with $app support.\n";
		print "In this application configure/RELEASE defines\n";
		print "\t$parent = $macros{$parent}\n";
		print "but $app at $path has\n";
		print "\t$parent = $ppath\n";
		$status = 1;
	    }

            if ( &checkPath( $parent, $ppath, $epicsRelease ) ) {
		$status = 1;
	    }
	}

    }
    print "\n" if ($status);
    exit $status;
}

# Path rewriting rules for various OSs
# These functions are duplicated in src/makeBaseApp/makeBaseApp.pl
sub UnixPath {
    my ($newpath) = @_;
    if ($^O eq "cygwin") {
       $newpath =~ s|\\|/|go;
       $newpath =~ s%^([a-zA-Z]):/%/cygdrive/$1/%;
    } elsif ($^O eq 'sunos') {
       $newpath =~ s(^\/tmp_mnt/)(/);
    }
    return $newpath;
}

sub LocalPath {
    my ($newpath) = @_;
    if ($^O eq "cygwin") {
       $newpath =~ s%^/cygdrive/([a-zA-Z])/%$1:/%;
    } elsif ($^O eq "darwin") {
       # These rules are likely to be site-specific
       $newpath =~ s%^/private/var/auto\.home/%/home/%;    # APS
    }
    return $newpath;
}
