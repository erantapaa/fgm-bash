#
# After soucing this file the following commands become available.
#
#  f file-pattern
#  g pattern
#  m id command...

mtags_dir="$HOME/tmp"

if [ ! -d $mtags_dir ]; then
  mkdir $mtags_dir
fi

export MTAGS="$mtags_dir/mtags-$$"

function f () {
  run_perl_fgm 'f' "$@"
}

function g () {
  run_perl_fgm 'g' "$@"
}

function m {
  case "$#" in
    0|1) run_perl_fgm 'm' "$@" ;;
    *) cmd=$(run_perl_fgm 'm' "$@")
       history -s "$cmd"
       $cmd
  esac
}

function check_perl_fgm () {
  run_perl_fgm "-cw"
}

function run_perl_fgm () {
  read -r -d '' SCRIPT <<'__EOS__'
#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use IO::Handle;

sub use_plus;
sub just_path;
sub use_offset_or_plus;

my $RED = "\e[01;31m";
my $PURPLE = "\e[35m";
my $GREEN =  "\e[32m";
my $BOLD_WHITE = "\e[37;40m";
my $OFF = "\e[m";

my $COLORIZED = {
  off    => $OFF,
  id     => $OFF,
  match  => $RED,
  path   => $PURPLE,
  lineno => $GREEN,
};

my $NOT_COLORIZED = { };

# --- start of configurable settings

my $MTAGS_VAR = "MTAGS";      # environment variable for the MTAGS files

my $F_COLOR_SCHEME = $NOT_COLORIZED;
my $G_COLOR_SCHEME = $COLORIZED;

sub exec_args {
  my ($m, $leaf, $cmd) = @_;
  if ($leaf eq "less") {
    return use_offset_or_plus(100_000);
  } elsif ($leaf =~ m,\A(emacs|vi|view|more)\z,) {
    return \&use_plus;
  }
  return \&just_path;
}

# --- end of configurable settings

my $PATH_RE = qr/\A(\/|\.)/;

sub color {
  my ($cs, $class, $text) = @_;
  if (defined(my $on = $cs->{$class})) {
    $on . $text . $cs->{off}
  } else {
    $text;
  }
}

# --- m

sub usage_m {
  die "Usage: m [id [command...] ]\n";
}

sub main_m {
  my $matches = match_reader();

  if (@ARGV == 0) {
    m_show_all($matches);
  } elsif (@ARGV == 1) {
    m_show_one($matches, $ARGV[0]);
  } else {
    my $id = shift(@ARGV);
    my $args = m_command($matches, $id, \@ARGV);
    print join(' ', @$args), "\n";
    # exec($args) or die "unable to exec $$args[0]: $!\n";
  }
}

sub m_show_all {
  my $matches = shift;
  while (my $m = $matches->()) {
    my $line = $m->{lineno} ? ":".$m->{lineno} : "";
    print $m->{id}." ".$m->{path}.$line."\n";
  }
}

sub m_show_one {
  my ($matches, $id) = @_;
  my $m = find_match_or_die($matches, $id);
  my $line = $m->{lineno} // "";
  print $m->{path}." ".$line."\n";
}

sub m_command {
  my ($matches, $id, $argv) = @_;
  my $m = find_match_or_die($matches, $id);
  my $cmd = $argv->[0];
  my $leaf = basename($cmd);
  my @args = exec_args($leaf, $cmd)->($m);

  return [ @$argv, @args ];
}

# --- s

sub usage_s {
  die "Usage: s id command args\n";
}

sub main_s {
  usage_s() unless @ARGV >= 2;
  my $matches = match_reader();
  my $id = shift(@ARGV);
  my $args = m_command($matches, $id, \@ARGV);
  print join(' ', @$args), "\n";
}


# --- f

sub usage_f {
  die "Usage: f file-pattern...\n";
}

sub main_f {
  usage_f() unless @ARGV;

  # directories: /some/path or ./something
  # extensions: .ext
  # path elements: all else

  my (@exts, @elements, @dirs);

  while (@ARGV) {
    my $arg = shift(@ARGV);
    if ($arg =~ m/\A(\/|\.\/)/) {
      push(@dirs, $arg);
    } elsif ($arg =~ m,\A\.\w+\z,) {
      push(@exts, $arg);
    } else {
      push(@elements, $arg);
    }
  }

  my $pat =  "(?:" . join(".*?", map { quotemeta($_) } @elements) .")";
  if (@exts) {
    $pat .= "(?:" . join("|", map { quotemeta($_) } @exts ) .")" . "[^/]*\\z";
  }
  my $pattern = qr/$pat/i;

  my $files;
  if (@dirs) {
    $files = concat_all_files(@dirs);
  } else {
    $files = all_files("");
  } 

  my $mfh = match_writefh();
  my $writer = mk_file_writer($F_COLOR_SCHEME, $mfh);

  do_find($files, $writer, sub { $_[0] =~ m/$pattern/ });
}

sub do_find {
  my ($files, $writer, $filter) = @_;

  my $matches = 0;
  while (defined(my $f = $files->())) {
    if ($filter->($f->[0], $f->[1])) {
      $matches++;
      my $m = { id => $matches, path => $f->[0] };
      $writer->($m);
    }
  }
}

sub mk_file_writer {
  my ($cs, $fh) = @_;
  sub {
    my ($m) = @_;
    print $m->{id}.' '.$m->{path}."\n";
    write_match($fh, $m) if $fh;
  };
}

# --- g

sub usage_g {
  die "Usage: g pattern...\n";
}

sub main_g {
  usage_g() unless @ARGV;
  my @paths;
  my @patterns;

  if (@ARGV && $ARGV[0] eq "-d") {
    shift @ARGV;
    while (@ARGV) {
      my $arg = shift(@ARGV);
      last if $arg eq "--";
      if ($arg =~ $PATH_RE) {
        push(@paths, $arg);
      } else {
        push(@patterns, $arg);
      }
    }
    push(@patterns, @ARGV);
  } else {
    @patterns = @ARGV; 
  }

  my $p = "(".join(".*?", map { quotemeta($_) } @patterns).")";
  my $pattern = qr/$p/i;

  my $files;
  if (@paths) {
    $files = concat_all_files(@paths);
  } elsif (-t STDIN) {
    $files = all_files("");
  } else {
    $files = stdin_files();
  }

  my $mfh = match_writefh();
  my $writer = mk_grep_writer($G_COLOR_SCHEME, $mfh);
  my $once = 0;

  do_grep($files, $writer, $pattern, $once);
}

sub ellipses {
  my ($str, $start, $length) = @_;
  if ($length > 256) {
    return substr($str, $start, 32) . "..." . substr($str, $start+$length-32, 32)
  } else {
    return substr($str, $start, $length);
  }
}

sub fmt_parts {
  my ($line, $start, $length) = @_;

  my $pre   = ellipses($line, 0, $start);
  my $match = ellipses($line, $start, $length);
  my $post  = ellipses($line, $start+$length, length($line) - ($start+$length));
  return ($pre, $match, $post);
}

sub mk_grep_writer {
  my ($cs, $fh) = @_;
  # $cs is the color scheme
  sub {
    my ($m, $line, $equals) = @_;
    my $start = $equals->[0];
    my $length = $equals->[1];

    my ($pre, $match, $post) = fmt_parts($line, $start, $length);

    print color($cs, "id", $m->{id}). " ".
          color($cs, "path", $m->{path}) . ":" .
          color($cs, "lineno", $m->{lineno}) . ":" .
          $pre .
          color($cs, "match", $match) .
          $post;
    print "\n" unless substr($post,-1) eq "\n";
    if ($fh) {
      write_match($fh, $m);
    }
  };
}

sub do_grep {
  my ($files, $writer, $pattern, $once) = @_;

  my $matches = 0;
  while (my $f = $files->()) {
    my $path = $f->[0];
    grep_file($path, \$matches, $writer, $pattern, $once);
  }
}

sub grep_file {
  my ($path, $rmatches, $writer, $pattern, $once) = @_;

  open(my $fh, "<", $path) or do {
    warn "unable to read file $path: $!\n";
    return;
  };

  return unless -T $fh;

  while (<$fh>) {
    if (m/$pattern/) {
      $$rmatches++;
      my $m = { id => $$rmatches, path => $path, lineno => $., offset => tell($fh) - length($_) };
      $writer->($m, $_, [ $-[1], $+[1] - $-[1] ]);
      last if $once;
    }
  }

  close($fh);
}

# --- match object methods 

sub match_to_string {
  my ($m) = @_;

  my $buf = "id $m->{id}\npath $m->{path}\n";
  $buf .= "lineno $m->{lineno}\n" if defined($m->{lineno});
  $buf .= "offset $m->{offset}\n" if defined($m->{offset});
  $buf .= "end\n";

}

sub write_match {
  my ($fh, $m) = @_;

  print {$fh} match_to_string($m);
}

sub match_writefh {
  my $MTAGS_FILE = $ENV{$MTAGS_VAR};
  if (defined($MTAGS_FILE)) {
    open(my $fh, ">", $MTAGS_FILE) or do {
      warn "unable to write file $MTAGS_FILE: $!\n";
    };
    $fh->autoflush;
    return $fh;
  }
  return;
}

sub match_reader {
  my $MTAGS_FILE = $ENV{$MTAGS_VAR};
  unless (defined($MTAGS_FILE) && length($MTAGS_FILE)) {
    die "environment variable $MTAGS_VAR is not set\n";
  }
  return mk_match_reader($MTAGS_FILE);
}

sub mk_match_reader {
  my ($path) = @_;
  open(my $fh, "<", $path);
  unless ($fh) {
    return sub { undef };
  } else {
    return sub {
      while (<$fh>) {
        if (m/^id (\S+)/) {
          my $m = { id => $1 };
          while (<$fh>) {
            chomp;
            my ($k,$v) = split(' ', $_, 2);
            last if $k eq "end";
            $m->{$k} = $v;
          }
          return $m;
        }
      }
    }
  }
}

sub find_match_or_die {
  my ($matches, $id) = @_;

  my $m = find_match($matches, $id);
  unless ($m) {
    die "no match labelled '$id'\n";
  }
  return $m;
}

sub find_match {
  my ($matches, $id) = @_;

  while (my $m = $matches->()) {
    return $m if $m->{id} eq $id;
  }
  return;
}

sub use_offset_or_plus {
  my ($threshold) = @_;
  unless (defined($threshold) && $threshold > 0) {
    die "use_offset_or_plus: invalid threshold: $threshold";
  }
  sub {
    my ($m) = @_;
    if ($m->{offset} && $m->{offset} >= $threshold) {
      return ("+P$m->{offset}", $m->{path});
    } elsif ($m->{lineno}) {
      return ("+$m->{lineno}", $m->{path});
    } else {
      return $m->{path};
    }
  };
}

sub use_plus {
  my ($m) = @_;
  if ($m->{lineno}) {
    return ("+".$m->{lineno}, $m->{path});
  } else {
    return $m->{path};
  }
}

sub just_path {
  my ($m) = @_;
  return $m->{path};
}

# --- directory iterators

sub stdin_files {
  sub {
    while (<STDIN>) {
      chomp;
      return [ $_, basename($_) ];
    }
    return;
  };
}

sub concat_all_files {
  my @paths = @_;

  my $i;
  sub {
    while (1) {
      unless ($i) {
        return unless @paths;
        my $path = shift(@paths);
        if (-d $path) {
          $i = all_files($path);
        } else {
          return [ $path ];
        }
      }
      my $r = $i->();
      return $r if defined($r);
      $i = undef;
    }
  }
}

sub all_files {
  my ($dpath, $dh) = @_;

  unless ($dh) {
    my $dpath2 = $dpath eq "" ? "." : $dpath;
    opendir($dh, $dpath2) or die "unable to read directory $dpath2: $!\n";
  }

  # make sure $dpath ends in a /

  if ($dpath ne "") {
    $dpath .= "/" unless substr($dpath, -1) eq "/";
  }

  # create an iterator for all files beneath a directory
  my @dh = ($dh);
  my @dpath = ($dpath);
  sub {
    while (@dh) {
      while (defined(my $leaf = readdir($dh[$#dh]))) {
        next if $leaf eq "." || $leaf eq "..";
        my $path = $dpath[$#dpath].$leaf;
        if (-f $path) {
          return [ $path, $leaf ];
        } elsif (-d _ && ! -l $path && substr($leaf, 0, 1) ne ".") {
          my $ndh;
          if (opendir($ndh, $path)) {
            push(@dh, $ndh);
            push(@dpath, "$path/");
          } else {
            warn "unable to read directory $path: $!\n";
          }
        }
      }
      pop(@dh);
      pop(@dpath);
    }
    return;
  };
}

# --- main

sub main {
  unless (@ARGV) {
    die "bad usage\n";
  }
  my $p = shift(@ARGV);
  if ($p eq 'f') { main_f(); }
  elsif ($p eq 'g') { main_g(); }
  elsif ($p eq 'm') { main_m(); }
  else {
    die "bad usage: $p\n";
  }
}

main();
__EOS__
  perl -e "$SCRIPT" "$@"
}
