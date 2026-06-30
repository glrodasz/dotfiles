.DEFAULT_GOAL := help

DOTFILES      := $(HOME)/dotfiles
CURSOR_SKILLS := $(HOME)/.cursor/skills-cursor
CLAUDE_SKILLS := $(HOME)/.claude/skills
SKILLS        := $(notdir $(patsubst %/,%,$(dir $(wildcard $(DOTFILES)/skills/*/SKILL.md))))

.PHONY: help slink slink-skills slink-skills-cursor slink-skills-claude slink-zsh slink-vim \
        install install-brew install-npm \
        backup backup-brew backup-apps backup-npm

help: ## List available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}' | \
		sort

## Symlinks

slink: slink-skills slink-zsh slink-vim ## Symlink all dotfiles configs

slink-skills: slink-skills-cursor slink-skills-claude ## Symlink skills into Cursor and Claude

slink-skills-cursor: ## Symlink skills into ~/.cursor/skills-cursor
	@mkdir -p $(CURSOR_SKILLS)
	@for s in $(SKILLS); do \
		rm -rf "$(CURSOR_SKILLS)/$$s"; \
		ln -s "$(DOTFILES)/skills/$$s" "$(CURSOR_SKILLS)/$$s"; \
		echo "linked $$s -> cursor"; \
	done

slink-skills-claude: ## Symlink skills into ~/.claude/skills
	@mkdir -p $(CLAUDE_SKILLS)
	@for s in $(SKILLS); do \
		rm -rf "$(CLAUDE_SKILLS)/$$s"; \
		ln -s "$(DOTFILES)/skills/$$s" "$(CLAUDE_SKILLS)/$$s"; \
		echo "linked $$s -> claude"; \
	done

slink-zsh: ## Symlink ~/.zshrc
	@ln -sfn $(DOTFILES)/zsh/.zshrc ~/.zshrc
	@echo "linked ~/.zshrc"

slink-vim: ## Symlink ~/.vimrc and solarized colors
	@ln -sfn $(DOTFILES)/vim/.vimrc ~/.vimrc
	@mkdir -p ~/.vim/colors
	@ln -sfn $(DOTFILES)/vim/vim-colors-solarized/colors/solarized.vim ~/.vim/colors/solarized.vim
	@echo "linked ~/.vimrc and solarized colors"

## Install

install: install-brew install-npm ## Install brew and npm packages from backups

install-brew: ## Install brew packages from brew/packages
	@cat $(DOTFILES)/brew/packages | xargs brew install

install-npm: ## Install global npm packages
	@npm install -g public-ip-cli internal-ip-cli trash-cli vercel serve

## Backup

backup: backup-brew backup-apps backup-npm ## Regenerate all backup files

backup-brew: ## Update brew/packages via interactive script
	@$(DOTFILES)/brew/update-brew-packages.sh

backup-apps: ## Update apps/installed-apps.json via interactive script
	@$(DOTFILES)/apps/update-installed-apps.sh

backup-npm: ## Print global npm packages (for manual backup)
	@npm list -g --depth 0
