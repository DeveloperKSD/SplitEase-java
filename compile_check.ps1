Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)
$files = Get-ChildItem -Path "src" -Recurse -Filter "*.java" | Select-Object -ExpandProperty FullName
$cp = "lib\okhttp-4.12.0.jar;lib\okio-jvm-3.6.0.jar;lib\gson-2.10.1.jar;lib\kotlin-stdlib-1.9.10.jar"
if (-not (Test-Path "out")) { New-Item -ItemType Directory -Path "out" | Out-Null }
& javac -cp $cp -d out $files 2>&1
