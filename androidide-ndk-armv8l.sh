#!/bin/bash

fpath=$1
arch=$(uname -m)
_arch_=arm
downloaded=
sdk_root=${HOME}/android-sdk
ndk_root=$sdk_root/ndk
r26b_dir=$ndk_root/26.1.10909125
llvm_dir=$r26b_dir/toolchains/llvm/prebuilt
x86_llvm=$llvm_dir/linux-x86_64
arch_llvm=$llvm_dir/linux-$_arch_
x86_dir=$r26b_dir/prebuilt/linux-x86_64
arch_dir=$r26b_dir/prebuilt/linux-$_arch_

help() {
  cat << EOF
Usage: 
android-ndk-arm-setup.sh path/to/ndk.zip	Install ndk from path/to/ndk.zip
android-ndk-arm-setup.sh -h  			Display this help
android-ndk-arm-setup.sh 			Display this help
android-ndk-arm-setup.sh -d			Download and install ndk
EOF
}

download_ndk() {
  pkg update
  pkg upgrade -y
  pkg install wget -y
  echo "Downloading ndk"
  wget -q -O $1 https://github.com/lzhiyong/termux-ndk/releases/download/android-ndk/android-ndk-r26b-aarch64.zip
}

extract_ndk(){
  if [ ! -d $sdk_root ] || [ ! -d $ndk_root ]
  then
    echo $ndk_root not found
    mkdir -p $ndk_root
  fi

  if [ -d $r26b_dir ]
  then
    echo "Found $r26b_dir"
    echo "Removing $r26b_dir"
    rm -rf $r26b_dir
  fi

  pkg install unzip -y

  echo "Unzipping '$1' to '$ndk_root'"
  unzip -qq $1 -d $ndk_root
  mv $ndk_root/android-ndk-r26b $r26b_dir

  echo "Updating android*.toolchain.cmake"
  sed -i "s/ANDROID_HOST_TAG linux-aarch64/ANDROID_HOST_TAG linux-$_arch_/g" $r26b_dir/build/cmake/android.toolchain.cmake
  sed -i "s/ANDROID_HOST_TAG linux-aarch64/ANDROID_HOST_TAG linux-$_arch_/g" $r26b_dir/build/cmake/android-legacy.toolchain.cmake
  ln -s $x86_llvm $arch_llvm
  ln -s $x86_dir $arch_dir
}

patch_pkg(){
  pkg_dir=$arch_llvm/bin/$1
  pkg_dep=$2
  if [ -z $pkg_dep ]
  then
    pkg_dep=$1
  fi

  rm $pkg_dir
  echo "#!/bin/sh" > $pkg_dir
  echo "$pkg_dep \$@"   >> $pkg_dir
  chmod a+rx $pkg_dir
}


copy_libraries(){
  echo Copying static libraries
  for arch_src_dir in aarch64    arm    i386    riscv64    x86_64
  do
    for arch_dst_dir in aarch64-linux-android    arm-linux-androideabi    i686-linux-android    riscv64-linux-android    x86_64-linux-android
    do
      if [[ "$arch_dst_dir" == $arch_src_dir* ]] ||  [[ "$arch_src_dir" == "i"*"86"* &&  "$arch_dst_dir" == "i"*"86"* ]]
      then
        #echo "    ... from .../linux-aarch64/lib/clang/17/lib/linux/$arch_src_dir/  to  .../linux-arm/sysroot/usr/lib/$arch_dst_dir"
        #for src_lib in $arch_llvm/lib/clang/17/lib/linux/$arch_src_dir/*
        #do
        #  echo " from $src_lib"
        #  echo " to   $arch_llvm/sysroot/usr/lib/$arch_dst_dir"
        #  cp $src_lib $arch_llvm/sysroot/usr/lib/$arch_dst_dir
        #done

        for src_lib in libatomic.a libunwind.a
        do
          cp $arch_llvm/lib/clang/17/lib/linux/$arch_src_dir/$src_lib $arch_llvm/sysroot/usr/lib/$arch_dst_dir
        done

      fi
    done
  done
}

copy_rt_lib(){
#/data/data/com.itsaky.androidide/files/usr/lib/clang/17/lib/linux/libclang_rt.builtins-i686-android.a:
  for _arch__ in aarch64    arm    i686    riscv64    x86_64
  do
    cp $arch_llvm/lib/clang/17/lib/linux/libclang_rt.builtins-${_arch__}-android.a ${HOME}/../usr/lib/clang/17/lib/linux/
  done
}

install_ndk(){
  extract_ndk $@
  pkg install clang -y
  patch_pkg clang
  patch_pkg clang++ clang
  patch_pkg ld.lld lld
  copy_libraries
  copy_rt_lib
  patch_pkg llvm-strip
}

if [ -z "$fpath" ] ||  [ "$fpath" = "-h" ]
then
  help
else
  if [ "$fpath" = "-d" ]
  then
    fpath="android-ndk-arm.zip"
    download_ndk $fpath
    downloaded="true"
  fi
  install_ndk $fpath
  if [ "$downloaded" = "true" ]
  then
    echo "Removing $fpath"
    rm $fpath
  fi
fi
