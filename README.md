# Azure Front Door Structure Analysis

A PowerShell script to analyze Classic Azure Front Door (AFD) resources and assess migration readiness to Standard or Premium tiers.

## Overview

This script parses JSON exports of Classic Azure Front Door resources and provides:
- Detailed inventory of backend pools, backends, custom domains, and routing rules
- Mapping to equivalent Premium/Standard Front Door constructs
- **Complete limit analysis** for both Standard and Premium tiers
- Clear warnings about migration blockers
- Actionable recommendations for resources exceeding limits

## Features

✅ **Complete Limit Checking**
- All Standard tier limits (Custom Domains, Origin Groups, Origins, Routes, Rule Sets)
- All Premium tier limits
- Per-pool origin limits (50 origins per group)
- Per-ruleset limits (100 rules per set)

✅ **Clear Output**
- Color-coded warnings (Green = OK, Yellow = Warning, Red = Critical)
- Migration verdict with specific action items
- Detailed resource breakdown

✅ **Simple & Maintainable**
- Direct JSON property access (no complex recursion)
- Clean, linear logic flow
- Easy to extend for additional checks

## Requirements

- PowerShell 5.1 or later
- Azure Front Door resource exported to JSON

## Usage

### 1. Export Your Classic Front Door to JSON

Using Azure CLI:
```powershell
az network front-door show --name <your-frontdoor-name> --resource-group <your-rg> > frontdoor-export.json
```

Using Azure PowerShell:
```powershell
Get-AzFrontDoor -Name <your-frontdoor-name> -ResourceGroupName <your-rg> | ConvertTo-Json -Depth 10 | Out-File frontdoor-export.json
```

### 2. Run the Analysis Script

```powershell
.\get-afdstructure.ps1 -JsonFile ".\frontdoor-export.json"
```

## Example Output

```
=== Backend Pools and Backends ===

Pool: production-pool-01          Backends: 10
    - 10.0.1.10
    - 10.0.1.11
    ...

=== Custom Domains (FrontendEndpoints) ===

Name: www-example-com             Hostname: www.example.com
Name: api-example-com             Hostname: api.example.com

====================================
Classic Front Door - Resource Summary
====================================
Total FrontendEndpoints  : 40
Total Backend Pools      : 98
Total Backends           : 342
Total RoutingRules       : 54
Total RulesEngines       : 21

====================================
Premium/Standard Front Door - Equivalent Resources
====================================
Custom Domains (from FrontendEndpoints)      : 40
Origin Groups (from Backend Pools)           : 98
Origins (from Backends)                      : 342
Routes (from RoutingRules)                   : 54
Rule Sets (from RulesEngines)                : 21

====================================
Migration Limit Analysis
====================================

Standard Tier:
--------------
  ❌ Origins: 342 exceeds limit of 100

Premium Tier:
-------------
  ❌ Origins: 342 exceeds limit of 200

====================================
⚠️  Migration Issues Detected
Review the warnings above before proceeding with migration.
====================================
```

## Azure Front Door Limits

### Standard Tier
- Custom Domains: 100
- Origin Groups: 100
- Origins per Profile: 100
- Routes: 100
- Rule Sets: 100

### Premium Tier
- Custom Domains: 500
- Origin Groups: 200
- Origins per Profile: 200
- Routes: 200
- Rule Sets: 200

### Common (Both Tiers)
- Origins per Group: 50
- Rules per Rule Set: 100

## Resource Mapping

| Classic Front Door | Standard/Premium Front Door |
|-------------------|----------------------------|
| Frontend Endpoint | Custom Domain |
| Backend Pool | Origin Group |
| Backend | Origin |
| Routing Rule | Route |
| Rules Engine | Rule Set |

## Files

- `get-afdstructure.ps1` - Main analysis script
- `.gitignore` - Git configuration
- `Tests/` - Folder for test JSON files (not tracked by Git)

## Testing

Place your Front Door JSON exports in the `Tests/` folder:

```powershell
.\get-afdstructure.ps1 -JsonFile ".\Tests\your-frontdoor.json"
```

## Migration Guidance

### ✅ No Warnings
Your Classic Front Door can be migrated to both Standard and Premium tiers without changes.

### ⚠️ Tier Limit Violations
If resources exceed Standard limits but fit within Premium limits, migrate to Premium tier.

### 🔴 Per-Resource Violations
- **Pool with >50 origins**: Split into multiple origin groups before migration
- **Rule Engine with >100 rules**: Split into multiple rule sets before migration

### 🔴 Both Tiers Exceeded
Requires architecture redesign before migration. Consider:
- Consolidating duplicate origins
- Splitting into multiple Front Door profiles
- Reviewing if all resources are actively used

## Contributing

Improvements and bug reports are welcome! Please ensure:
- All limit checks remain functional
- Output remains clear and actionable
- Code stays simple and maintainable

## License

This script is provided as-is for Azure Front Door migration assessment purposes.

## References

- [Azure Front Door Service Limits](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-front-door-standard-and-premium-tier-service-limits)
- [Migrate from Classic to Standard/Premium](https://learn.microsoft.com/en-us/azure/frontdoor/tier-migration)
- [Classic vs Standard/Premium Comparison](https://learn.microsoft.com/en-us/azure/frontdoor/understanding-pricing)
