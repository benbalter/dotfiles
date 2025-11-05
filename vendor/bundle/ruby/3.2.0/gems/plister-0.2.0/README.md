# Plister

*A utility for programmatically setting OS X plist file preferences*

[![Build Status](https://travis-ci.org/benbalter/plister.svg?branch=master)](https://travis-ci.org/benbalter/plister)

## What it does

Most dotfile setups have a string of cryptic `defaults write com.apple...`-type commands. Plister simplifies that process by allowing you to store your OS X preferences in a single YAML file (likely in your home directory or within your dotfiles repostiory), and exposes a single `plister` command line tool to set your saved preferences.

See [@benbalter's dotfiles for an example](https://github.com/benbalter/dotfiles/blob/master/.osx.yml).

## Usage

1. Install the Gem (`gem install plister`)
2. Create a preference file as `~/.osx.yml` (see below)
3. Run `plister` command to set the desired preferences

### The command line tool

`$ plister [path-to-your-preferences.yml] [options]`

If no preference file is passed, Plister will default to `~/.osx.yml`.

### Creating a preference file

1. Create a file in your home directory called `.osx.yml` (or symlink it from elsewhere)
.
2. Add your OS X preferences to the `.osx.yml` file, following the instructions below.

### Dumping existing preferences

To dump all your existing preferences, run `plister [path-to-your-preferences.yml] --dump`. This will output all your existing preferences as a YAML file at the specified path, defaulting to `~/.osx.yml` if none is given. You can also pass the `--stdout` flag to dump preferences to STDOUT.

### Describing preferences

OS X has several different ways of storing preferences, each with their own domain (e.g., `com.apple.safari`). If you're copying your preferences from a tutorial or someone else's dotfiles, you can tell the domain and type by the command used to set it.

```
defaults write -someFlag com.apple.safari key value
COMMAND        FLAG      DOMAIN           SETTING
```

#### User preferences

User preferences are specific to a user and live in `~/Library/Preferences`. They are the default and have no flag. Example: `defaults write com.apple.safari someSetting -int 0`.

#### System preferences

System preferences are system wide and live in `/Library/Preferenences`. These are often passed as absolute paths, and require `sudo`. Example: `sudo defaults write /Library/Preferences/com.apple.safari.plist someSetting -int 0`.

#### Global preferences

Global preferences are not application specific and have a domain of `NSGlobalDomain`. This may be omitted in favor of the `-g` or `-globalDomain` flag. Global preference can be either user or system preferences and should be stored with a key of `.GlobalPreferences` in your config file. Example: `defaults write NSGlobalDomain someSetting -int 0`.

#### Host preferences

Host preferences live in `~/Library/Preferences/byHost` and are identified by the `-currentHost` flag. Example: `defaults write -currentHost com.apple.safari someSetting -int 0`.

### The `.osx.yml` file

Settings are group by type and domain within your `.osx.yml` file.

```yml
user:
  com.apple.safari:
    someSetting: 0
    anotherSetting: my-value

  com.apple.dock:
    autohide: true

  # NSGlobalDomain preferences
  .GlobalPreferences:
    WebKitDeveloperExtras: true

system:
  com.apple.SoftwareUpdate:
    AutomaticCheckEnabled: true

host:
  com.apple.ScreenSaver.iLifeSlideShows:
    styleKey: VintagePrints
```

The above would be equivalent to:

```
defaults write com.apple.safari someSetting -int 0
defaults write com.apple.safari anotherSetting my-value
defaults write com.apple.dock autohide -bool true
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true
sudo defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
default write -currentHost com.apple.ScreenSaver.iLifeSlideShows styleKey VintagePrints
```

## Not writable errors

If you get an error that looks like:

```
/Library/Preferences/[DOMAIN].plist is not writable by [USER] (IOError)
```

You'll need to preface the `plister` command with `sudo` so that Ruby can write the system-wide preference.
