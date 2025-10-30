# Contributing

## Table of Contents
- [GitHub Actions CI/CD](#github-actions-cicd)
  - [What Gets Tested](#what-gets-tested)
  - [View Test Results](#view-test-results)
  - [Running Tests Locally](#running-tests-locally)
- [Contributing Changes](#contributing-changes)
  - [Before Committing](#before-committing)
  - [Pull Requests](#pull-requests)
- [Code Style](#code-style)
  - [Shell Scripts](#shell-scripts)
  - [Python](#python)
  - [Documentation](#documentation)
- [Security](#security)
  - [Never Commit](#never-commit)
  - [If You Accidentally Commit Secrets](#if-you-accidentally-commit-secrets)
- [Questions](#questions)

## GitHub Actions CI/CD

This repository includes automated testing that runs on every commit.

### What Gets Tested

**On Every Push:**
- ✅ Docker Compose validation
- ✅ Shell script linting (shellcheck)
- ✅ Python code validation
- ✅ Security scanning (no secrets)
- ✅ Documentation checks
- ✅ Integration testing
- ✅ Encryption testing

**Daily:**
- 🔐 TruffleHog secret scanning
- 🔐 Hadolint Dockerfile linting
- 🔐 Dependency vulnerability scanning
- 🔐 Docker image security (Trivy)

**Weekly:**
- 📦 Dependabot dependency updates

### View Test Results

https://github.com/etiennechabert/limesurvey-pi-stack/actions

### Running Tests Locally

```bash
# Docker Compose validation
docker compose config

# Shell scripts
shellcheck scripts/*.sh

# Python
cd backup-service
python -m py_compile backup.py

# Security check
./scripts/pre-commit-check.sh
```

## Contributing Changes

### Before Committing

1. **Run security check:**
   ```bash
   ./scripts/pre-commit-check.sh
   ```

2. **Test locally:**
   ```bash
   docker compose config
   shellcheck scripts/*.sh
   ```

3. **Commit:**
   ```bash
   git add .
   git commit -m "Your message"
   git push
   ```

4. **Watch CI:** Check Actions tab for results

### Pull Requests

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure tests pass
5. Submit PR

CI will automatically test your PR.

## Code Style

### Shell Scripts
- Use `shellcheck` for linting
- Include error handling (`set -e`)
- Add descriptive comments

### Python
- Follow PEP 8
- Use type hints where helpful
- Add docstrings to functions

### Documentation
- Use clear, concise language
- Include code examples
- Test all commands before documenting

## Security

### Never Commit

- `.env` files
- `google-credentials.json`
- Backup files (`.sql`, `.sql.gz`)
- Private keys

### If You Accidentally Commit Secrets

1. **Immediately rotate** all exposed credentials
2. **Remove from history:**
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch .env" \
     --prune-empty --tag-name-filter cat -- --all
   ```
3. **Force push** (with caution)

## Questions?

Open an issue: https://github.com/etiennechabert/limesurvey-pi-stack/issues
