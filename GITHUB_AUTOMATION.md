# GitHub Automation & CI/CD

This project includes comprehensive GitHub Actions automation to ensure everything works correctly and stays secure.

## What Gets Tested Automatically

Every time you push code or create a pull request, GitHub Actions will:

### ✅ Validate Docker Compose Setup
- Checks `docker-compose.yml` syntax is valid
- Builds the backup service image
- Pulls all Docker images
- Verifies all 7 services are defined correctly
- Tests with dummy credentials (no real secrets needed)

### ✅ Validate Shell Scripts
- Runs `shellcheck` on all `.sh` files
- Checks for common shell script errors
- Verifies scripts are executable
- Ensures scripts follow best practices

### ✅ Validate Python Code
- Checks Python syntax in backup script
- Runs `pylint` for code quality
- Tests all imports work correctly
- Validates encryption/decryption logic

### ✅ Validate Documentation
- Checks all required documentation files exist
- Validates markdown syntax
- Checks for broken links (coming soon)
- Ensures documentation is complete

### ✅ Security Scanning
- Scans for accidentally committed secrets
- Checks `.env` is NOT in repository
- Checks `google-credentials.json` is NOT in repository
- Validates `.gitignore` is comprehensive
- Scans dependencies for vulnerabilities
- Scans Docker images for security issues

### ✅ Integration Testing
- Starts database container with test credentials
- Tests database connectivity
- Verifies basic functionality
- Tests encryption/decryption works

## Workflows

### 1. CI - Validate Setup (`.github/workflows/ci.yml`)

**Runs on:**
- Every push to `main` or `develop` branches
- Every pull request to `main`
- Weekly (Sundays at midnight) to catch upstream issues

**Jobs:**
1. **validate-docker-compose**: Docker Compose syntax and image builds
2. **validate-scripts**: Shell script linting and permissions
3. **validate-python**: Python syntax and code quality
4. **validate-documentation**: Documentation completeness
5. **security-scan**: Secret scanning and security checks
6. **test-backup-script**: Backup script logic testing
7. **validate-systemd**: Systemd service file validation
8. **integration-test**: Database connectivity testing
9. **report-status**: Overall CI status report

**Duration:** ~5-10 minutes

### 2. Security Scanning (`.github/workflows/security.yml`)

**Runs on:**
- Every push to `main`
- Every pull request to `main`
- Daily at 2 AM UTC (scheduled)

**Jobs:**
1. **secret-scanning**: TruffleHog + manual pattern checks
2. **dockerfile-security**: Hadolint Dockerfile linting
3. **dependency-security**: Python dependency vulnerability scanning
4. **docker-image-security**: Trivy image scanning
5. **gitignore-validation**: .gitignore effectiveness testing

**Duration:** ~3-5 minutes

### 3. Dependabot (`.github/dependabot.yml`)

**Runs:** Weekly on Mondays at 3 AM

**Updates:**
- Docker base images in backup service
- Python dependencies (`requirements.txt`)
- GitHub Actions versions

**Benefits:**
- Automatic pull requests for updates
- Security patch notifications
- Keep dependencies current

## Badges

The README includes status badges showing:

```markdown
[![CI](https://github.com/etiennechabert/limesurvey-pi-stack/workflows/CI%20-%20Validate%20Setup/badge.svg)]
[![Security](https://github.com/etiennechabert/limesurvey-pi-stack/workflows/Security%20Scanning/badge.svg)]
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)]
```

**What they show:**
- 🟢 Green badge = All tests passing
- 🔴 Red badge = Tests failing
- ⚪ Gray badge = No runs yet or pending

## What Happens When Tests Fail

### If CI Fails:
1. Check the Actions tab on GitHub
2. Click on the failed workflow
3. Review the logs for the failing job
4. Fix the issue locally
5. Push the fix
6. CI automatically re-runs

### Common Failures & Fixes:

| Failure | Likely Cause | Fix |
|---------|--------------|-----|
| Docker Compose validation | Syntax error in `docker-compose.yml` | Run `docker compose config` locally |
| Shell script check | Shellcheck warning | Run `shellcheck scripts/*.sh` locally |
| Python validation | Import error or syntax issue | Run `python -m py_compile backup.py` |
| Security scan | Potential secret found | Review and remove, check `.gitignore` |
| Integration test | Database connection failed | Check environment variable syntax |

## Running Tests Locally

### Test Docker Compose:
```bash
docker compose config
docker compose build
```

### Test Shell Scripts:
```bash
# Install shellcheck
sudo apt-get install shellcheck

# Check all scripts
find . -name "*.sh" -exec shellcheck {} \;
```

### Test Python:
```bash
cd backup-service
python -m py_compile backup.py
pip install pylint
pylint backup.py
```

### Test Security:
```bash
# Run pre-commit check
./scripts/pre-commit-check.sh

# Manual secret check
grep -r "password.*=.*['\"][^'\"]*[A-Za-z0-9!@#$%^&*]{20,}" . --exclude-dir=.git
```

