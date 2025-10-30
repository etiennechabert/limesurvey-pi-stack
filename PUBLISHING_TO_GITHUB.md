# Publishing to GitHub - Checklist

## Before You Commit - Security Check ⚠️

### Critical: Never Commit These Files!

Run this check before your first commit:

```bash
# Check for sensitive files
ls -la .env
ls -la google-credentials.json
ls -la backups/*.sql*

# These should return "No such file" or be listed in .gitignore
```

**Files that should NEVER be committed:**
- ❌ `.env` (contains passwords and secrets)
- ❌ `google-credentials.json` (Google service account key)
- ❌ Any backup files (`.sql`, `.sql.gz`, `.sql.gz.enc`)
- ❌ Any `.key` or `.pem` files

**If you accidentally committed secrets:**
1. **Immediately** rotate all passwords and API keys
2. Delete Google service account and create new one
3. Use `git filter-branch` or BFG Repo-Cleaner to remove from history
4. Force push to GitHub

### Verify .gitignore is Working

```bash
# This should show NO sensitive files
git status

# Should NOT see:
# - .env
# - google-credentials.json
# - backups/*.sql*
```

## Pre-Publish Checklist

- [ ] `.env` is NOT tracked (only `.env.example`)
- [ ] `google-credentials.json` is NOT tracked
- [ ] No backup files (`.sql`, `.sql.gz`, `.sql.gz.enc`) are tracked
- [ ] License file exists (`LICENSE`)
- [ ] README is complete and accurate
- [ ] `.gitignore` is comprehensive
- [ ] All scripts have placeholders, not real credentials

## Publishing Steps

### Step 1: Create Repository on GitHub

✅ **Already done!** Your repository: https://github.com/etiennechabert/limesurvey-pi-stack

If you haven't created it yet:
1. Go to https://github.com/new
2. Fill in:
   - **Repository name**: `limesurvey-pi-stack` ✅
   - **Description**: "Complete Docker setup for LimeSurvey on Raspberry Pi with auto-backups to Google Drive, encryption, and monitoring"
   - **Visibility**: Public ✅
   - **DO NOT** initialize with README (you already have one)
   - **DO NOT** add .gitignore (you already have one)
   - **DO NOT** add license (you already have one)

3. Click "Create repository"

### Step 2: Initialize Git (if not already done)

```bash
cd ~/limesurvey-lykebo

# Initialize git if needed
git init

# Check current status
git status
```

### Step 3: Verify Nothing Sensitive Will Be Committed

```bash
# See what will be added
git status

# If you see .env or google-credentials.json, STOP!
# They should be in .gitignore
```

### Step 4: Make Initial Commit

```bash
# Add all files (gitignore will exclude sensitive ones)
git add .

# Verify what's staged (double check!)
git status

# Should see:
# ✅ docker-compose.yml
# ✅ .env.example
# ✅ README.md
# ✅ All .md documentation files
# ✅ scripts/
# ✅ backup-service/
# ✅ .gitignore
# ✅ LICENSE

# Should NOT see:
# ❌ .env
# ❌ google-credentials.json
# ❌ backups/*.sql*

# Create initial commit
git commit -m "Initial commit: LimeSurvey on Raspberry Pi with auto-backups

Features:
- Docker Compose setup for LimeSurvey + MariaDB
- Hourly encrypted backups to Google Drive
- Intelligent backup rotation (grandfather-father-son)
- Optional restore-on-boot (stateless Pi mode)
- Cloudflare Tunnel for secure access
- Netdata monitoring
- Watchtower auto-updates
- Health checks and watchdog
- Comprehensive documentation"
```

### Step 5: Add Remote and Push

```bash
# Add GitHub remote
git remote add origin https://github.com/etiennechabert/limesurvey-pi-stack.git

# Or if using SSH:
# git remote add origin git@github.com:etiennechabert/limesurvey-pi-stack.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 6: Verify on GitHub

1. Go to your repository URL: `https://github.com/etiennechabert/limesurvey-pi-stack`
2. Check that README displays correctly
3. Verify LICENSE file is recognized by GitHub
4. **IMPORTANT**: Check that `.env` and `google-credentials.json` are NOT visible

### Step 7: Add Topics (Optional but Recommended)

On your GitHub repository page:
1. Click "⚙️ Settings" (top right of code section)
2. In "Topics", add:
   - `limesurvey`
   - `raspberry-pi`
   - `docker-compose`
   - `backup`
   - `google-drive`
   - `cloudflare`
   - `monitoring`
   - `self-hosted`
   - `encryption`

This helps others discover your project!

## Recommended: Add GitHub Features

### Add Repository Description

In repository settings, add:
> Complete LimeSurvey deployment for Raspberry Pi with automated encrypted backups to Google Drive, monitoring, and auto-updates. Includes optional stateless mode for disaster recovery validation.

