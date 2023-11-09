#JOB_SLOTS=16
ROOT_REPO=$(pwd)
ROOT_DEP=${1:-/tmp}
JOB_SLOTS=${2:-16}

# install compile-time dependencies
sudo apt-get -y install libstdc++6 gcc-multilib lua5.3 lua5.3-dev \
	libcurl4-openssl-dev libssl-dev libv8-dev libc-ares-dev libclang-dev libv8-dev \
	python3-venv make clang lld dotnet-sdk-6.0 \
	build-essential unzip 

# symlinks
#sudo ln -s /lib/x86_64-linux-gnu/libclang-15.so.15 /lib/x86_64-linux-gnu/libclang.so
sudo ln -s /usr/lib/x86_64-linux-gnu/libclang-10.so /usr/lib/x86_64-linux-gnu/libclang.so
sudo ln -s /usr/lib/x86_64-linux-gnu/libcurl.so /usr/lib/libcurl.so

# install python deps
python3 -m venv $ROOT_DEP/py-venv
. $ROOT_DEP/py-venv/bin/activate

# build natives
cd $ROOT_REPO/ext/natives
gcc -O2 -shared -fpic -o cfx.so -I/usr/include/lua5.3/ lua_cfx.c

mkdir -p inp out
curl --http1.1 -sLo inp/natives_global.lua http://runtime.fivem.net/doc/natives.lua

cd $ROOT_REPO/ext/native-doc-gen

ROOT_NATIVE_GEN=$(pwd)
LUA53=lua5.3
NODE=node            
YARN="$NODE $ROOT_NATIVE_GEN/yarn_cli.js"

# install yarn deps
cd $ROOT_NATIVE_GEN/../native-doc-tooling/

echo yarn
$YARN global add node-gyp@9.3.1
$YARN

cd $ROOT_NATIVE_GEN/../natives/

NATIVES_MD_DIR=$ROOT_NATIVE_GEN/../native-decls/native_md/ $LUA53 codegen.lua inp/natives_global.lua markdown server rpc

# make out dir
cd $ROOT
mkdir -p out && cd "$_"

# setup clang and build
$NODE $ROOT_NATIVE_GEN/../native-doc-tooling/index.js $ROOT_NATIVE_GEN/../native-decls/

mkdir -p $ROOT_NATIVE_GEN/../natives/inp/ || true

echo build2
NODE_PATH=$ROOT_NATIVE_GEN/../native-doc-tooling/node_modules/ $NODE $ROOT_NATIVE_GEN/../native-doc-tooling/build-template.js lua CFX > $ROOT_NATIVE_GEN/../natives/inp/natives_cfx_new.lua
rm $PWD/libclang.dll || true

# copy outputs
cd $ROOT
cp -a out/natives_test.json natives_cfx.json

# copy new
if [ -e $ROOT_NATIVE_GEN/../natives/inp/natives_cfx.lua ]; then
	if ! diff -q $ROOT_NATIVE_GEN/../natives/inp/natives_cfx_new.lua $ROOT_NATIVE_GEN/../natives/inp/natives_cfx.lua 2>&1 > /dev/null; then
		cp -a $ROOT_NATIVE_GEN/../natives/inp/natives_cfx_new.lua $ROOT_NATIVE_GEN/../natives/inp/natives_cfx.lua
	fi
else
	cp -a $ROOT_NATIVE_GEN/../natives/inp/natives_cfx_new.lua $ROOT_NATIVE_GEN/../natives/inp/natives_cfx.lua
fi


cd $ROOT_REPO/ext/natives

mkdir -p ~/natives/cfx-server/citizen/scripting/lua/
mkdir -p ~/natives/cfx-server/citizen/scripting/v8/

lua5.3 codegen.lua inp/natives_global.lua native_lua server > $ROOT_REPO/code/components/citizen-scripting-lua/include/NativesServer.h
lua5.3 codegen.lua inp/natives_global.lua lua server > ~/natives/cfx-server/citizen/scripting/lua/natives_server.lua
lua5.3 codegen.lua inp/natives_global.lua js server > ~/natives/cfx-server/citizen/scripting/v8/natives_server.js
lua5.3 codegen.lua inp/natives_global.lua dts server > ~/natives/cfx-server/citizen/scripting/v8/natives_server.d.ts

cat > $ROOT_REPO/code/client/clrcore/NativesServer.cs << EOF
#if IS_FXSERVER
using ContextType = CitizenFX.Core.fxScriptContext;

namespace CitizenFX.Core.Native
{
EOF
  
lua5.3 codegen.lua inp/natives_global.lua enum server >> $ROOT_REPO/code/client/clrcore/NativesServer.cs
lua5.3 codegen.lua inp/natives_global.lua cs server >> $ROOT_REPO/code/client/clrcore/NativesServer.cs
  
cat >> $ROOT_REPO/code/client/clrcore/NativesServer.cs << EOF
}
#endif
EOF

lua5.3 codegen.lua inp/natives_global.lua cs_v2 server > $ROOT_REPO/code/client/clrcore-v2/Native/NativesServer.cs

lua5.3 codegen.lua inp/natives_global.lua rpc server > ~/natives/cfx-server/citizen/scripting/rpc_natives.json

# done with natives

# download and build premake
curl --http1.1 -sLo $ROOT_DEP/premake.zip https://github.com/premake/premake-core/releases/download/v5.0.0-beta1/premake-5.0.0-beta1-src.zip

cd /tmp
unzip -q premake.zip
rm premake.zip
cd premake-*

cd build/gmake*.unix/
make -j${JOB_SLOTS}
cd ../../

mv bin/release/premake5 /usr/local/bin
cd ..

rm -rf premake-*

## SETUP-CUTOFF

# build CitizenFX
cd $ROOT_REPO/code

premake5 gmake2 --game=server --cc=clang --dotnet=msnet
cd build/server/linux

export CFLAGS="-fno-plt"
export CXXFLAGS="-D_LIBCPP_ENABLE_CXX17_REMOVED_AUTO_PTR -Wno-deprecated-declarations -Wno-invalid-offsetof -fno-plt"
export LDFLAGS="-Wl,--build-id -fuse-ld=lld -ldl"

make clean
make clean config=release verbose=1
make -j${JOB_SLOTS} config=release
