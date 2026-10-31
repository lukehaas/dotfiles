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
# Key repeat instead of the accent popup when holding a key
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# Fast key repeat (units of ~15ms)
defaults write NSGlobalDomain InitialKeyRepeat -int 20  # ~300ms delay
defaults write NSGlobalDomain KeyRepeat -int 2          # ~30ms between repeats
# Disable two-finger swipe left/right to go back/forward
defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false

###############################################################################
# Dock                                                                        #
###############################################################################

# auto-hide, no recent apps
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
# Icon size
defaults write com.apple.dock tilesize -int 64
# Disable bottom-right hot corner (default is Quick Note)
defaults write com.apple.dock wvous-br-corner -int 1
defaults write com.apple.dock wvous-br-modifier -int 0
# Disable Mission Control and Show Desktop gestures
defaults write com.apple.dock showMissionControlGestureEnabled -bool false
defaults write com.apple.dock showDesktopGestureEnabled -bool false

###############################################################################
# Screen                                                                      #
###############################################################################

# Screenshots location
mkdir -p "$HOME/Documents/screenshots"
defaults write com.apple.screencapture location -string "~/Documents/screenshots"
# Capture a window by default, with a 5 second delay
defaults write com.apple.screencapture style -string "window"
defaults write com.apple.screencapture captureDelay -int 5

###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
###############################################################################

# Tap to click disabled
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool false

# Natural scrolling disabled
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable 3/4 finger swipes (Spaces, Mission Control, App Exposé), Launchpad
# pinch and Notification Centre edge swipe, for built-in and Magic Trackpad
for domain in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  defaults write "$domain" TrackpadThreeFingerHorizSwipeGesture -int 0
  defaults write "$domain" TrackpadThreeFingerVertSwipeGesture -int 0
  defaults write "$domain" TrackpadFourFingerHorizSwipeGesture -int 0
  defaults write "$domain" TrackpadFourFingerVertSwipeGesture -int 0
  defaults write "$domain" TrackpadFourFingerPinchGesture -int 0
  defaults write "$domain" TrackpadFiveFingerPinchGesture -int 0
  defaults write "$domain" TrackpadTwoFingerFromRightEdgeSwipeGesture -int 0
done
# System Settings mirrors the gestures here too
defaults -currentHost write NSGlobalDomain com.apple.trackpad.threeFingerHorizSwipeGesture -int 0
defaults -currentHost write NSGlobalDomain com.apple.trackpad.threeFingerVertSwipeGesture -int 0
defaults -currentHost write NSGlobalDomain com.apple.trackpad.fourFingerHorizSwipeGesture -int 0
defaults -currentHost write NSGlobalDomain com.apple.trackpad.fourFingerVertSwipeGesture -int 0
defaults -currentHost write NSGlobalDomain com.apple.trackpad.fourFingerPinchSwipeGesture -int 0
defaults -currentHost write NSGlobalDomain com.apple.trackpad.fiveFingerPinchSwipeGesture -int 0
defaults -currentHost write NSGlobalDomain com.apple.trackpad.twoFingerFromRightEdgeSwipeGesture -int 0

# Disable Spotlight (64, 65) and input source (60, 61) shortcuts to free
# Cmd-Space and Ctrl-Space
for id in 60 61 64 65; do
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" "<dict><key>enabled</key><false/></dict>"
done
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

###############################################################################
# Finder                                                                      #
###############################################################################

# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true
# Column view
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"
# Show path bar and status bar
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
# New windows open in home folder
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
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

###############################################################################
# Hammerspoon                                                                 #
###############################################################################

# Load config from ~/.config instead of ~/.hammerspoon
defaults write org.hammerspoon.Hammerspoon MJConfigFile "~/.config/hammerspoon/init.lua"

for app in Finder Dock SystemUIServer; do
  killall "$app" &>/dev/null || true
done

printf "Please log out and log back in to make all settings take effect.\n"
