call fxd get-chrome
call prebuild.cmd

call fxd gen -game %PROGRAM%

cd code\build\%PROGRAM%\
IF %PROGRAM%==server ( cd windows )

"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MsBuild.exe" CitizenMP.sln -t:build -restore -p:RestorePackagesConfig=true -p:preferredtoolarchitecture=x64 -p:configuration=release -maxcpucount:4 -v:q -flp1:logfile=errors.txt;errorsonly
set MSBUILD_ERROR=%ERRORLEVEL%

IF %MSBUILD_ERROR% EQU 0 (
	echo Successfully build %PROGRAM%
) else (
	echo Failed to build %PROGRAM%, MSBuild returned with error code: %MSBUILD_ERROR%
	for /F "tokens=*" %%A in (myfile.txt) do echo "::error::%%A"
	exit /b %MSBUILD_ERROR%
)