#!/usr/bin/env bash
# integrate_kilocode.sh - Integrate Kilo Code into VSCodium build

set -e

echo "=== Integrating Kilo Code ==="

# Paths
KILOCODE_SOURCE="/home/josh/Documents/windsurfinfo/kilocode"
KILOCODE_DIST="${KILOCODE_SOURCE}/src/dist"
VSCODE_EXTENSIONS="./vscode/extensions"
TARGET_DIR="${VSCODE_EXTENSIONS}/kilo-code"

# Verify Kilo Code was built
if [ ! -d "${KILOCODE_DIST}" ]; then
  echo "ERROR: Kilo Code not built. Run 'cd ${KILOCODE_SOURCE} && pnpm build' first"
  exit 1
fi

if [ ! -f "${KILOCODE_DIST}/extension.js" ]; then
  echo "ERROR: Kilo Code dist/extension.js not found"
  exit 1
fi

# Verify vscode/extensions exists
if [ ! -d "${VSCODE_EXTENSIONS}" ]; then
  echo "ERROR: vscode/extensions directory not found. Run prepare_vscode.sh first"
  exit 1
fi

# Remove old integration if exists
if [ -d "${TARGET_DIR}" ]; then
  echo "Removing old Kilo Code integration..."
  rm -rf "${TARGET_DIR}"
fi

# Create target directory
echo "Creating extension directory..."
mkdir -p "${TARGET_DIR}"

# Copy dist directory (preserve folder structure like VS Code built-ins)
echo "Copying Kilo Code dist to ${TARGET_DIR}/dist/..."
mkdir -p "${TARGET_DIR}/dist"
cp -r "${KILOCODE_DIST}"/* "${TARGET_DIR}/dist/"

# Copy package.json and localization files from src/
echo "Copying package.json..."
cp "${KILOCODE_SOURCE}/src/package.json" "${TARGET_DIR}/"

# Copy package.nls.json for extension manifest localization
if [ -f "${KILOCODE_SOURCE}/src/package.nls.json" ]; then
  echo "Copying package.nls.json..."
  cp "${KILOCODE_SOURCE}/src/package.nls.json" "${TARGET_DIR}/"
fi

# Copy additional required files
if [ -f "${KILOCODE_SOURCE}/README.md" ]; then
  cp "${KILOCODE_SOURCE}/README.md" "${TARGET_DIR}/"
fi

if [ -f "${KILOCODE_SOURCE}/LICENSE" ]; then
  cp "${KILOCODE_SOURCE}/LICENSE" "${TARGET_DIR}/"
fi

if [ -f "${KILOCODE_SOURCE}/changelog.md" ]; then
  cp "${KILOCODE_SOURCE}/changelog.md" "${TARGET_DIR}/"
fi

# Copy assets
if [ -d "${KILOCODE_SOURCE}/src/assets" ]; then
  echo "Copying assets..."
  cp -r "${KILOCODE_SOURCE}/src/assets" "${TARGET_DIR}/"
fi

# Copy webview-ui
if [ -d "${KILOCODE_SOURCE}/src/webview-ui" ]; then
  echo "Copying webview-ui..."
  cp -r "${KILOCODE_SOURCE}/src/webview-ui" "${TARGET_DIR}/"
fi

# Copy walkthrough
if [ -d "${KILOCODE_SOURCE}/src/walkthrough" ]; then
  echo "Copying walkthrough..."
  cp -r "${KILOCODE_SOURCE}/src/walkthrough" "${TARGET_DIR}/"
fi

# Copy integrations
if [ -d "${KILOCODE_SOURCE}/src/integrations" ]; then
  echo "Copying integrations..."
  cp -r "${KILOCODE_SOURCE}/src/integrations" "${TARGET_DIR}/"
fi

# Copy i18n locales
if [ -d "${KILOCODE_SOURCE}/src/i18n/locales" ]; then
  echo "Copying i18n locales..."
  mkdir -p "${TARGET_DIR}/i18n"
  cp -r "${KILOCODE_SOURCE}/src/i18n/locales" "${TARGET_DIR}/i18n/"
fi

# Modify package.json to set publisher to "vscodium" and keep only external dependencies
if command -v jq &> /dev/null; then
  echo "Normalizing package.json for built-in distribution..."
  jq '(.publisher = "vscodium")
      | (.dependencies = {"sqlite3": .dependencies.sqlite3, "sqlite": .dependencies.sqlite})
      | (.devDependencies = {})
      | del(.pnpm)
      | del(.packageManager)
      | del(.scripts)' "${TARGET_DIR}/package.json" > "${TARGET_DIR}/package.json.tmp"
  mv "${TARGET_DIR}/package.json.tmp" "${TARGET_DIR}/package.json"
else
  echo "WARNING: jq not found. Please manually normalize package.json (publisher/dependencies)."
fi

# Install external (non-bundled) dependencies
echo "Installing external dependencies (sqlite3, sqlite)..."
cd "${TARGET_DIR}"
npm install --production --no-save --legacy-peer-deps 2>&1 | grep -v "^npm WARN" || true
cd - > /dev/null

# Verify integration
if [ -f "${TARGET_DIR}/dist/extension.js" ] && [ -f "${TARGET_DIR}/package.json" ] && [ -f "${TARGET_DIR}/package.nls.json" ]; then
  echo "✓ Kilo Code integrated successfully"
  echo "  Location: ${TARGET_DIR}"
  echo "  Files copied: $(find ${TARGET_DIR} -type f | wc -l)"
  echo "  Total size: $(du -sh ${TARGET_DIR} | cut -f1)"
  
  # Verify sqlite3 was installed
  if [ -d "${TARGET_DIR}/node_modules/sqlite3" ]; then
    echo "  ✓ sqlite3 dependency installed"
  else
    echo "  ⚠ WARNING: sqlite3 dependency not found (extension may fail to activate)"
  fi
else
  echo "ERROR: Integration verification failed"
  echo "  Missing required files:"
  [ ! -f "${TARGET_DIR}/dist/extension.js" ] && echo "    - dist/extension.js"
  [ ! -f "${TARGET_DIR}/package.json" ] && echo "    - package.json"
  [ ! -f "${TARGET_DIR}/package.nls.json" ] && echo "    - package.nls.json"
  exit 1
fi

echo "=== Kilo Code Integration Complete ==="
