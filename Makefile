.PHONY: all build run dmg clean help

all: build

help:
	@echo "NoteNote Build Targets:"
	@echo "  make build   - Build the NoteNote.app release bundle"
	@echo "  make run     - Build and launch NoteNote.app"
	@echo "  make dmg     - Build the release installer NoteNote.dmg"
	@echo "  make clean   - Remove build artifacts and temporary files"

build:
	@chmod +x scripts/build_app.sh
	./scripts/build_app.sh

run: build
	@echo "🚀 Launching NoteNote..."
	open NoteNote.app

dmg:
	@chmod +x scripts/build_dmg.sh
	./scripts/build_dmg.sh

clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf .build
	rm -rf NoteNote.app
	rm -rf NoteNote.dmg
	rm -rf temp_*.dmg
	rm -rf .dmg_staging
	rm -f *.log
	find . -name ".DS_Store" -depth -exec rm -f {} +
	@echo "✨ Clean complete!"
