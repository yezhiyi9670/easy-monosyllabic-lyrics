# Easy Monosyllabic Lyrics

<img align=right src="./EasyMonosyllabicLyrics.png" width=220px />

> This is a [MuseScore](http://musescore.org/) plugin modified from [bakajikara/MuseScoreLyricsJP (日本語歌詞入力)](https://github.com/bakajikara/MuseScoreLyricsJP), ported to MuseScore 3.
> 
> ⚠️ **This branch works only on MuseScore 4.4 and above. If you use MuseScore ≤4.3, check the `main` branch.**

Typing lyrics in monosyllabic languages (one syllable per character, no spaces between them, for example Chinese) has always been painful. We have to either type characters one by one and add spaces, or add spaces via an external text editor and paste the lyrics back by pressing Ctrl+V multiple times.

The [lyricsHelper](https://github.com/SnakeAmadeus/lyricsHelper) plugin somehow solves this problem, but it can only read lyrics from an external txt file, so it is probably not suitable for music composition, which may require frequently modifying the lyrics on the go.

This plugin addresses these issues.

![Screenshot](readme-assets/screenshot.png)

## Installation

1. Download the code and unzip it under the user's `Plugins` directory (check MuseScore preferences if you don't know where).
2. Restart MuseScore, and you should be able to activate the plugin in the plugin manager.

## Usage

Select the starting note, and run this plugin from the Plugin menu or via keyboard shortcut. The dialog will open.

![Dialog](readme-assets/dialog.png)

Select the appropriate verse and start typing. As you type, lyrics will be added instantly onto the score (overwriting existing lyrics). After you finish, click 'Done'.

Clicking 'Revert' will discard changes to the score and close the dialog.

For advanced usage, see the [original repo](https://github.com/bakajikara/MuseScoreLyricsJP).

## Known Issues

- Translation does not work for some reason, so all users will see English as the UI language.

## Changes compared to bakajikara/MuseScoreLyricsJP

- Made to work with MuseScore 4.4, with consistent UI styling.
- Translate the default language of UI into English. Chinese and Japanese are available as localization.
- Lyrics assignment skips tied notes by default.
- Add symbol `%` which skips over a note.
