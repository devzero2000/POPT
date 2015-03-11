#!/bin/sh
#
# $Id$
# autogen.sh: autogen.sh script for popt projects
#
# Copyright (c) 2010-2015 Elia Pinto <devzero2000@rpm5.org>
#
# This program have the same copyright notice as popt
# itself
#
# Global Function and Variables
#
_PROGNAME="$0"
#
red=; grn=; lgn=; blu=; std=; 
test "X$$TERM" != Xdumb \
&&  test -t 1 2>/dev/null  \
&& { \
  red='[0;31m'; \
  grn='[0;32m'; \
  lgn='[1;32m'; \
  blu='[1;34m'; \
  std='[m'; \
}
#
# git repository for autoconf config.guess and config.sub
#
_CONFIG_URL="http://git.savannah.gnu.org/gitweb/"
_CONFIG_GUESS_URL="${_CONFIG_URL}?p=config.git;a=blob_plain;f=config.guess;hb=HEAD"
_CONFIG_SUB_URL="${_CONFIG_URL}?p=config.git;a=blob_plain;f=config.guess;hb=HEAD"


Die()    {
        color="$red"
	echo "${color}${_PROGNAME}: Error: $@${std}" >&2
	exit 1
}

Notice() {
        color="$grn"
	echo "${color}${_PROGNAME}: $@${std}" 
}


# Function Used for checking the Version Used for building
# 
# Note this deviates from the version comparison in automake
# in that it treats 1.5 < 1.5.0, and treats 1.4.4a < 1.4-p3a
# but this should suffice as we won't be specifying old
# version formats or redundant trailing .0 in bootstrap.conf.
# If we did want full compatibility then we should probably
# use m4_version_compare from autoconf.
sort_ver() { # sort -V is not generally available
  ver1="$1"
  ver2="$2"

  # split on '.' and compare each component
  i=1
  while : ; do
    p1=$(echo "$ver1" | cut -d. -f$i)
    p2=$(echo "$ver2" | cut -d. -f$i)
    if [ ! "$p1" ]; then
      echo "$1 $2"
      break
    elif [ ! "$p2" ]; then
      echo "$2 $1"
      break
    elif [ ! "$p1" = "$p2" ]; then
      if [ "$p1" -gt "$p2" ] 2>/dev/null; then # numeric comparison
        echo "$2 $1"
      elif [ "$p2" -gt "$p1" ] 2>/dev/null; then # numeric comparison
        echo "$1 $2"
      else # numeric, then lexicographic comparison
        lp=$(printf "$p1\n$p2\n" | LANG=C sort -n | tail -n1)
        if [ "$lp" = "$p2" ]; then
          echo "$1 $2"
        else
          echo "$2 $1"
        fi
      fi
      break
    fi
    i=$(($i+1))
  done
}

get_version() {
  app=$1

  $app --version >/dev/null 2>&1 || return 1

  $app --version 2>&1 |
  sed -n '# extract version within line
          s/.*[v ]\{1,\}\([0-9]\{1,\}\.[.a-z0-9-]*\).*/\1/
          t done

          # extract version at start of line
          s/^\([0-9]\{1,\}\.[.a-z0-9-]*\).*/\1/
          t done

          d

          :done
          #the following essentially does s/5.005/5.5/
          s/\.0*\([1-9]\)/.\1/g
          p
          q'
}

check_versions() {
  ret=0

  while read app req_ver; do
    # Honor $APP variables ($TAR, $AUTOCONF, etc.)
    appvar=`echo $app | tr '[a-z]' '[A-Z]'`
    test "$appvar" = TAR && appvar=AMTAR
    eval "app=\${$appvar-$app}"
    inst_ver=$(get_version $app)
    if [ ! "$inst_ver" ]; then
      echo "Error: '$app' not found" >&2
      ret=1
    elif [ ! "$req_ver" = "-" ]; then
      latest_ver=$(sort_ver $req_ver $inst_ver | cut -d' ' -f2)
      if [ ! "$latest_ver" = "$inst_ver" ]; then
        echo "Error: '$app' version == $inst_ver is too old" >&2
        echo "       '$app' version >= $req_ver is required" >&2
        ret=1
      fi
    fi
  done

  return $ret
}

print_versions() {
  echo "Program    Min_version"
  echo "----------------------"
  printf "$buildreq"
  echo "----------------------"
  # can't depend on column -t
}

