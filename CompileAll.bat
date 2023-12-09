set msbuildPath=%MSBUILD_2022_PATH%
echo %msbuildPath%\MSBuild.exe

REM Freetype solution 
"%msbuildPath%\MSBuild.exe" Libraries/freetype/MSBuild.sln /p:configuration=Debug /p:Platform=x64
"%msbuildPath%\MSBuild.exe" Libraries/freetype/MSBuild.sln /p:configuration=Release /p:Platform=x64

REM tinyxml2 solution
"%msbuildPath%\MSBuild.exe" Libraries/tinyxml2/tinyxml2.sln /p:configuration=Debug /p:Platform=x64
"%msbuildPath%\MSBuild.exe" Libraries/tinyxml2/tinyxml2.sln /p:configuration=Release /p:Platform=x64

REM msdfgen
"%msbuildPath%\MSBuild.exe" msdfgen.sln /p:configuration=Debug /p:Platform=x64
"%msbuildPath%\MSBuild.exe" msdfgen.sln /p:configuration=Release /p:Platform=x64

PAUSE