#!/bin/bash
# Pre-Commit Security Check
# Run this before committing to ensure no sensitive data is included

set -e

echo "=========================================="
echo "Pre-Commit Security Check"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

echo "Checking for sensitive files in git staging area..."
echo ""

# Check if .env is staged
if git ls-files --error-unmatch .env 2>/dev/null; then
    echo -e "${RED}❌ ERROR: .env is staged for commit!${NC}"
    echo "   This file contains secrets and should NEVER be committed."
    echo "   Run: git reset HEAD .env"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓${NC} .env is not staged (good)"
fi

# Check if google-credentials.json is staged
if git ls-files --error-unmatch google-credentials.json 2>/dev/null; then
    echo -e "${RED}❌ ERROR: google-credentials.json is staged for commit!${NC}"
    echo "   This file contains Google API credentials and should NEVER be committed."
    echo "   Run: git reset HEAD google-credentials.json"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓${NC} google-credentials.json is not staged (good)"
fi

# Check for any backup files
if git ls-files --error-unmatch 'backups/*.sql*' 2>/dev/null; then
    echo -e "${RED}❌ ERROR: Backup files (.sql, .sql.gz) are staged for commit!${NC}"
    echo "   Backup files may contain sensitive data and should not be committed."
    echo "   Run: git reset HEAD backups/*.sql*"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓${NC} No backup files staged (good)"
fi

# Check for any .key or .pem files
if git ls-files --error-unmatch '*.key' '*.pem' 2>/dev/null; then
    echo -e "${RED}❌ ERROR: Key files (.key, .pem) are staged for commit!${NC}"
    echo "   These files should NEVER be committed."
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓${NC} No key files staged (good)"
fi

echo ""

# Check for common secret patterns in staged files
echo "Scanning staged files for potential secrets..."
echo ""

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
    echo -e "${YELLOW}⚠${NC}  No files staged for commit"
    echo ""
else
    # Check for patterns that might be secrets (basic check)
    for file in $STAGED_FILES; do
        # Skip binary files and directories
        if [ -f "$file" ] && file "$file" | grep -q text; then
            # Check for potential secrets (very basic check)
            if grep -qiE '(password|token|secret|key)\s*=\s*["\047][^"\047]{10,}' "$file" 2>/dev/null; then
                echo -e "${YELLOW}⚠${NC}  Warning: Possible secret in $file"
                echo "   Please verify this file doesn't contain real credentials"
            fi
        fi
    done
fi

echo ""
echo "=========================================="

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo "Safe to commit."
    echo ""
    echo "Next steps:"
    echo "  git commit -m 'Your message'"
    echo "  git push"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS critical issue(s)${NC}"
    echo "Please fix the issues above before committing."
    echo ""
    echo "To unstage files:"
    echo "  git reset HEAD <file>"
    echo ""
    echo "To check what's staged:"
    echo "  git status"
    exit 1
fi
