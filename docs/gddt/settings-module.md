# GDDT Settings Module

This document describes the current settings module that is implemented in this plugin. It is the first feature area shipped by GDDT and focuses on tracking, reviewing, applying, and sharing editor settings and editor layouts.

This module is centered around two primary surfaces:

- the GDDT Settings menu in the editor UI
- the Godot Development Tools tab in the Editor Settings window

The plugin also adds a direct editor context-menu action for individual settings and a layout-tracking action inside the Editor Layout menu.

---

## Scope of the current module

The settings module currently covers:

- tracking editor settings that differ from the default editor state
- reviewing tracked settings and drift against the local editor
- applying a saved shared config back onto the current editor
- auto-applying configuration on startup
- managing risk warnings for paths that look machine-specific or user-specific
- tracking editor layout sections for selective layout sharing
- installing a tracked layout package back into the project editor layout file
- status reporting and self-checks for the settings workflow

---

## Where to find the features

### 1) GDDT Settings submenu

The plugin adds a submenu named GDDT Settings to the main editor menu when it can find the Editor popup menu.

If the editor popup is not discoverable, it falls back to the Tools menu instead.

The submenu includes:

- Apply Current Config
- Save Current Config Changes
- Build Tracked Settings from Current Diffs
- Auto Apply on Startup
- Status line (display-only, disabled item)

The status text is generated from the current profile state and shows:

- config version
- applied version
- tracked count
- drift count
- sync state
- auto-apply state

### 2) Editor Settings tab

The plugin injects a tab named Godot Development Tools into the Editor Settings tab container when the standard Godot editor settings UI is present.

This is the main management surface for the settings module.

### 3) Editor Layout menu

The plugin adds a menu action named Track Layouts... inside the Editor Layout menu.

This opens a dialog that lets the user choose which layout entries should be tracked and shared.

The Track Layouts dialog includes:

- a list of available layout names
- a checkbox beside each layout entry
- Save button to persist the selected tracked layout set
- Load Layout... button to open the tracked-layout installation dialog

### 4) Inspector property context menu

When right-clicking an editor setting in the Inspector, the plugin adds a contextual menu entry for settings that are valid editor-setting paths:

- Track Setting
- Untrack Setting

This provides a quick path for tracking a specific setting without opening the full settings tree.

---

## Settings profile model

The settings module stores its own profile in:

- addons/gddt/editor/settings.tres

This profile holds:

- config_version
- auto_apply_enabled
- setting_overrides
- risky_warning_keywords
- tracked_editor_layouts

The plugin also tracks the last applied version in project metadata so the editor can detect whether the current config is newer than what has been applied.

Important behavior:

- reserved tracking keys are intentionally excluded
- the plugin prevents the internal applied-version metadata itself from being tracked
- a local lock is enforced to keep the applied-version state consistent with the saved profile

---

## Feature-by-feature documentation

### Apply Current Config

Available in:

- GDDT Settings submenu
- Godot Development Tools tab -> Apply Current Config button

What it does:

- iterates all tracked editor settings
- compares the current local editor value with the tracked value
- writes the tracked value back to the editor when it differs
- applies tracked editor layout sections as part of the same process
- updates the applied-version metadata after the apply completes

This is the main action that enforces the saved configuration on the current editor session.

### Save Current Config Changes

Available in:

- GDDT Settings submenu
- Godot Development Tools tab -> Save Current Config Changes button

What it does:

- scans the current editor settings for non-default values
- records only valid tracked paths
- stores those values in the profile as the current configuration snapshot
- increments the config version when the saved profile changes

This is the action used to persist the current local-editor configuration as the shared tracked state.

### Build Tracked Settings from Current Diffs

Available in:

- GDDT Settings submenu
- Godot Development Tools tab -> Build Tracked from Current Diffs button

What it does:

- enumerates the current editor settings
- finds all settings that differ from their default revert values
- records those as tracked overrides
- updates the config version when the tracked set changes

