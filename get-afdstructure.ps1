param(
    [Parameter(Mandatory = $true)]
    [string]$JsonFile
)

# ==================== Limits (from Microsoft Learn) ====================
$Limits = @{
    Std   = @{
        CustomDomains     = 100
        OriginGroups      = 100
        OriginsPerProfile = 100
        Routes            = 100
        RuleSets          = 100
    }
    Prem  = @{
        CustomDomains     = 500
        OriginGroups      = 200
        OriginsPerProfile = 200
        Routes            = 200
        RuleSets          = 200
    }
    Common = @{
        OriginsPerGroup   = 50     # per origin group (Std & Prem)
        RulesPerRuleSet   = 100    # per rule set (Std & Prem)
    }
}

# ==================== Helper: aligned key:value printer for stats blocks ==========
function Write-AlignedStats {
    param(
        [Parameter(Mandatory=$true)][object[]]$Rows,
        [int]$MinWidth = 10,
        [string]$Sep = " : "
    )
    if (-not $Rows -or $Rows.Count -eq 0) { return }
    $labelWidth = [Math]::Max($MinWidth, (($Rows | ForEach-Object { ($_.Label | Out-String).Trim().Length } | Measure-Object -Maximum).Maximum))
    foreach ($r in $Rows) {
        $label = ($r.Label | Out-String).Trim()
        $value = $r.Value
        Write-Host ($label.PadRight($labelWidth) + $Sep + $value)
    }
}

# ==================== Load JSON ====================
if (-not (Test-Path -LiteralPath $JsonFile)) {
    Write-Error "File not found: $JsonFile"
    exit 1
}
$jsonContent = Get-Content -Path $JsonFile -Raw | ConvertFrom-Json

# ==================== Parse Classic Front Door Structure (Direct Access) ====================
# Access the known JSON structure directly - much simpler than recursive traversal
$frontendEndpoints = @()
$backendPools = @()
$routingRules = @()
$rulesEngines = @()

if ($jsonContent.properties) {
    if ($jsonContent.properties.frontendEndpoints) { $frontendEndpoints = @($jsonContent.properties.frontendEndpoints) }
    if ($jsonContent.properties.backendPools) { $backendPools = @($jsonContent.properties.backendPools) }
    if ($jsonContent.properties.routingRules) { $routingRules = @($jsonContent.properties.routingRules) }
    if ($jsonContent.properties.rulesEngines) { $rulesEngines = @($jsonContent.properties.rulesEngines) }
}

# Get counts
[int]$frontendEndpointCount = $frontendEndpoints.Count
[int]$backendPoolCount = $backendPools.Count
[int]$routingRuleCount = $routingRules.Count
[int]$rulesEngineCount = $rulesEngines.Count

# ==================== Enumerate backend pools and backends ====================
[int]$totalBackends = 0
[int]$maxBackendsInPool = 0
[string]$maxPoolName = ""
$poolLimitViolations = @()

if ($backendPools.Count -gt 0) {
    Write-Host "`n=== Backend Pools and Backends ===`n"

    $maxPoolNameLength = ($backendPools | ForEach-Object { $_.name.Length } | Measure-Object -Maximum).Maximum
    if (-not $maxPoolNameLength) { $maxPoolNameLength = 10 }
    $formatPool = "Pool: {0,-" + $maxPoolNameLength + "}    Backends: {1}"

    foreach ($pool in $backendPools) {
        $poolName = $pool.name
        $backends = @()
        
        # Get backends from properties or direct
        if ($pool.properties -and $pool.properties.backends) {
            $backends = @($pool.properties.backends)
        } elseif ($pool.backends) {
            $backends = @($pool.backends)
        }

        [int]$backendCount = $backends.Count
        $totalBackends += $backendCount

        # Track max and violations
        if ($backendCount -gt $maxBackendsInPool) {
            $maxBackendsInPool = $backendCount
            $maxPoolName = $poolName
        }
        if ($backendCount -gt $Limits.Common.OriginsPerGroup) {
            $poolLimitViolations += [PSCustomObject]@{
                PoolName = $poolName
                Count = $backendCount
                Limit = $Limits.Common.OriginsPerGroup
            }
        }

        Write-Host ($formatPool -f $poolName, $backendCount)

        foreach ($b in $backends) {
            $addr = if ($b.address) { $b.address } else { "(no address field)" }
            Write-Host ("    - {0}" -f $addr)
        }
        Write-Host ""
    }
}