### Test Encryption:
```bash
# Test encryption/decryption
echo "test" > test.txt
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
  -in test.txt -out test.enc -pass pass:testkey123
openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
  -in test.enc -out test.dec -pass pass:testkey123
diff test.txt test.dec && echo "✓ Encryption works"
rm test.*
```

## GitHub Actions Configuration

### Secrets Required: None! 🎉

All tests use:
- Dummy credentials for validation
- Test data (no real backups)
- Mock Google credentials
- Simulated services

**This means:**
- No secrets needed in GitHub
- Safe to run on public repositories
- Anyone can fork and CI works immediately

### Manual Workflow Dispatch

Some workflows can be triggered manually:

1. Go to "Actions" tab on GitHub
2. Select workflow (e.g., "Security Scanning")
3. Click "Run workflow"
4. Choose branch
5. Click "Run workflow" button

## What CI Can't Test (Requires Manual Testing)

While CI covers a lot, you still need to manually test:

- ❌ **Actual Google Drive uploads** (requires real credentials)
- ❌ **Cloudflare Tunnel connection** (requires real token)
- ❌ **Email notifications** (requires SMTP config)
- ❌ **Netdata alerts** (requires real monitoring)
- ❌ **Restore from real backup** (requires production data)
- ❌ **Performance on actual Raspberry Pi** (CI runs on Ubuntu)

**For these, follow the setup guides and test on your actual Pi!**

## Understanding Test Results

### All Green ✅
- All tests passed
- Safe to merge/deploy
- Changes didn't break anything

### Some Yellow ⚠️
- Some non-critical checks failed
- Review warnings
- Usually safe to continue

### Any Red ❌
- Critical test failed
- Do NOT merge/deploy
- Fix the issue first

## Continuous Improvement

The CI pipeline helps by:
1. **Catching errors early** - Before users encounter them
2. **Validating changes** - Every commit is tested
3. **Security monitoring** - Daily scans for vulnerabilities
4. **Dependency updates** - Automatic update PRs
5. **Documentation quality** - Ensures docs stay current

## Advanced: Adding More Tests

Want to add more tests? Edit `.github/workflows/ci.yml`:

```yaml
- name: Your new test
  run: |
    echo "Running your test..."
    # Your test commands here
```

Common additions:
- Performance benchmarks
- Load testing
- API endpoint testing
- Backup file integrity checks
- Restore process validation

## FAQ

### Q: Why do I need CI if I'm the only developer?

**A:** CI still helps you:
- Catch errors before deploying
- Validate changes work
- Track security issues
- Ensure documentation accuracy

### Q: Can I disable CI?

**A:** Yes, but not recommended. To disable:
1. Delete `.github/workflows/` directory
2. Or: Disable in repository Settings → Actions

### Q: Does CI cost money?

**A:** No! GitHub Actions is free for public repositories:
- 2,000 minutes/month for private repos
- Unlimited for public repos
- These workflows use ~10-20 minutes per run

### Q: How do I see test results?

**A:**
1. Go to your repository on GitHub
2. Click "Actions" tab
3. Click on any workflow run
4. Expand jobs to see details

### Q: What if CI fails on main branch?

**A:**
1. Don't panic! It happens
2. Check the failure logs
3. Fix locally and push
4. Or revert the breaking commit

### Q: Can others contribute and run CI?

**A:** Yes! When someone opens a pull request:
- CI automatically runs
- You see test results before merging
- Helps maintain code quality

## Best Practices

### Before Committing:
```bash
# 1. Run pre-commit check
./scripts/pre-commit-check.sh

# 2. Test Docker Compose
docker compose config

# 3. Test scripts
shellcheck scripts/*.sh

# 4. Commit
git add .
git commit -m "Your message"
git push
```

### Before Merging PRs:
1. ✅ Wait for CI to finish
2. ✅ Review test results
3. ✅ Check security scan
4. ✅ Test locally if needed
5. ✅ Merge when all green

### Regular Maintenance:
- Weekly: Review Dependabot PRs
- Monthly: Check security scan results
- Quarterly: Update CI workflows if needed

## Resources

- **GitHub Actions Docs**: https://docs.github.com/actions
- **Docker Actions**: https://github.com/marketplace?type=actions&query=docker
- **Security Scanning**: https://github.com/marketplace?category=security
- **Shellcheck**: https://www.shellcheck.net/
- **Trivy Scanner**: https://github.com/aquasecurity/trivy

---

## Summary

Your repository now has:
- ✅ Automated testing on every commit
- ✅ Daily security scanning
- ✅ Weekly dependency updates
- ✅ Comprehensive validation
- ✅ Status badges for README
- ✅ No manual testing needed for basic validation

**Result:** Higher quality, more secure, and easier to maintain! 🚀
