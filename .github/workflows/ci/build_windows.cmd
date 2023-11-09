call fxd get-chrome
call prebuild.cmd

call fxd gen -game %PROGRAM%

cd code\build\%PROGRAM%\
IF %PROGRAM%==server ( cd windows )

"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MsBuild.exe" CitizenMP.sln -t:build -restore -p:RestorePackagesConfig=true -p:preferredtoolarchitecture=x64 -p:configuration=release -maxcpucount:4 -v:q