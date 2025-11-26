#!/bin/bash
# Deployment Script for Audio-X Backend

echo "🚀 Audio-X Backend Deployment"
echo "=============================="
echo ""

# Step 1: Create .env file
echo "📝 Step 1: Creating .env file from template..."
cd backend
if [ ! -f .env ]; then
    cp .env.example .env
    echo "✅ .env file created!"
    echo "⚠️  IMPORTANT: Edit .env and add your Spotify credentials!"
    echo ""
else
    echo "✅ .env file already exists"
    echo ""
fi

# Step 2: Git setup
echo "📦 Step 2: Setting up Git repository..."
if [ ! -d .git ]; then
    git init
    echo "✅ Git initialized"
else
    echo "✅ Git already initialized"
fi

# Step 3: Commit files
echo "💾 Step 3: Committing files..."
git add .
git commit -m "Deploy: Spotify backend to Render" || echo "No changes to commit"

echo ""
echo "📋 Next Steps:"
echo "=============="
echo "1. Create GitHub repository: https://github.com/new"
echo "   Name: audio-x-backend"
echo ""
echo "2. Connect with:"
echo "   git remote add origin https://github.com/YOUR_USERNAME/audio-x-backend.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. In Render Dashboard (https://dashboard.render.com/):"
echo "   - Connect your GitHub repository"
echo "   - Add environment variables:"
echo "     SPOTIFY_CLIENT_ID"
echo "     SPOTIFY_CLIENT_SECRET"
echo ""
echo "4. Your backend URL: https://audio-x.onrender.com"
echo ""
echo "✨ Done! Check DEPLOYMENT_GUIDE.md for detailed steps"
