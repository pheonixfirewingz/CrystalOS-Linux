# check if LFS is set
if [ -z ${LFS:?} ]; then echo "LFS is not set"; else echo "LFS is set"; fi
# print active LFS and directory
echo $LFS
echo $(pwd)

LC_ALL=C 
PATH=/usr/bin:/bin

bail() { echo "FATAL: $1"; exit 1; }
grep --version > /dev/null 2> /dev/null || bail "grep does not work"
sed '' /dev/null || bail "sed does not work"
sort   /dev/null || bail "sort does not work"

ver_check()
{
   if ! type -p $2 &>/dev/null
   then 
     echo "ERROR: Cannot find $2 ($1)"; return 1; 
   fi
   v=$($2 --version 2>&1 | grep -E -o '[0-9]+\.[0-9\.]+[a-z]*' | head -n1)
   if printf '%s\n' $3 $v | sort --version-sort --check &>/dev/null
   then 
     printf "OK:    %-9s %-6s >= $3\n" "$1" "$v"; return 0;
   else 
     printf "ERROR: %-9s is TOO OLD ($3 or later required)\n" "$1"; 
     return 1; 
   fi
}

ver_kernel()
{
   kver=$(uname -r | grep -E -o '^[0-9\.]+')
   if printf '%s\n' $1 $kver | sort --version-sort --check &>/dev/null
   then 
     printf "OK:    Linux Kernel $kver >= $1\n"; return 0;
   else 
     printf "ERROR: Linux Kernel ($kver) is TOO OLD ($1 or later required)\n" "$kver";
     bail "Alias check failed";
     return 1; 
   fi
}

removeVersion() {
  local input_string="$1"
  local dont_check="$2"

  if [ "$dont_check" = true ] ; then
    echo "${input_string%-*}"
    return
  fi

  if [[ "$input_string" == *"_"* ]]; then
    # If the input string contains an underscore, extract data before the underscore
    echo "${input_string%_*}"
  else
    # If the input string does not contain an underscore, extract data before the last dash
    echo "${input_string%-*}"
  fi
}


removeExt() {
    local input_string="$1"
    if [[ "$input_string" == *".tar.gz"* ]]; then
        echo "${input_string%.tar.gz}"
    else
        if [[ "$input_string" == *".orig.tar.xz"* ]]; then
          echo "${input_string%.orig.tar.xz}"
        else
          echo "${input_string%.tar.xz}"
        fi
    fi
}

# Coreutils first because --version-sort needs Coreutils >= 7.0
ver_check Coreutils      sort     8.1 || bail "Coreutils too old, stop"
ver_check Bash           bash     3.2
ver_check Binutils       ld       2.13.1
ver_check Bison          bison    2.7
ver_check Diffutils      diff     2.8.1
ver_check Findutils      find     4.2.31
ver_check Gawk           gawk     4.0.1
ver_check GCC            gcc      5.2
ver_check "GCC (C++)"    g++      5.2
ver_check Grep           grep     2.5.1a
ver_check Gzip           gzip     1.3.12
ver_check M4             m4       1.4.10
ver_check Make           make     4.0
ver_check Patch          patch    2.5.4
ver_check Perl           perl     5.8.8
ver_check Python         python3  3.4
ver_check Sed            sed      4.1.5
ver_check Tar            tar      1.22
ver_check Texinfo        texi2any 5.0
ver_check Xz             xz       5.0.0
ver_kernel 6.0

if mount | grep -q 'devpts on /dev/pts' && [ -e /dev/ptmx ]
then echo "OK:    Linux Kernel supports UNIX 98 PTY";
else echo "ERROR: Linux Kernel does NOT support UNIX 98 PTY"; bail "Alias check failed"; fi

alias_check() {
   if $1 --version 2>&1 | grep -qi $2
   then printf "OK:    %-4s is $2\n" "$1";
   else printf "ERROR: %-4s is NOT $2\n" "$1"; bail "Alias check failed"; fi
}
echo "Aliases:"
alias_check awk GNU
alias_check yacc Bison
alias_check sh Bash

echo "Compiler check:"
if printf "int main(){}" | g++ -x c++ -
then echo "OK:    g++ works";
else echo "ERROR: g++ does NOT work"; fi
rm -f a.out

if [ "$(nproc)" = "" ]; then
   echo "ERROR: nproc is not available or it produces empty output"
else
   echo "OK: nproc reports $(nproc) logical cores are available"
fi
#all checks passed
echo "All checks passed, you can start the build now."
if [ -v DEBUG ] 
then
  set -o xtrace
  set -o verbose
fi
sudo mkdir -p $LFS/sources


if [ ! -v NO_DOWNLOAD ] 
then
for f in $(cat $(pwd)/Scripts/DistroSetupPackages)
do
    bn=$(basename $f)
    name=$(removeExt $bn)
    if ! test -d $LFS/sources/$(removeVersion $name true) ; 
    then
      sudo wget $f -O $LFS/sources/$bn
      sudo tar -xf $LFS/sources/$bn -C $LFS/sources
      if [[ "$LFS/sources/$bn" != *".patch"* ]]; 
      then
        sudo mv "$LFS/sources/$name" "$LFS/sources/$(removeVersion $name false)"
      fi
    fi

done;
fi
CWD=$(pwd)

cd $LFS/sources
sudo rm -if *.xz *.gz
cd gcc
sudo mv -v ../mpfr mpfr
sudo mv -v ../gmp gmp
sudo mv -v ../mpc mpc
cd ..
cd $CWD

sudo mkdir -pv $LFS/{bin,etc,lib,sbin,usr,var,lib64,tools}

if ! test $(id -u lfs) ; 
then

sudo groupadd lfs
sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
sudo usermod -aG lfs $(whoami)
sudo passwd lfs
sudo chown -v lfs $LFS/{usr,lib,var,etc,bin,sbin,tools,lib64,sources}
sudo chown -R lfs:lfs ~lfs
sudo chmod -R g+w ~lfs
sudo chmod -R u+w ~lfs

sudo adduser lfs sudo

dbhome=$(eval echo "~lfs")
sudo chown -v -R $(whoami) $dbhome
cat > $dbhome/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
sudo chown -v lfs $dbhome/.bash_profile

cat > $dbhome/.bashrc << EOF
set +h
umask 022
LFS=$LFS
export DIST_ROOT=$LFS
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
export MAKEFLAGS="-j$(nproc)"
EOF
sudo chown -v lfs $dbhome/.bashrc
sudo chown -v -R lfs $dbhome
fi
sudo cp $(pwd)/Scripts/pass1.sh $dbhome/pass1.sh
echo "xz package dose not work the same as most files so may need manual correction before running the pass1.sh script"
echo "switching to lfs user"
sudo su - lfs