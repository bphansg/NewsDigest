# ============================================================================
# NewsDigest — Makefile
# ============================================================================
# Usage:
#   make          — Build the app + create DMG installer
#   make build    — Build the app only (no DMG)
#   make dmg      — Build + create DMG
#   make clean    — Remove all build artifacts
#   make run      — Build and run the app
#   make open     — Open the Xcode project
# ============================================================================

APP_NAME    := NewsDigest
PROJECT     := $(APP_NAME).xcodeproj
SCHEME      := $(APP_NAME)
BUILD_DIR   := build
CONFIG      := Release

.PHONY: all build dmg clean run open help

all: dmg

help:
	@echo ""
	@echo "  NewsDigest Build System"
	@echo "  ─────────────────────────────"
	@echo "  make          Build app + DMG"
	@echo "  make build    Build app only"
	@echo "  make dmg      Build + DMG"
	@echo "  make run      Build and launch"
	@echo "  make clean    Clean all"
	@echo "  make open     Open in Xcode"
	@echo ""

# Build the app via xcodebuild
build:
	@echo "→ Building $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	@xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(BUILD_DIR)/derived \
		build \
		2>&1 | grep -E "(Build Succeeded|error:|warning:)" || true
	@BUILT=$$(find $(BUILD_DIR)/derived -name "$(APP_NAME).app" -type d | head -1); \
	if [ -n "$$BUILT" ]; then \
		rm -rf $(BUILD_DIR)/$(APP_NAME).app; \
		cp -R "$$BUILT" $(BUILD_DIR)/$(APP_NAME).app; \
		echo "✓ Built: $(BUILD_DIR)/$(APP_NAME).app"; \
	else \
		echo "✗ Build failed — no .app found"; \
		exit 1; \
	fi

# Build + create DMG
dmg: build
	@echo "→ Creating DMG..."
	@chmod +x scripts/create-dmg.sh
	@bash scripts/create-dmg.sh $(BUILD_DIR)/$(APP_NAME).app

# Clean everything
clean:
	@echo "→ Cleaning..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ Clean"

# Build and run
run: build
	@echo "→ Launching $(APP_NAME)..."
	@open $(BUILD_DIR)/$(APP_NAME).app

# Open in Xcode
open:
	@open $(PROJECT)