This is useful when you want the profile to rapidly capture the current editor state without individually toggling settings by hand.

### Auto Apply on Startup

Available in:

- GDDT Settings submenu -> check item
- Godot Development Tools tab -> Auto Apply on Startup checkbox

What it does:

- toggles whether the plugin automatically applies the tracked config when the editor starts
- if the saved config version is newer than the last applied version, it triggers apply_current_config()

This makes the plugin behave like a lightweight shared editor preset system at startup.

### Version / Sync status

Available in:

- GDDT Settings submenu status entry
- Godot Development Tools tab status label

Status text format:

- Version X
- Applied Y
- Tracked Z
- Drift D
- Sync: In Sync / Out of Sync (Version) / Out of Sync (Drift) / Out of Sync (Version + Drift)
- Auto: On / Off

This status is designed to answer three questions quickly:

1. are the tracked settings newer than the local applied state?
2. is the local editor diverging from the tracked profile?
3. is auto-apply enabled?

### Preview Apply Changes

Available in:

- Godot Development Tools tab -> Preview Apply Changes button

What it does:

- reads the pending tracked-setting diff
- displays a preview of the current value and target value for each pending change
- shows up to a limited number of rows and summarizes the rest if there are many

This helps users validate the diff before applying it.

### Rollback Last Apply

Available in:

- Godot Development Tools tab -> Rollback Last Apply button

What it does:

- restores the previous values from the last apply snapshot
- uses the exact pre-apply local values that were recorded during the last config application

This is a safety net when a recently applied shared config did not match the desired editor state.

### Run Self Checks

Available in:

- Godot Development Tools tab -> Run Self Checks button

What it does:

- validates the tracking workflow in a temporary setting path
- checks that the reserved applied-version key is non-trackable
- verifies tracking/untracking works
- validates apply preview behavior
- validates apply flow behavior
- validates rollback behavior
- executes the lock enforcement path

The output is displayed in the preview label and tells the user whether the core workflow passes or fails.

---

## Settings manager tab layout

The Godot Development Tools tab is organized as a single vertical control stack.

### Top workflow row

Buttons in order:

1. Apply Current Config
2. Preview Apply Changes
3. Rollback Last Apply
4. Save Current Config Changes
5. Build Tracked from Current Diffs
6. Run Self Checks
7. Auto Apply on Startup checkbox

These are the primary operations for the settings workflow.

### Status and preview surfaces

The tab includes:

- status label
- preview label
- risk notice label

The status label reports version, sync, and drift information.

The preview label shows:

- no pending changes when nothing is diffed
- a preview list when tracked values differ from the local editor
- self-check results after running validation

The risk notice reads:

> RISKY flags are advisory only and never block tracking or saving.

This makes the cautionary layer explicit: the flags are for awareness, not enforcement.

### Risk warning keywords

The tab includes a row with:

- a LineEdit field for comma-separated keywords
- Save Warning Keywords button
- Reset Defaults button

Purpose:

- classify a setting as risky if the path contains one of the configured keywords
- help users spot settings that are likely user-specific, machine-specific, or environment-specific
- encourage caution before tracking or applying a config that could be problematic on a different machine

Default keywords include terms such as:

- password, token, secret, auth, key, profile, host, path, dir, sdk, cache, temp, plugin, etc.

### Search, sort, and filter controls

The tab includes:

- Search settings path
- Sort: A to Z / Z to A
- Filter: All / Tracked / Untracked / Changed from Default
- Category: All / category-specific submenus

These controls let users narrow the visible settings list before tracking or reviewing them.

### Bulk action controls

The tab includes buttons for working on the currently visible or selected subset:

- Track Visible
- Untrack Visible
- Track Category
- Untrack All

These are bulk convenience actions for managing multiple editor settings at once.

### Settings tree

The main list is a three-column Tree:

- Track checkbox column
- Setting path
- Flags column

Each row contains a checkbox that can be toggled directly.

The tree shows:

- tracked state
- risk flags
- changed-from-tracked status
- non-trackable classification

