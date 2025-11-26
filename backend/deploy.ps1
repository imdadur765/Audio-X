# Audio-X Backend Deployment Script (Windows)
# Run this from the audio_x directory

Write-Host "🚀 Audio-X Backend Deployment" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create .env file
Write-Host "📝 Step 1: Creating .env file from template..." -ForegroundColor Yellow
Set-Location backend

if (-not (Test-Path .env)) {
    Copy-Item .env.example .env
    Write-Host "✅ .env file created!" -ForegroundColor Green
    Write-Host "⚠️  IMPORTANT: Edit .env and add your Spotify credentials!" -ForegroundColor Red
    Write-Host ""
} else {
    Write-Host "✅ .env file already exists" -ForegroundColor Green
    Write-Host ""
}

# Step 2: Git setup
Write-Host "📦 Step 2: Setting up Git repository..." -ForegroundColor Yellow
if (-not (Test-Path .git)) {
    git init
    Write-Host "✅ Git initialized" -ForegroundColor Green
} else {
    Write-Host "✅ Git already initialized" -ForegroundColor Green
}

# Step 3: Commit files
Write-Host "💾 Step 3: Committing files..." -ForegroundColor Yellow
git add .
git commit -m "Deploy: Spotify backend to Render"

Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host "==============" -ForegroundColor Cyan
Write-Host "1. Create GitHub repository: https://github.com/new"
Write-Host "   Name: audio-x-backend"
Write-Host ""
Write-Host "2. Connect with:"
Write-Host "   git remote add origin https://github.com/YOUR_USERNAME/audio-x-backend.git" -ForegroundColor Yellow
Write-Host "   git branch -M main" -ForegroundColor Yellow
Write-Host "   git push -u origin main" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. In Render Dashboard (https://dashboard.render.com/):"
Write-Host "   - Connect your GitHub repository"
Write-Host "   - Add environment variables:"
Write-Host "     SPOTIFY_CLIENT_ID" -ForegroundColor Yellow
Write-Host "     SPOTIFY_CLIENT_SECRET" -ForegroundColor Yellow
Write-Host ""
Write-Host "4. Your backend URL: https://audio-x.onrender.com" -ForegroundColor Green
Write-Host ""
Write-Host "✨ Done! Check DEPLOYMENT_GUIDE.md for detailed steps" -ForegroundColor Green
