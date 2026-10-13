# Wizards & Warriors (GOG) – mouse click fix for Wine / Proton

On Linux (Wine, Proton, Heroic, Lutris, Steam), the GOG release of *Wizards & Warriors* (2000, Heuristic Park) shows its main menu and the game's hand cursor follows the mouse, but **clicks never do anything**. This fixes that.

## Cause

`deep6.exe` reads the mouse buttons by polling `GetAsyncKeyState(VK_LBUTTON)`. It counts a click only when the **least significant bit** is set. On Windows, that bit means "pressed since the last call". Wine only ever returns `0x8000` (button currently down) and never sets that bit, so the game sees the button held but never sees a click.

This has nothing to do with Wayland/XWayland, the window manager, the virtual desktop or the DirectDraw wrapper. All of those were tested and none of them change it.

Note: the main menu has no hover highlight and ignores the keyboard, even on Windows. That's normal.

## How the fix works

`binkw32.dll` (the Bink video library) ships with the game, and the game always loads it at startup. The fix replaces it with a small proxy:

- all 80 Bink exports are forwarded unchanged to the original, renamed to `binkw32_orig.dll`;
- on load, the proxy patches `user32!GetAsyncKeyState` with a wrapper around `win32u!NtUserGetAsyncKeyState`. The wrapper sets bit 0 the first time a key or button is polled after it goes down, which matches Windows behaviour.

No Wine/Proton build changes, no DLL overrides and no registry edits are needed. Wine loads a game's own DLLs from the game directory by default.

## Files

| File | Purpose |
|---|---|
| `src/shim.c` | The hook (DllMain + `GetAsyncKeyState` wrapper) |
| `src/binkw32.def` | Export forwarders to `binkw32_orig.dll` (same names and ordinals as the GOG `binkw32.dll`) |
| `build.sh` | Builds `build/binkw32.dll` with clang + lld-link + llvm-dlltool |
| `prebuilt/binkw32.dll` | Ready-made build of the above (32-bit, ~8 KB) |
| `install.sh` | Installs into or uninstalls from the game directory |

## Install

The game directory is the folder that contains `deep6.exe`.

```sh
./install.sh "/path/to/Wizards and Warriors"
```

Or install manually:

1. In the game directory, rename `binkw32.dll` to **`binkw32_orig.dll`**.
2. Copy `prebuilt/binkw32.dll` (or `build/binkw32.dll`) into the game directory as **`binkw32.dll`**.

The result should be:

```
Wizards and Warriors/
├── deep6.exe
├── binkw32.dll        <- this fix (~8 KB)
└── binkw32_orig.dll   <- original RAD Bink DLL (~261 KB)
```

**Uninstall:** `./install.sh --uninstall "/path/to/Wizards and Warriors"`, or delete `binkw32.dll` and rename `binkw32_orig.dll` back.

**After a GOG/Heroic "verify", "repair" or update**, the launcher puts the original `binkw32.dll` back and clicks stop working again. Run `install.sh` again. It detects this case and fixes it.

## Configuration

Nothing is required. Tested with **GE-Proton10-34** through Heroic (umu). Optional:

- **DirectDraw:** both Wine's built-in ddraw (`WINEDLLOVERRIDES=ddraw=b`) and the D3D9-based `ddraw.dll` wrapper that GOG ships (`ddraw=n,b`) work. The game renders at 640×480, and Wine scales it to the window.
- **Heroic:** game settings → Advanced → Environment variables, if you want to set the ddraw override above.

## Build

Requires `clang`, `lld` (`lld-link`) and `llvm-dlltool`. MinGW isn't needed.

```sh
./build.sh                                   # -> build/binkw32.dll
./build.sh --regen-def /path/to/binkw32.dll  # regenerate src/binkw32.def from an original DLL first
```

## Notes

- The original `binkw32.dll` (RAD Game Tools) isn't included. It comes from your own copy of the game.
- The hook is harmless on Windows (10+, where `win32u.dll` exists). It's only needed under Wine.

## License

[MIT](LICENSE). This covers only the files in this repository, not the game or RAD's `binkw32.dll`.