### Enable GitHub Features

- ✅ Issues (for bug reports and feature requests)
- ✅ Discussions (for questions and community)
- ❌ Wiki (README is comprehensive enough)
- ❌ Projects (probably not needed)

### Add Repository Website

In repository settings, add your documentation link or leave blank.

### Create Releases (Optional)

Consider tagging releases when you make major updates:

```bash
# Tag a release
git tag -a v1.0.0 -m "Initial stable release"
git push origin v1.0.0
```

Then create a release on GitHub with release notes.

## Maintaining the Repository

### Making Updates

```bash
# Make changes to files
nano README.md

# Check what changed
git status
git diff

# Commit changes
git add .
git commit -m "Update: improved backup documentation"

# Push to GitHub
git push
```

### Accepting Contributions

If others contribute:
1. Review pull requests carefully
2. Test changes before merging
3. Thank contributors!

### Keeping Secrets Safe - Ongoing

**Every time before you commit:**

```bash
# Always check what you're committing
git status
git diff

# NEVER commit:
# - .env
# - google-credentials.json
# - Any file with real passwords/keys
```

## Promoting Your Project

### Share On

- Reddit: r/selfhosted, r/raspberry_pi
- LimeSurvey Forums: https://forums.limesurvey.org/
- Hacker News (if it gains traction)
- Your blog/social media

### Example Post

> 🚀 I created a complete Docker setup for running LimeSurvey on Raspberry Pi!
>
> Features:
> ✅ Automated encrypted backups to Google Drive
> ✅ Optional "stateless Pi" mode - validates backups on every boot
> ✅ Cloudflare Tunnel for secure access (no port forwarding)
> ✅ Netdata monitoring + auto-updates
> ✅ Comprehensive documentation
>
> Perfect for surveys, research, customer feedback!
>
> GitHub: [your-link]

## Security Best Practices

### What to Include in README

✅ Generic examples
✅ Placeholder values
✅ Setup instructions
✅ Architecture diagrams

### What NOT to Include

❌ Real passwords
❌ Real API keys
❌ Real Google credentials
❌ Real domain names (use example.com)
❌ Real email addresses (use your real one only in LICENSE copyright)

## Example: Good vs Bad

### ❌ BAD (Don't do this!)

```yaml
MYSQL_ROOT_PASSWORD=MySecretPass123!
GOOGLE_DRIVE_FOLDER_ID=1a2b3c4d5e6f7g8h9i
CLOUDFLARE_TUNNEL_TOKEN=eyJhbGciOiJIUzI1...
```

### ✅ GOOD (Do this!)

```yaml
MYSQL_ROOT_PASSWORD=your_secure_root_password_here
GOOGLE_DRIVE_FOLDER_ID=your_google_drive_folder_id_here
CLOUDFLARE_TUNNEL_TOKEN=your_cloudflare_tunnel_token_here
```

## Final Security Check

Before publishing, run:

```bash
# Search for common secret patterns
grep -r "password=" . --exclude-dir=.git
grep -r "token=" . --exclude-dir=.git
grep -r "key=" . --exclude-dir=.git

# Should only find examples in .env.example and documentation
# NOT in actual .env or scripts
```

## After Publishing

### Monitor Your Repository

1. **Watch for issues** - respond to user questions
2. **Security alerts** - GitHub will notify you of vulnerable dependencies
3. **Pull requests** - review and merge community improvements
4. **Stars** - see how popular it becomes!

### Update Regularly

When you make improvements to your local setup:
1. Test thoroughly
2. Update documentation
3. Commit and push to GitHub

### Consider Adding

- GitHub Actions for automated testing (advanced)
- Docker Hub automated builds (advanced)
- Changelog file (CHANGELOG.md)
- Contributing guidelines (CONTRIBUTING.md)

## Quick Reference Commands

```bash
# Check what will be committed
git status

# Add all changes
git add .

# Commit with message
git commit -m "Your message here"

# Push to GitHub
git push

# Pull latest changes
git pull

# View commit history
git log --oneline

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes) - DANGEROUS!
git reset --hard HEAD~1
```

## Need Help?

- Git basics: https://git-scm.com/doc
- GitHub guides: https://guides.github.com/
- Removing sensitive data: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository

---

## Summary: Pre-Publish Checklist

Run these commands before your first push:

```bash
# 1. Verify gitignore is working
git status | grep -E '\.env$|google-credentials\.json|\.sql'
# Should return NOTHING

# 2. Check what will be committed
git status

# 3. If all looks good, commit and push
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_USERNAME/REPO_NAME.git
git push -u origin main
```

**If you see ANY sensitive files in `git status`, STOP and fix .gitignore first!**

Good luck! 🚀
