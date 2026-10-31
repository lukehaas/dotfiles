#!/usr/bin/env bash
# macOS preferences
# Run manually: ./macos/defaults.sh

# Inspired by https://github.com/geerlingguy/dotfiles/blob/master/.osx

set -euo pipefail

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
# Full keyboard access: Tab moves focus between all controls
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
# Disable smart quotes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
# Disable smart dashes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
# Disable automatic capitalisation
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
# Disable automatic period substitution on double space
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
# Save to disk (not iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

###############################################################################
# Dock                                                                        #
###############################################################################

# auto-hide, no recent apps
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false

###############################################################################
# Screen                                                                      #
###############################################################################

# Screenshots location
mkdir -p "$HOME/Documents/screenshots"
defaults write com.apple.screencapture location -string "~/Documents/screenshots"

###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
###############################################################################

# Tap to click disabled
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool false

# Natural scrolling disabled
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

###############################################################################
# Finder                                                                      #
###############################################################################

# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true
# Column view
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"
# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
# Avoid creating .DS_Store files on USB volumes
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

###############################################################################
# Photos                                                                      #
###############################################################################

# Prevent Photos from opening automatically when devices are plugged in
defaults write com.apple.ImageCapture disableHotPlug -bool true

###############################################################################
# Safari & WebKit                                                             #
###############################################################################

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# Add a context menu item for showing the Web Inspector in web views
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

###############################################################################
# App Store                                                                   #
###############################################################################

# Disable in-app rating requests from apps downloaded from the App Store.
defaults write com.apple.appstore InAppReviewEnabled -int 0

for app in Finder Dock SystemUIServer; do
  killall "$app" &>/dev/null || true
done
