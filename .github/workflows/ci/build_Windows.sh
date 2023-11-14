pwsh ./fxd.ps1 get-chrome
./prebuild.cmd

pwsh ./fxd.ps1 gen -game $PROGRAM

cd code/build/$PROGRAM/$([[ $PROGRAM = server ]] && echo windows || echo '')

"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MsBuild.exe" CitizenMP.sln -t:build -restore -p:RestorePackagesConfig=true -p:preferredtoolarchitecture=x64 -p:configuration=release -maxcpucount:4 -v:q -flp1:logfile=errors.txt;errorsonly
MSBUILD_ERROR=$?

if [[ $MSBUILD_ERROR -eq 0 ]]; then
	echo Successfully build $PROGRAM
else
	echo "::error::Failed to build $PROGRAM, MSBuild returned with error code: $MSBUILD_ERROR"
	while IFS= read -r LINE; do echo -e "\033[0;31m$LINE"; done < errors.txt
	exit $MSBUILD_ERROR
fi