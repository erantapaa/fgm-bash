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
@include run-fgm.perl
__EOS__
  perl -e "$SCRIPT" "$@"
}

function gg () {
  run_ag "$@"
}

function run_ag () {
  read -r -d '' SCRIPT <<'__EOS__'
@include run-ag.perl
__EOS__
  perl -e "$SCRIPT" "$@"
}

