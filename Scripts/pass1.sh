#!/bin/bash
# check if LFS is set
if [ -z ${LFS:?} ]; 
then 
  echo "LFS is not set"; 
else 
  echo "LFS is set"; 
fi
# print active LFS and directory
echo $LFS
echo $(pwd)
set -o xtrace
set -o verbose

jmpBuild () {
   if [ ! -f ./Build ]; then
        mkdir Build  
   fi
   cd Build
}

simpleMake () {
    make -j$(nproc)
    make install
}

simpleMake2 () {
    make -j$(nproc)
    make DESTDIR=$LFS install
}

standardMake () {
  ./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess)
  simpleMake2
}

cd $LFS/sources/binutils
jmpBuild
../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT \
             --disable-nls \
             --enable-gprofng=no \
             --disable-werror \
             --enable-default-hash-style=gnu
simpleMake
cd $LFS/sources/gcc
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
 ;;
esac
jmpBuild
../configure --target=$LFS_TGT \
             --prefix=$LFS/tools \
             --with-glibc-version=2.39 \
             --with-sysroot=$LFS \
             --with-newlib \
             --without-headers \
             --enable-default-pie \
             --enable-default-ssp \
             --disable-nls \
             --disable-shared \
             --disable-multilib \
             --disable-threads \
             --disable-libatomic \
             --disable-libgomp \
             --disable-libquadmath \
             --disable-libssp \
             --disable-libvtv \
             --disable-libstdcxx \
             --enable-languages=c,c++
simpleMake
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h
cd $LFS/sources/linux
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr
cd $LFS/sources/glibc
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
  ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac
patch -Np1 -i ../glibc-2.39-fhs-1.patch
jmpBuild
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr --host=$LFS_TGT \
                           --build=$(../scripts/config.guess) \
                           --enable-kernel=4.19 \
                           --with-headers=$LFS/usr/include \
                           --disable-nscd libc_cv_slibdir=/usr/lib
simpleMake2
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
echo 'int main(){}' | $LFS_TGT-gcc -xc -
readelf -l a.out | grep ld-linux
rm -v a.out
cd $LFS/sources/gcc/Build
rm -fr ./*
../libstdc++-v3/configure --host=$LFS_TGT \
                          --build=$(../config.guess) \
                          --prefix=/usr \
                          --disable-multilib \
                          --disable-nls \
                          --disable-libstdcxx-pch \
                          --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/13.2.0
simpleMake2
rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la
cd $LFS/sources/m4
standardMake
cd $LFS/sources/ncurses
sed -i s/mawk// configure
mkdir -p Build
pushd Build
  ../configure
  make -C include
  make -C progs tic
popd
./configure --prefix=/usr           \
            --host=$LFS_TGT         \
            --build=$(./config.guess) \
            --mandir=/usr/share/man \
            --with-manpage-format=normal \
            --with-shared           \
            --without-debug         \
            --without-ada           \
            --without-normal        \
            --enable-widec
simpleMake2
cd $LFS/sources/bash
jmpBuild
./configure --prefix=/usr                       \
            --build=$(support/config.guess) \
            --host=$LFS_TGT                     \
            --without-bash-malloc
simpleMake2

ln -fsv bash $LFS/bin/sh
cd $LFS/sources/coreutils
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime
simpleMake2
mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
cd $LFS/sources/diffutils
standardMake
cd $LFS/sources/findutils
standardMake
cd $LFS/sources/gawk
sed -i 's/extras//' Makefile.in
standardMake
cd $LFS/sources/grep
standardMake
cd $LFS/sources/gzip
./configure --prefix=/usr \
            --host=$LFS_TGT
simpleMake2
cd $LFS/sources/make
./configure --prefix=/usr   \
            --without-guile \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
simpleMake2
cd $LFS/sources/patch
standardMake
cd $LFS/sources/sed
standardMake
cd $LFS/sources/tar
standardMake
# xz-5.4.1 needs to be fixed with distroSetup.sh script
echo "need to fix xz-5.4.1 to be xz with out the version in the name"
cd $LFS/sources/xz-5.4.1
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.4.1
simpleMake2
rm -v $LFS/usr/lib/liblzma.la
#make sure the files are owned by lfs
sudo chown -R lfs $LFS