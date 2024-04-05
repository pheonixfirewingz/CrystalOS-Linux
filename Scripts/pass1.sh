#!/bin/bash
# check if LFS is set
if [ -z ${LFS:?} ]; then echo "LFS is not set"; else echo "LFS is set"; fi
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
#find . -name "*.tar.xz" | while read filename; do if [ ! -f ./Build ]; then echo $filename; tar -xf $filename; fi; done;

cd $LFS/sources
cd binutils
jmpBuild
../configure --prefix=$LFS/tools --with-sysroot=$LFS --target=$LFS_TGT --disable-nls --enable-gprofng=no  --disable-werror --enable-default-hash-style=gnu
simpleMake
cd ../../gcc
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
 ;;
esac
jmpBuild
../configure --target=$LFS_TGT --prefix=$LFS/tools --with-glibc-version=2.39 --with-sysroot=$LFS --with-newlib --without-headers --enable-default-pie --enable-default-ssp --disable-nls     --disable-shared  --disable-multilib   --disable-threads --disable-libatomic  --disable-libgomp --disable-libquadmath     --disable-libssp  --disable-libvtv  --disable-libstdcxx  --enable-languages=c,c++
simpleMake
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h
cd ../linux
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr
cd ../glibc
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
../configure --prefix=/usr --host=$LFS_TGT --build=$(../scripts/config.guess) --enable-kernel=4.19 --with-headers=$LFS/usr/include --disable-nscd libc_cv_slibdir=/usr/lib
simpleMake2
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
echo 'int main(){}' | $LFS_TGT-gcc -xc -
readelf -l a.out | grep ld-linux
rm -v a.out
cd ../../gcc/Build
rm -fr ./*
../libstdc++-v3/configure --host=$LFS_TGT --build=$(../config.guess) --prefix=/usr --disable-multilib --disable-nls --disable-libstdcxx-pch --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/13.2.0
simpleMake2
rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la


#make sure the files are owned by lfs
sudo chown -R lfs $LFS