# ==================== List Custom Domains (FrontendEndpoints) ====================
if ($frontendEndpoints.Count -gt 0) {
    Write-Host "=== Custom Domains (FrontendEndpoints) ===`n"

    $maxNameLength = ($frontendEndpoints | ForEach-Object { $_.name.Length } | Measure-Object -Maximum).Maximum
    if (-not $maxNameLength) { $maxNameLength = 10 }
    $formatFE = "Name: {0,-" + $maxNameLength + "}    Hostname: {1}"

    foreach ($fe in $frontendEndpoints) {
        $feName = $fe.name
        $hostName = $null
        
        if ($fe.properties -and $fe.properties.hostName) {
            $hostName = $fe.properties.hostName
        } elseif ($fe.hostName) {
            $hostName = $fe.hostName
        }
        
        if (-not $hostName) { $hostName = "(no hostName field)" }

        Write-Host ($formatFE -f $feName, $hostName)
    }
    Write-Host ""
}

# ==================== Rule Engines: rules cap check ====================
[int]$maxRulesInEngine = 0
[string]$maxRulesEngineName = ""
$ruleSetLimitViolations = @()

foreach ($re in $rulesEngines) {
    $reName = $re.name
    $rules = @()
    
    if ($re.properties -and $re.properties.rules) {
        $rules = @($re.properties.rules)
    } elseif ($re.rules) {
        $rules = @($re.rules)
    }

    [int]$ruleCount = $rules.Count

    if ($ruleCount -gt $maxRulesInEngine) {
        $maxRulesInEngine = $ruleCount
        $maxRulesEngineName = $reName
    }
    
    if ($ruleCount -gt $Limits.Common.RulesPerRuleSet) {
        $ruleSetLimitViolations += [PSCustomObject]@{
            RuleEngineName = $reName
            Count = $ruleCount
            Limit = $Limits.Common.RulesPerRuleSet
        }
    }
}

# ==================== Classic Totals ====================
Write-Host "===================================="
Write-Host "Classic Front Door - Resource Summary"
Write-Host "===================================="

$classicRows = @(
    [pscustomobject]@{ Label = 'Total FrontendEndpoints'; Value = $frontendEndpointCount }
    [pscustomobject]@{ Label = 'Total Backend Pools';     Value = $backendPoolCount }
    [pscustomobject]@{ Label = 'Total Backends';          Value = $totalBackends }
    [pscustomobject]@{ Label = 'Total RoutingRules';      Value = $routingRuleCount }
    [pscustomobject]@{ Label = 'Total RulesEngines';      Value = $rulesEngineCount }
)
Write-AlignedStats -Rows $classicRows -MinWidth 24

Write-Host ""
Write-Host ("Max Backends in a Single Pool : {0}    (Pool: {1})" -f $maxBackendsInPool, $maxPoolName)
if ($rulesEngines.Count -gt 0) {
    Write-Host ("Max Rules in a Single RuleEngine : {0}    (RuleEngine: {1})" -f $maxRulesInEngine, $maxRulesEngineName)
}

# ==================== Equivalent Premium/Standard Totals ====================
Write-Host ""
Write-Host "===================================="
Write-Host "Premium/Standard Front Door - Equivalent Resources"
Write-Host "===================================="

[int]$customDomains = $frontendEndpointCount   # FrontendEndpoint -> Custom Domain
[int]$originGroups  = $backendPoolCount        # BackendPool -> Origin Group
[int]$originsTotal  = $totalBackends           # Backend -> Origin
[int]$routesTotal   = $routingRuleCount        # RoutingRules -> Routes
[int]$ruleSetsTotal = $rulesEngineCount        # RulesEngines -> Rule Sets

$equivRows = @(
    [pscustomobject]@{ Label = 'Custom Domains (from FrontendEndpoints)'; Value = $customDomains }
    [pscustomobject]@{ Label = 'Origin Groups (from Backend Pools)';      Value = $originGroups }
    [pscustomobject]@{ Label = 'Origins (from Backends)';                 Value = $originsTotal }
    [pscustomobject]@{ Label = 'Routes (from RoutingRules)';              Value = $routesTotal }
    [pscustomobject]@{ Label = 'Rule Sets (from RulesEngines)';           Value = $ruleSetsTotal }
)
Write-AlignedStats -Rows $equivRows -MinWidth 44

# ==================== Limit Warnings Section ====================
Write-Host ""
Write-Host "===================================="
Write-Host "Migration Limit Analysis"
Write-Host "===================================="

$hasWarnings = $false

