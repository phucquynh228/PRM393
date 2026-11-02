[CmdletBinding()]
param([ValidateRange(1, 65535)][int]$Port = 8080)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $projectRoot
& (Join-Path $projectRoot 'mvnw.cmd') spring-boot:run "-Dspring-boot.run.arguments=--server.port=$Port"
exit $LASTEXITCODE
