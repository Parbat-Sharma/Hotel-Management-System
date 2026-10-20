@echo off
rem Compiles the hotel app and starts it. Double-click this file, or run it from a terminal.
rem Needs: Java (JDK) installed, the MySQL connector jar, and config.properties next to this file.
cd /d "%~dp0"

set "JAR=%USERPROFILE%\Downloads\mysql-connector-j-26.7.0\mysql-connector-j-26.7.0\mysql-connector-j-26.7.0.jar"

if not exist "%JAR%" (
    echo Connector jar not found at:
    echo   %JAR%
    echo Edit the JAR line in run.bat to point at your mysql-connector-j-*.jar file.
    pause
    exit /b 1
)
if not exist "config.properties" (
    echo config.properties not found in %CD%
    echo Copy config.properties.example to config.properties and check the password in it.
    pause
    exit /b 1
)

if not exist "out" mkdir "out"

rem javac on Windows does not expand *.java, so write the file names into a list and pass the list (@file).
rem Forward slashes and quotes keep the folder name with a space ("dbms project") working.
if exist "out\sources.txt" del "out\sources.txt"
for %%f in ("dbms project\src\hotel\*.java") do echo "dbms project/src/hotel/%%~nxf">> "out\sources.txt"

javac -d out @out\sources.txt
if errorlevel 1 (
    echo Compile failed - see the messages above.
    pause
    exit /b 1
)

rem "dbms project\src" is on the classpath so the icon\*.png pictures are found.
java -cp "out;dbms project\src;%JAR%" hotel.splash
if errorlevel 1 pause
