# MemoRadar

*[Leia em português](README.md)*

A macOS menu bar app that shows what is using your memory, built for **Claude Code** users: which projects are open, how long Claude has been idle in each one and how many copies of each MCP server are running.

Activity Monitor lists dozens of `Code Helper` processes without saying which project they belong to. MemoRadar answers in seconds: **what is using memory, what was forgotten and what you can close**.

> Independent project, not affiliated with Anthropic or Microsoft.

The app's interface is currently in Brazilian Portuguese.

## What it shows

- **Memory and pressure:** percentage used and the pressure level reported by macOS.
- **App ranking:** from the biggest to the smallest, adding up every process of each app.
- **VS Code projects:** memory, number of Claude sessions, time open and time idle.
- **Claude Code in the terminal:** sessions by folder.
- **Open MCP servers:** how many copies of each server, how much they use and which session they belong to.
- **Unused Skills:** by plugin, how many Skills have no recorded use and the command to disable them. Skills do not use RAM, but they take up context in every session. The app only shows this: you are the one who disables them.

## What counts as forgotten

A project looks forgotten when **all** Claude sessions in that folder have been idle for at least 4 hours. You can change this limit in the settings.

When that happens, MemoRadar sends a notification, highlights the project in the panel and turns the icon yellow. The icon turns red if memory pressure becomes critical.

## Closing from the app

Nothing closes without confirmation. If Claude is working, or if the session state is unknown, the warning is stronger.

| What you close | What the app does |
|---|---|
| Regular app | Asks it to quit normally, and the app may ask you to save |
| VS Code window | Presses the window's close button, so the unsaved file prompt is still VS Code's own |
| Terminal session | Sends `SIGTERM` |
| MCP server | Sends `SIGTERM`. It comes back in new sessions if it is still configured |

System processes, development servers, Docker and the like are listed but have no close button.

## Installation

1. Download the latest `.dmg` from the [Releases](https://github.com/marcoswgallo/memoradar/releases) page.
2. Open it and drag **MemoRadar** to your **Applications** folder.
3. The first time, macOS warns that it cannot verify the developer, because this free app does not go through Apple's paid notarization. Go to **System Settings > Privacy & Security**, scroll to the message about MemoRadar and click **Open Anyway**.

Requires macOS 14 or later.

## Permissions

- **Accessibility (optional):** only to read VS Code window titles and press the close button. Everything else works without it. You may need to grant it again after updating the app.
- **Notifications (optional):** the official macOS API refuses apps without a paid Apple certificate, so the alert is sent through AppleScript. It shows the name and icon of **Script Editor**, with a title starting with "MemoRadar:", and clicking it may open that program. If it does not appear, allow Script Editor notifications in System Settings > Notifications. The panel highlight and the icon color work without it.

## Privacy

MemoRadar **makes no network connections**. There is no account, telemetry or automatic update.

**What it reads:**

- Information about your processes, through macOS APIs.
- The `~/.claude/sessions/<pid>.json` files, which hold each session's state.
- For the Skills section, when the panel opens: the `skillUsage` field of `~/.claude.json`, the `enabledPlugins` field of `~/.claude/settings.json`, the plugin list in `~/.claude/plugins/installed_plugins.json` and the names of Skill folders. The app has to open these whole files to find the fields, and the rest is discarded without being stored or shown.

**What it never reads:** your conversations (`~/.claude/projects`), session `.key` files and the content of Skills. The app also never changes any of these files.

## Limitations

- Session state comes from internal Claude Code files, which may change in an update. If they do, the app shows "estado desconhecido" (unknown state) instead of guessing, and uses the strong warning.
- The Skill usage record belongs to Claude Code and is not an exact count, so the app says "sem uso registrado" (no recorded use). The count leaves out project Skills and other sources.
- macOS does not report the usage of other users' processes without administrator privileges, such as WindowServer, and the app does not ask for them. So it shows the memory reserved by the system as a single number.
- The memory of the window itself cannot always be tied to a project, and goes to "VS Code (geral)" (general). The estimate shown when closing a window may be lower than the real amount.
- Windows without a Claude session appear unnamed and cannot be closed from the app, because they cannot be identified safely.
- VS Code windows in another Space may not be found. In that case, nothing is closed.

## Building

Only the Command Line Tools are needed, not Xcode:

```bash
scripts/test.sh          # runs the tests
scripts/package-app.sh   # builds dist/MemoRadar.app
scripts/package-dmg.sh   # builds the .dmg in dist/
```

Without Xcode, the `@State` macro plugin is not available, so interface state lives in `@Observable` objects. `scripts/test.sh` also works around an intermittent failure of the testing plugin in the Command Line Tools.

## License

[MIT](LICENSE)