# Check Standard Tier Limits
$stdWarnings = @()
if ($customDomains -gt $Limits.Std.CustomDomains) {
    $stdWarnings += "  ❌ Custom Domains: $customDomains exceeds limit of $($Limits.Std.CustomDomains)"
    $hasWarnings = $true
}
if ($originGroups -gt $Limits.Std.OriginGroups) {
    $stdWarnings += "  ❌ Origin Groups: $originGroups exceeds limit of $($Limits.Std.OriginGroups)"
    $hasWarnings = $true
}
if ($originsTotal -gt $Limits.Std.OriginsPerProfile) {
    $stdWarnings += "  ❌ Origins: $originsTotal exceeds limit of $($Limits.Std.OriginsPerProfile)"
    $hasWarnings = $true
}
if ($routesTotal -gt $Limits.Std.Routes) {
    $stdWarnings += "  ❌ Routes: $routesTotal exceeds limit of $($Limits.Std.Routes)"
    $hasWarnings = $true
}
if ($ruleSetsTotal -gt $Limits.Std.RuleSets) {
    $stdWarnings += "  ❌ Rule Sets: $ruleSetsTotal exceeds limit of $($Limits.Std.RuleSets)"
    $hasWarnings = $true
}

# Check Premium Tier Limits
$premWarnings = @()
if ($customDomains -gt $Limits.Prem.CustomDomains) {
    $premWarnings += "  ❌ Custom Domains: $customDomains exceeds limit of $($Limits.Prem.CustomDomains)"
    $hasWarnings = $true
}
if ($originGroups -gt $Limits.Prem.OriginGroups) {
    $premWarnings += "  ❌ Origin Groups: $originGroups exceeds limit of $($Limits.Prem.OriginGroups)"
    $hasWarnings = $true
}
if ($originsTotal -gt $Limits.Prem.OriginsPerProfile) {
    $premWarnings += "  ❌ Origins: $originsTotal exceeds limit of $($Limits.Prem.OriginsPerProfile)"
    $hasWarnings = $true
}
if ($routesTotal -gt $Limits.Prem.Routes) {
    $premWarnings += "  ❌ Routes: $routesTotal exceeds limit of $($Limits.Prem.Routes)"
    $hasWarnings = $true
}
if ($ruleSetsTotal -gt $Limits.Prem.RuleSets) {
    $premWarnings += "  ❌ Rule Sets: $ruleSetsTotal exceeds limit of $($Limits.Prem.RuleSets)"
    $hasWarnings = $true
}

# Display Standard Tier Warnings
Write-Host "`nStandard Tier:"
Write-Host "--------------"
if ($stdWarnings.Count -gt 0) {
    foreach ($w in $stdWarnings) {
        Write-Host $w -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✅ All resources within Standard tier limits" -ForegroundColor Green
}

# Display Premium Tier Warnings
Write-Host "`nPremium Tier:"
Write-Host "-------------"
if ($premWarnings.Count -gt 0) {
    foreach ($w in $premWarnings) {
        Write-Host $w -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✅ All resources within Premium tier limits" -ForegroundColor Green
}

# Per-Pool Warnings (both tiers have same limit)
if ($poolLimitViolations.Count -gt 0) {
    Write-Host "`nPer-Pool Limit Violations (affects both Standard & Premium):"
    Write-Host "-------------------------------------------------------------"
    $hasWarnings = $true
    foreach ($violation in $poolLimitViolations) {
        Write-Host ("  ❌ Pool '{0}': {1} origins exceeds limit of {2}" -f $violation.PoolName, $violation.Count, $violation.Limit) -ForegroundColor Red
    }
    Write-Host "  ACTION REQUIRED: Split these pools into multiple origin groups before migration" -ForegroundColor Red
}

# Per-RuleSet Warnings (both tiers have same limit)
if ($ruleSetLimitViolations.Count -gt 0) {
    Write-Host "`nPer-RuleSet Limit Violations (affects both Standard & Premium):"
    Write-Host "----------------------------------------------------------------"
    $hasWarnings = $true
    foreach ($violation in $ruleSetLimitViolations) {
        Write-Host ("  ❌ RuleEngine '{0}': {1} rules exceeds limit of {2}" -f $violation.RuleEngineName, $violation.Count, $violation.Limit) -ForegroundColor Red
    }
    Write-Host "  ACTION REQUIRED: Split these rule engines into multiple rule sets before migration" -ForegroundColor Red
}

# Summary
Write-Host ""
if (-not $hasWarnings) {
    Write-Host "===================================="
    Write-Host "✅ No migration blockers detected!" -ForegroundColor Green
    Write-Host "This Classic Front Door can be migrated to both Standard and Premium tiers." -ForegroundColor Green
    Write-Host "===================================="
} else {
    Write-Host "===================================="
    Write-Host "⚠️  Migration Issues Detected" -ForegroundColor Yellow
    Write-Host "Review the warnings above before proceeding with migration." -ForegroundColor Yellow
    Write-Host "===================================="
}
Write-Host ""
