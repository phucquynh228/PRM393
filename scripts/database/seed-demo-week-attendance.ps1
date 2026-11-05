param(
    [Parameter(Mandatory = $true)][datetime]$WeekStart,
    [Parameter(Mandatory = $true)][datetime]$ThroughDate,
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$configText = Get-Content -LiteralPath (Join-Path $projectRoot 'src/main/resources/application.yml') -Raw
$jdbc = [regex]::Match($configText, 'jdbc:sqlserver://([^;]+);databaseName=([^;]+)').Groups
if ($jdbc.Count -ne 3) { throw 'Cannot read local SQL Server connection configuration.' }
$dbBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$dbBuilder['Data Source'] = $jdbc[1].Value.Replace(':', ',')
$dbBuilder['Initial Catalog'] = $jdbc[2].Value
$dbBuilder['User ID'] = [regex]::Match($configText, '(?m)^    username: (.+)$').Groups[1].Value.Trim()
$dbBuilder['Password'] = [regex]::Match($configText, '(?m)^    password: (.+)$').Groups[1].Value.Trim()
$dbBuilder['TrustServerCertificate'] = $true
$dbConn = New-Object System.Data.SqlClient.SqlConnection($dbBuilder.ConnectionString)
$dbConn.Open()
try {
    $outputDir = Join-Path $projectRoot 'target/data-seed'
    [void](New-Item -ItemType Directory -Path $outputDir -Force)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $mode = if ($Apply) { 'apply' } else { 'preview' }
    if ($Apply) {
        $backupCmd = $dbConn.CreateCommand()
        $backupCmd.CommandText = @'
SELECT
 COALESCE((SELECT sc.* FROM dbo.user_schedules sc WHERE sc.date BETWEEN @WeekStart AND @ThroughDate FOR JSON PATH), '[]') AS schedules,
 COALESCE((SELECT a.* FROM dbo.attendances a JOIN dbo.user_schedules sc ON sc.id=a.schedule_id
  WHERE sc.date BETWEEN @WeekStart AND @ThroughDate FOR JSON PATH), '[]') AS attendances;
'@
        [void]$backupCmd.Parameters.Add('@WeekStart', [System.Data.SqlDbType]::Date)
        $backupCmd.Parameters['@WeekStart'].Value = $WeekStart.Date
        [void]$backupCmd.Parameters.Add('@ThroughDate', [System.Data.SqlDbType]::Date)
        $backupCmd.Parameters['@ThroughDate'].Value = $ThroughDate.Date
        $backupReader = $backupCmd.ExecuteReader()
        try {
            [void]$backupReader.Read()
            $snapshot = [ordered]@{
                schedules = @(foreach ($item in (ConvertFrom-Json -InputObject $backupReader.GetString(0))) { $item })
                attendances = @(foreach ($item in (ConvertFrom-Json -InputObject $backupReader.GetString(1))) { $item })
            }
            $snapshot | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $outputDir "$stamp-before.json") -Encoding UTF8
        } finally { $backupReader.Close() }
    }
    $dbCmd = $dbConn.CreateCommand()
    $dbCmd.CommandTimeout = 60
    $dbCmd.CommandText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'seed-demo-week-attendance.sql') -Raw -Encoding UTF8
    [void]$dbCmd.Parameters.Add('@WeekStart', [System.Data.SqlDbType]::Date)
    $dbCmd.Parameters['@WeekStart'].Value = $WeekStart.Date
    [void]$dbCmd.Parameters.Add('@ThroughDate', [System.Data.SqlDbType]::Date)
    $dbCmd.Parameters['@ThroughDate'].Value = $ThroughDate.Date
    [void]$dbCmd.Parameters.Add('@Apply', [System.Data.SqlDbType]::Bit)
    $dbCmd.Parameters['@Apply'].Value = [bool]$Apply
    $dbAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($dbCmd)
    $dbSet = New-Object System.Data.DataSet
    [void]$dbAdapter.Fill($dbSet)
    $result = @(
        foreach ($dbTable in $dbSet.Tables) {
            $rows = @(foreach ($dbRow in $dbTable.Rows) {
                $row = [ordered]@{}
                foreach ($column in $dbTable.Columns) {
                    $row[$column.ColumnName] = if ($dbRow.IsNull($column)) { $null } else { $dbRow[$column.ColumnName] }
                }
                [pscustomobject]$row
            })
            ,$rows
        }
    )
    $report = [ordered]@{
        summary = @(foreach ($item in $result[0]) { $item })
        distribution = @(foreach ($item in $result[1]) { $item })
        skipped = @(foreach ($item in $result[2]) { $item })
        counts = @(foreach ($item in $result[3]) { $item })
        created = @(foreach ($item in $result[4]) { $item })
    }
    ConvertTo-Json -InputObject $report -Depth 12 | Set-Content -LiteralPath (Join-Path $outputDir "$stamp-$mode.json") -Encoding UTF8
    $result[0] | Format-Table -AutoSize
    $result[1] | Format-Table -AutoSize
    if ($result[2].Count -gt 0) { $result[2] | Format-Table -AutoSize }
    $result[3] | Format-Table -AutoSize
    Write-Output "Saved report: target/data-seed/$stamp-$mode.json"
} finally { $dbConn.Close() }