Flags can include:

- NON-TRACKABLE
- RISKY
- CHANGED

Definitions:

- NON-TRACKABLE: the path is reserved or otherwise not eligible for tracking
- RISKY: the setting path looks machine-specific or user-specific
- CHANGED: the local value differs from the tracked value

---

## Tracking behavior

### What counts as a valid setting

A setting can be tracked only when:

- it exists in the editor settings
- it is not reserved by GDDT
- it contains a slash-separated property path

The plugin intentionally excludes the internal applied-version tracking key.

### Track / untrack flow

Users can:

- toggle a setting in the tree
- bulk track or untrack visible settings
- bulk track a whole category
- untrack all stored settings
- track a setting from the Inspector context menu

When a path is toggled, the tracked value is saved as the current editor value.

### Drift detection

If a tracked value no longer matches the local editor value, the row is marked as CHANGED and the status surface shows drift.

This makes it easy to see when the local editor differs from the configured shared profile.

---

## Risk analysis and warning model

Risky detection is advisory, not blocking.

A setting is flagged as risky when the path includes one of the configured warning keywords, such as:

- password
- token
- auth
- host
- path
- sdk
- cache
- temp
- profile
- plugin

Any path containing absolute filesystem references or Windows-style path separators is also treated as risky.

This warning system is meant to reduce accidental tracking of personal or machine-specific values.

---

## Editor layout tracking and sharing

The settings module also includes editor-layout support.

### Track Layouts dialog

Opened from the Editor Layout menu.

It lists all available editor layouts and allows the user to check which ones should be tracked.

This preserves and shares selected layout sections while ignoring unselected ones.

Any tracked layout is captured from the current layout file and stored in the settings profile.

### Load Layout... action

From the Track Layouts dialog, users can click Load Layout... to open a second dialog that presents grouped tracked layout packages.

This dialog groups tracked entries by package root and shows child sections underneath each root.

Selecting a package root and confirming the dialog installs the tracked layout package into the project editor layouts file.

This enables selective sharing and installation of layout packages without flattening all layout data into a single list.

### Shared layout behavior

The module preserves subsection-level entries rather than collapsing everything into a single top-level layout entry.

That means a tracked package can contain multiple related layout sections under one package root, and users can install only the package they want.

---

## Current user-facing element map

### Editor menu

Menu name:

- GDDT Settings

Actions included:

- Apply Current Config
- Save Current Config Changes
- Build Tracked Settings from Current Diffs
- Auto Apply on Startup
- Status display item

### Editor Settings tab

Tab name:

- Godot Development Tools

Primary controls:

- Apply Current Config
- Preview Apply Changes
- Rollback Last Apply
- Save Current Config Changes
- Build Tracked from Current Diffs
- Run Self Checks
- Auto Apply on Startup
- Save Warning Keywords
- Reset Defaults
- Search settings path
- Sort selector
- Filter selector
- Category selector
- Track Visible
- Untrack Visible
- Track Category
- Untrack All

### Editor Layout menu

Action name:

- Track Layouts...

Related dialog actions:

- Save
- Load Layout...
- Cancel

### Inspector context menu

Actions:

- Track Setting
- Untrack Setting

---

## Operational notes

- The settings module is the first feature area implemented in the plugin and is intentionally focused on editor configuration management.
- It is designed to be practical for team sharing, without forcing all editor settings to be tracked or applied blindly.
- Risky paths are flagged as a warning, not a block.
- The module is built around a clear split between:
  - the tracked shared profile
  - the local active editor state
  - the last apply snapshot for rollback

---

## Summary

The current settings module gives users a complete management workflow for editor settings and a selective layout-sharing workflow for the editor layout system.

The main user-facing surfaces are:

- the GDDT Settings submenu
- the Godot Development Tools editor-settings tab
- the Editor Layout -> Track Layouts... action
- Inspector context-menu handling for individual settings

Together these provide a practical system for tracking, validating, applying, and sharing editor settings and layout sections without flattening everything into a single global state.
