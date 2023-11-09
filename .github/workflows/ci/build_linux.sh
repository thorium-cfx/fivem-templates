#JOB_SLOTS=16
JOB_SLOTS=$(nproc --all); JOB_SLOTS=$(( JOB_SLOTS * 2 ))

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
python3 -m venv /tmp/py-venv
. /tmp/py-venv/bin/activate

pip install ply six Jinja2 MarkupSafe
		
git clone --depth=1 --quiet --shallow-submodules https://github.com/thorium-cfx/fivem-templates.git ~/fivem -c core.symlinks=true
cd ~/fivem
git submodule update --jobs=${JOB_SLOTS} --init --depth=1

# build natives
cd ~/fivem/ext/natives
gcc -O2 -shared -fpic -o cfx.so -I/usr/include/lua5.3/ lua_cfx.c

mkdir -p inp out
curl --http1.1 -sLo inp/natives_global.lua http://runtime.fivem.net/doc/natives.lua

cd ~/fivem/ext/native-doc-gen

ROOT=$(pwd)
LUA53=lua5.3
NODE=node            
YARN="$NODE $ROOT/yarn_cli.js"

# install yarn deps
cd $ROOT/../native-doc-tooling/

echo yarn
$YARN global add node-gyp@9.3.1
$YARN

cd $ROOT/../natives/

NATIVES_MD_DIR=$ROOT/../native-decls/native_md/ $LUA53 codegen.lua inp/natives_global.lua markdown server rpc

# make out dir
cd $ROOT
mkdir out || true

# enter out dir
cd out

echo build
whereis libclang.so
whereis libclang.so.1

# exit 0

# setup clang and build
$NODE $ROOT/../native-doc-tooling/index.js $ROOT/../native-decls/

mkdir -p $ROOT/../natives/inp/ || true

echo build2
NODE_PATH=$ROOT/../native-doc-tooling/node_modules/ $NODE $ROOT/../native-doc-tooling/build-template.js lua CFX > $ROOT/../natives/inp/natives_cfx_new.lua
rm $PWD/libclang.dll || true

# copy outputs
cd $ROOT
cp -a out/natives_test.json natives_cfx.json

# copy new
if [ -e $ROOT/../natives/inp/natives_cfx.lua ]; then
	if ! diff -q $ROOT/../natives/inp/natives_cfx_new.lua $ROOT/../natives/inp/natives_cfx.lua 2>&1 > /dev/null; then
		cp -a $ROOT/../natives/inp/natives_cfx_new.lua $ROOT/../natives/inp/natives_cfx.lua
	fi
else
	cp -a $ROOT/../natives/inp/natives_cfx_new.lua $ROOT/../natives/inp/natives_cfx.lua
fi


cd ~/fivem/ext/natives

mkdir -p ~/natives/cfx-server/citizen/scripting/lua/
mkdir -p ~/natives/cfx-server/citizen/scripting/v8/

lua5.3 codegen.lua inp/natives_global.lua native_lua server > ~/fivem/code/components/citizen-scripting-lua/include/NativesServer.h
lua5.3 codegen.lua inp/natives_global.lua lua server > ~/natives/cfx-server/citizen/scripting/lua/natives_server.lua
lua5.3 codegen.lua inp/natives_global.lua js server > ~/natives/cfx-server/citizen/scripting/v8/natives_server.js
lua5.3 codegen.lua inp/natives_global.lua dts server > ~/natives/cfx-server/citizen/scripting/v8/natives_server.d.ts

cat > ~/fivem/code/client/clrcore/NativesServer.cs << EOF
#if IS_FXSERVER
using ContextType = CitizenFX.Core.fxScriptContext;

namespace CitizenFX.Core.Native
{
EOF
  
lua5.3 codegen.lua inp/natives_global.lua enum server >> ~/fivem/code/client/clrcore/NativesServer.cs
lua5.3 codegen.lua inp/natives_global.lua cs server >> ~/fivem/code/client/clrcore/NativesServer.cs
  
cat >> ~/fivem/code/client/clrcore/NativesServer.cs << EOF
}
#endif
EOF

lua5.3 codegen.lua inp/natives_global.lua cs_v2 server > ~/fivem/code/client/clrcore-v2/Native/NativesServer.cs

lua5.3 codegen.lua inp/natives_global.lua rpc server > ~/natives/cfx-server/citizen/scripting/rpc_natives.json

# done with natives


# download and extract boost
cd /tmp
curl --http1.1 -sLo /tmp/boost.tar.bz2 https://runtime.fivem.net/client/deps/boost_1_71_0.tar.bz2

tar xf boost.tar.bz2
rm boost.tar.bz2

mv boost_* boost || true

export BOOST_ROOT=/tmp/boost/

# download and build premake
curl --http1.1 -sLo /tmp/premake.zip https://github.com/premake/premake-core/releases/download/v5.0.0-beta1/premake-5.0.0-beta1-src.zip

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
cd ~/fivem/code

premake5 gmake2 --game=server --cc=clang --dotnet=msnet
cd build/server/linux

export CFLAGS="-fno-plt"
export CXXFLAGS="-D_LIBCPP_ENABLE_CXX17_REMOVED_AUTO_PTR -Wno-deprecated-declarations -Wno-invalid-offsetof -fno-plt"
export LDFLAGS="-Wl,--build-id -fuse-ld=lld -ldl"

make clean
make clean config=release verbose=1
make -j${JOB_SLOTS} config=release
