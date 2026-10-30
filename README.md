# Stash Toolkit

A single-file PowerShell/WinForms GUI for managing a self-hosted
[Stash](https://github.com/stashapp/stash) media library -- browsing,
finding gaps, exporting reports, and a few extras -- without juggling a pile
of separate scripts.

Everything lives in one portable `.ps1` file: no installer, no external
modules, nothing to unzip. Copy it anywhere and run it.

## Features

**Scenes** -- browse every scene with its screenshot, file details and
performers. Find scenes by performer, studio or tag, see recent additions,
and spot possible duplicates.

**Performers** -- search by name, alias, country or tag. Find profiles
missing pictures and compare possible duplicates side by side.

**Groups and studios** -- explore groups with their front and back covers
and linked scenes. Browse studios and see which performers appear for each
one.

**Images** -- pick a celebrity to see their pictures, save favourites, make
a collage, or run a slideshow in order or at random.

**Extras** -- create scene posters, performer collages, contact sheets and
timelines, export playlists, pick a random scene, or play the library quiz.

**Utilities** -- search scenes by several tags at once, see where your disk
space is going, export performer/studio pictures, export a Library
Checklist (Studios, Movie Scenes, Full Movies and Stars, each with a
"Have ?" column, as an Excel workbook), find single-file folders, check
your dependencies (FFmpeg, WebView2, Stash), and back up your settings.

A shared connection bar (Stash URL, API key, Connect, Open Stash, Stop
Stash, and an SFW/NSFW switch) sits above the tabs, since most of the tool
talks to Stash's GraphQL API.

## Requirements

- Windows (uses WinForms/.NET)
- PowerShell -- Windows PowerShell 5.1 (built in) or PowerShell 7; the
  toolkit relaunches itself under PowerShell 7 automatically if it's
  installed
- A running [Stash](https://github.com/stashapp/stash) server and its API
  key
- Optional: [FFmpeg](https://ffmpeg.org/) on your `PATH` (or next to your
  Stash executable) for contact sheets and some thumbnail features --
  the in-app Dependency Checker (Utilities tab) reports whether it can find
  it
- WebView2 is bundled inside the script and extracted automatically if it's
  not already installed

## Getting started

1. Download `Stash-Toolkit.ps1`.
2. Run it (right-click -> **Run with PowerShell**, or `./Stash-Toolkit.ps1`
   from a PowerShell prompt).
3. Enter your Stash URL and API key in the connection bar at the top and
   press **Start & Connect**.

The first run shows a few default folder paths (export locations, movie
library folders) that belong to the original author -- change them under
the relevant Utilities page (or in Settings) to match your own setup.

## Building a .exe (optional)

Run `Build-Exe.ps1` from the same folder as the script to produce
`Stash-Toolkit.exe` -- a double-clickable launcher with no console window,
instead of right-click -> Run with PowerShell and an execution-policy
prompt. It uses nothing but PowerShell's own built-in compiler -- no
module to install, no internet access needed. If you run it under
PowerShell 7, it automatically relaunches itself under Windows PowerShell
5.1 to do the actual build (that's the compiler that can produce a
stand-alone exe this way), so you don't need to do anything differently
either way.

The exe doesn't contain the script -- `Stash-Toolkit.ps1` is several
megabytes (mostly a bundled WebView2 component), too large for tools like
[ps2exe](https://github.com/MScholtes/PS2EXE) to embed reliably. The exe is
just a shortcut that starts `Stash-Toolkit.ps1`, which must stay in the
same folder as it.

If `stash-toolkit-icon.ico` or `stash-toolkit-icon.png` is next to
`Build-Exe.ps1` when you run it, the exe gets that as its icon
automatically (a `.png` is converted to `.ico` on the fly). No icon file
there, it just builds without a custom one. Pass `-IconPath` to use a
different image.

## Settings

Connection details and remembered folders are saved to
`%LocalAppData%\StashToolkit\settings.json` and reloaded on the next
launch. This file lives outside the script/repo folder, so it's never
committed to git, but it does contain your Stash API key -- keep that in
mind if you ever share that folder.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Credits

Built with help from ChatGPT and Claude.

With thanks to [Stash](https://stashapp.cc/), [FFmpeg](https://ffmpeg.org/),
[Microsoft PowerShell](https://learn.microsoft.com/powershell/) and the
open-source community.

## License

[MIT](LICENSE)
