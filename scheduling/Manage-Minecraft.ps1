# ==========================================
# Minecraft Club - Automatic Server Manager
# ==========================================

$ErrorActionPreference = "Stop"

$BasePath = "C:\Users\Student\Documents\GitHub\docker-minecraft-server"
# $BasePath = "."
$ComposeFile = Join-Path $BasePath "docker-compose.yml"
$ConfigFile = Join-Path $BasePath "scheduling\schedule.json"
$LogDirectory = Join-Path $BasePath "logs"
$LogFile = Join-Path $LogDirectory "minecraft-scheduler.log"

# Create log directory
New-Item -ItemType Directory -Force -Path $LogDirectory |
    Out-Null

function Write-Log {
    param([string]$Message)

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Timestamp] $Message"
}

try {
    # --------------------------------------
    # Load configuration
    # --------------------------------------

    $Config = Get-Content $ConfigFile -Raw |
        ConvertFrom-Json

    $TimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById(
        $Config.timezone
    )

    $Now = [System.TimeZoneInfo]::ConvertTime(
        [DateTimeOffset]::Now,
        $TimeZone
    ).DateTime

    $ShouldRun = $false

    # --------------------------------------
    # Evaluate today's and yesterday's
    # schedules. Checking yesterday allows
    # overnight sessions to work correctly.
    # --------------------------------------

    foreach ($Offset in @(0, -1)) {

        $ScheduleDate = $Now.Date.AddDays($Offset)
        $DayName = $ScheduleDate.DayOfWeek.ToString()

        $DayConfig = $Config.days.$DayName

        if ($null -eq $DayConfig) {
            continue
        }

        if (-not $DayConfig.enabled) {
            continue
        }

        foreach ($Window in $DayConfig.schedule) {

            $Start = [TimeSpan]::ParseExact(
                $Window.start,
                "hh\:mm",
                [Globalization.CultureInfo]::InvariantCulture
            )

            $Stop = [TimeSpan]::ParseExact(
                $Window.stop,
                "hh\:mm",
                [Globalization.CultureInfo]::InvariantCulture
            )

            if ($Start -eq $Stop) {
                throw "Start and stop times cannot be identical on $DayName."
            }

            $WindowStart = $ScheduleDate.Add($Start)
            $WindowStop = $ScheduleDate.Add($Stop)

            # Handle sessions crossing midnight
            if ($Stop -lt $Start) {
                $WindowStop = $WindowStop.AddDays(1)
            }

            if ($Now -ge $WindowStart -and
                $Now -lt $WindowStop) {

                $ShouldRun = $true
                break
            }
        }

        if ($ShouldRun) {
            break
        }
    }

    # --------------------------------------
    # Check Docker availability
    # --------------------------------------

    $null = & docker info --format '{{.ServerVersion}}' 2>$null

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Docker unavailable. Retrying next minute."
        exit 1
    }

    # --------------------------------------
    # Determine Minecraft container status
    # --------------------------------------

    $RunningServices = @(
        & docker compose -f $ComposeFile ps `
            --status running --services 2>$null
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to query Docker Compose status."
    }

    $IsRunning = $RunningServices -contains "mc"

    # --------------------------------------
    # Start or stop Minecraft
    # --------------------------------------

    if ($ShouldRun -and -not $IsRunning) {

        Write-Log "Starting Minecraft server..."

        & docker compose -f $ComposeFile start mc

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to start Minecraft."
        }

        Write-Log "Minecraft server started."
    }
    elseif (-not $ShouldRun -and $IsRunning) {

        Write-Log "Stopping Minecraft server gracefully..."

        & docker compose -f $ComposeFile stop -t 120 mc

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to stop Minecraft."
        }

        Write-Log "Minecraft server stopped."
    }

}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