usage ( ) {

cat <<EOF
Usage: ${_PROGNAME} [-h|--help]  [-d|--download]

--help      Help on $NAME_OF_AUTOGEN usage
--download  Download the latest config.guess from gnulib

EOF

    return 0
}

download_gnulib_config_guess () {
    config_guess_temp="config.guess.$$.download"
    config_sub_temp="config.sub.$$.download"
    ret=1
    for __cmd in wget curl fetch ; do
	${__cmd} --version > /dev/null 2>&1
	ret=$?
	if [ ! $ret = 0 ] ; then
	    continue
        fi

	__cmd_version=`${__cmd} --version | head -n 1 | sed -e 's/^[^0-9]\+//' -e 's/ .*//'`

	opts=""
	case ${__cmd} in
	    wget)
		opts="--timeout=5  -O" 
		;;
	    curl)
		opts="--max-time=5 -o"
		;;
	    fetch)
		opts="-t 5 -f"
		;;
	esac

	eval "$__cmd \"${_CONFIG_GUESS_URL}\" $opts \"${config_guess_temp}\"" > /dev/null 2>&1
	if [ $? = 0 ] ; then
	    mv -f "${config_guess_temp}" ${_aux_dir}/config.guess
            eval "$__cmd \"${_CONFIG_SUB_URL}\" $opts \"${config_sub_temp}\"" > /dev/null 2>&1
	    if [ $? = 0 ] ; then
	        mv -f "${config_sub_temp}" ${_aux_dir}/config.sub
	        ret=0
	        break
	    fi
        fi
    done

    if [ ! $ret = 0 ] ; then
	Notice "Warning: config.{guess,sub} download failed from ${_CONFIG_URL}"
	rm -f "${config_guess_temp}"
	rm -f "${config_sub_temp}"
    fi
}

#######################
# Begin  Bootstrapping
#######################
# Build prerequisites
buildreq="\
autoconf   2.63
automake   1.14.1
autopoint  -
gettext    0.19
libtool	   1.5.22
"
##################
# argument check #
##################
ARGS="$*"
#
for arg in $ARGS ; do
    case "x$arg" in
	x--help) usage && exit 0;;
	x-[dD]) DOWNLOAD=yes ;;
	x--download) DOWNLOAD=yes ;;
	*)
	    echo "${_PROGNAME}:Unknown option: $arg"
	    echo
	    usage
	    exit 1
	    ;;
    esac
done
echo
Notice "Bootstrapping popt build system..."
echo
# Guess whether we are using configure.ac or configure.in
if test -f configure.ac; then
  conffile="configure.ac"
elif test -f configure.in; then
  conffile="configure.in"
else
  Die "could not find configure.ac or configure.in"
  echo
fi
#
# detect the aux dir
# for config.{sub,guess}
aux_dir="`grep AC_CONFIG_AUX_DIR $conffile | grep -v '.*#.*AC_CONFIG_AUX_DIR' | tail -${TAIL_N}1 | sed 's/^[      ]*AC_CONFIG_AUX_DIR(\(.*\)).*/\1/' | sed 's/.*\[\(.*\)\].*/\1/'`"
if test ! -d "$_aux_dir" 
then
        _aux_dir=.
fi
#
if ! printf "$buildreq" | check_versions; then test -f README-prereq &&
  test -f README-prereq &&
  echo
  echo "See README-prereq for notes on obtaining these prerequisite programs:" >&2
  echo
  print_versions
  exit 1
fi

# Libtool
libtoolize=`which glibtoolize 2>/dev/null`
case $libtoolize in
		/*) ;;
		*)  libtoolize=`which libtoolize 2>/dev/null`
	case $libtoolize in
    	/*) ;;
    	*)  libtoolize=libtoolize
    	esac
esac
if test -z "$libtoolize"; then
		Die "libtool not found."
		echo
fi
find . -name "autom4te.cache" | xargs rm -rf 
[ ! -d m4 ]        && mkdir m4
[ ! -d build-aux ] && mkdir build-aux
autoreconf -vfi
po_dir=./po
LANG=C
ls "$po_dir"/*.po 2>/dev/null |
              sed 's|.*/||; s|\.po$||' > "$po_dir/LINGUAS"

#
[ ${DOWNLOAD} = "yes" ] && download_gnulib_config_guess
echo
Notice "done.  Now you can run './configure'."
#######################
# End  Bootstrapping
#######################
