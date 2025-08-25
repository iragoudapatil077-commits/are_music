param(
  [string]$orgOrUser = "iragoudapatil077-commits",
  [string]$repo = "are_music",
  [string]$visibility = "public"
)

Write-Host "This script will create a GitHub repo and push the current directory to it. Requires 'gh' (GitHub CLI) and 'git' installed and authenticated."

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Host "gh CLI not found. Install from https://cli.github.com/ and authenticate (gh auth login) then re-run." -ForegroundColor Red
  exit 1
}

$fullName = "$orgOrUser/$repo"

# Create repo
Write-Host "Creating repository $fullName ..."
gh repo create $fullName --$visibility --confirm

# Ensure git is initialized
if (-not (Test-Path .git)) {
  git init
  git add .
  git commit -m "Initial commit"
}

# Add remote and push
git remote remove origin -ErrorAction SilentlyContinue
git remote add origin https://github.com/$fullName.git
Write-Host "Pushing to origin main..."
git branch -M main
git push -u origin main

Write-Host "Repository created and pushed: https://github.com/$fullName"
Write-Host "You can now create a release by tagging and pushing: git tag v2.0.14; git push origin v2.0.14"
