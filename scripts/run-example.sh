#!/usr/bin/env bash
# Assemble, link and emulate one of the programs in examples/.
#
#   scripts/run-example.sh hello|level-a|level-b
#
# Intermediate files (objects, their readable *_txt.o dumps, program.hex,
# mem_dump.txt) end up in build/<example>/ so you can inspect every stage.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:?usage: $0 <example>}"
SRC="$ROOT/examples/$NAME"
OUT="$ROOT/build/$NAME"

case "$NAME" in
    hello)
        SOURCES="main isr_terminal"
        PLACE="-place=my_code@0x40000000 -place=isr@0x50000000"
        ;;
    level-a)
        SOURCES="handler math main isr_terminal isr_timer isr_software"
        PLACE="-place=my_code@0x40000000 -place=math@0xF0000000"
        ;;
    level-b)
        SOURCES="main isr_terminal isr_timer handler"
        PLACE="-place=my_code@0x40000000"
        ;;
    *)
        echo "Unknown example '$NAME' (hello, level-a, level-b)" >&2
        exit 1
        ;;
esac

make -s -C "$ROOT" all
mkdir -p "$OUT"
cd "$OUT"

OBJECTS=""
for s in $SOURCES; do
    "$ROOT/assembler" -o "$s.o" "$SRC/$s.s"
    OBJECTS="$OBJECTS $s.o"
done

"$ROOT/linker" -hex $PLACE -o program.hex $OBJECTS

exec "$ROOT/emulator" program.hex
