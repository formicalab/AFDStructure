# Tests Folder

This folder contains JSON exports of Azure Front Door resources for testing the analysis script.

## Purpose

The `Tests/` folder is **excluded from Git tracking** via `.gitignore` to prevent sensitive production data from being committed to the repository.

## Usage

1. **Export your Azure Front Door to JSON:**

   ```powershell
   # Using Azure CLI
   az network front-door show --name <your-frontdoor-name> --resource-group <your-rg> > Tests/my-frontdoor.json
   
   # Using Azure PowerShell
   Get-AzFrontDoor -Name <your-frontdoor-name> -ResourceGroupName <your-rg> | ConvertTo-Json -Depth 10 | Out-File Tests/my-frontdoor.json
   ```

2. **Run the analysis:**

   ```powershell
   .\get-afdstructure.ps1 -JsonFile ".\Tests\my-frontdoor.json"
   ```

## Sample Files

If you're contributing or testing, you can place sample (non-production) JSON files here:

- Use anonymized/sanitized data
- Remove any sensitive information (IPs, domain names, etc.)
- Name files descriptively (e.g., `sample-small.json`, `sample-with-violations.json`)

## Note

⚠️ **Never commit production JSON files with real data to Git!**

All `.json` and `.txt` files in this folder are automatically ignored by Git.
