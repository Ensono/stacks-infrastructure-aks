#!/bin/bash
set -e

echo "Rolling back to taskctl..."
echo ""

# Restore from backups
echo "Restoring taskctl configuration..."
cp taskctl.yaml.backup taskctl.yaml
rm -f eirctl.yaml
rm -rf build/eirctl
cp -r build/taskctl.backup build/taskctl

# Restore CI/CD files from git history
echo "Restoring CI/CD files..."
git checkout build/azDevOps/azure/

# Restore documentation from git history
echo "Restoring documentation..."
git checkout .github/copilot-instructions.md docs/

echo ""
echo "✓ Rollback complete."
echo ""
echo "Next steps:"
echo "1. Review git status: git status"
echo "2. Verify taskctl still works: taskctl lint"
echo "3. Remove rollback artifacts if desired: rm taskctl.yaml.backup && rm -rf build/taskctl.backup"
