#!/bin/bash
# Install or remove the mouse-click fix in a Wizards & Warriors (GOG) install directory.
#
#   ./install.sh "/path/to/Wizards and Warriors"            install
#   ./install.sh --uninstall "/path/to/Wizards and Warriors" restore the original binkw32.dll
#
# Uses build/binkw32.dll if you built it, otherwise prebuilt/binkw32.dll.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

uninstall=0
if [[ ${1:-} == --uninstall ]]; then uninstall=1; shift; fi
game=${1:?usage: install.sh [--uninstall] <game directory containing deep6.exe>}
[[ -f $game/deep6.exe ]] || { echo "error: $game/deep6.exe not found" >&2; exit 1; }

if (( uninstall )); then
    [[ -f $game/binkw32_orig.dll ]] || { echo "nothing to uninstall (no binkw32_orig.dll)"; exit 0; }
    mv -f "$game/binkw32_orig.dll" "$game/binkw32.dll"
    echo "restored original binkw32.dll"
    exit 0
fi

shim=$here/build/binkw32.dll
[[ -f $shim ]] || shim=$here/prebuilt/binkw32.dll

if [[ -f $game/binkw32_orig.dll ]]; then
    # Already installed once; a GOG repair/update may have put the original back as binkw32.dll.
    if ! cmp -s "$game/binkw32.dll" "$shim" && (( $(stat -c %s "$game/binkw32.dll") > 100000 )); then
        mv -f "$game/binkw32.dll" "$game/binkw32_orig.dll"
        echo "binkw32.dll was restored by the launcher; moved it back to binkw32_orig.dll"
    fi
else
    mv "$game/binkw32.dll" "$game/binkw32_orig.dll"
    echo "renamed original binkw32.dll -> binkw32_orig.dll"
fi
cp "$shim" "$game/binkw32.dll"
echo "installed $(basename "$(dirname "$shim")")/binkw32.dll -> $game/binkw32.dll"
