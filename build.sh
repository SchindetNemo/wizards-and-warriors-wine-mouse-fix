#!/bin/bash
# Build build/binkw32.dll from src/ using clang + lld-link + llvm-dlltool (no MinGW needed).
#
# src/binkw32.def forwards the 80 exports of the GOG binkw32.dll to binkw32_orig.dll.
# To regenerate it from an original binkw32.dll:  ./build.sh --regen-def /path/to/binkw32.dll
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build

if [[ ${1:-} == --regen-def ]]; then
    orig=${2:?path to the original binkw32.dll}
    {
        echo "LIBRARY binkw32.dll"
        echo "EXPORTS"
        objdump -p "$orig" | sed -n '/\[Ordinal\/Name Pointer\] Table/,/^$/p' |
            sed -nE 's/^\s+\[ *[0-9]+\] \+base\[ *([0-9]+)\] +[0-9a-f]+ (\S+)$/    \2=binkw32_orig.\2 @\1/p'
    } > src/binkw32.def
    echo "regenerated src/binkw32.def ($(grep -c binkw32_orig src/binkw32.def) exports)"
fi

cat > build/kernel32.def <<'EOF'
LIBRARY kernel32.dll
EXPORTS
    LoadLibraryA@4
    GetProcAddress@8
    VirtualProtect@16
    FlushInstructionCache@12
EOF
llvm-dlltool -m i386 -k -d build/kernel32.def -l build/kernel32.lib

clang -target i686-pc-windows-msvc -O2 -ffreestanding -fno-builtin -fno-stack-protector \
    -c src/shim.c -o build/shim.obj
lld-link /dll /machine:x86 /nodefaultlib /entry:DllMain /safeseh:no \
    /def:src/binkw32.def /out:build/binkw32.dll build/shim.obj build/kernel32.lib
echo "built $(pwd)/build/binkw32.dll"
