# System Software: assembler, linker and emulator

[![build-and-test](https://github.com/djokerg/System-Software/actions/workflows/ci.yml/badge.svg)](https://github.com/djokerg/System-Software/actions/workflows/ci.yml)

A complete toolchain for a small 32-bit processor, written from scratch in C++:

- a **two-pass assembler** (flex + bison front end) that produces relocatable object files,
- a **linker** that merges sections, places them at fixed addresses and resolves relocations,
- an **emulator** that loads the linked image into a 4 GB address space and runs it, with
  interrupts and a memory-mapped terminal.

Built as the semester project for **System Software** at the School of Electrical Engineering,
University of Belgrade (2023).

```
 main.s ─┐                         ┌─ main.o ─┐
 math.s ─┼─▶ assembler (per file) ─┼─ math.o ─┼─▶ linker ─▶ program.hex ─▶ emulator
  isr.s ─┘                         └─  isr.o ─┘   -place=…
```

## Quick start

You only need Docker. The first run builds a small image with g++, flex and bison.

```sh
git clone https://github.com/djokerg/System-Software.git && cd System-Software
./run.sh                # hello: prints "Hello world" from an interrupt routine
./run.sh level-a        # interrupts + calls into a separately linked math library
./run.sh level-b        # terminal interrupts: press "y" 20 times
./run.sh test           # run all examples headless, prints PASS/FAIL
```

Each run leaves every intermediate file in `build/<example>/`: the object files, a readable
dump of each one (`*_txt.o`), the linked `program.hex` and its dump, and the emulator's memory dump.

<details>
<summary>Building without Docker</summary>

Requires g++, make, flex and **bison 3.x** (macOS ships bison 2.3; use `brew install bison`).

```sh
make all                       # builds ./assembler ./linker ./emulator
make run EXAMPLE=level-a
make test
```
</details>

## Example: what each stage produces

`examples/hello/main.s` loads a constant, then calls an interrupt routine defined in another file:

```asm
.extern isr_terminal
.section my_code
my_start:
    ld $7, %r1
    ld %r1, %r2
    call isr_terminal
    halt
.end
```

**Assembler** (`assembler -o main.o main.s`) writes `main.o` plus a readable `main_txt.o`.
`isr_terminal` is unknown here, so it gets a relocation. The constant `7` and the address of
`isr_terminal` live in a *literal pool* placed after the code:

```
#.symtab
Id  Value  TYPE    Bind  Ndx  Name
0:  0000   SCTN    LOC   0    UND
1:  0000   NOTYPE  GLOB  0    isr_terminal
2:  0000   SCTN    LOC   1    my_code
3:  0000   NOTYPE  LOC   1    my_start
#.reloc.my_code
Offset  Type    Symbol        Addend
0014    R_TYPE  isr_terminal  0000
Section my_code:
0000: 0c 00 1f 92 00 00 21 91     ld [pc+0x0c], r1   ;  r2 = r1
0008: 08 00 f0 21 00 00 00 00     call [pc+0x08]     ;  halt
0010: 07 00 00 00 00 00 00 00     literal pool: 7, &isr_terminal (to be patched)
```

**Linker** (`linker -hex -place=my_code@0x40000000 -place=isr@0x50000000 -o program.hex main.o isr_terminal.o`)
places both sections and patches the pool entry with the final address `0x50000000`:

```
#.output_sections
Address   Size  Ndx  Name
50000000  0084  2    isr
40000000  0018  1    my_code
```

**Emulator** (`emulator program.hex`) runs from `0x40000000` until `halt`:

```
Hello world
-----------------------------------------------------------------
Emulated processor executed halt instruction
Emulated processor state:
	r0:0x00000000	r1:0x00000007	r2:0x00000007	r3:0x00000000
	...
	r12:0x00000000	r13:0x00000000	r14:0xffffff00	r15:0x40000010
```

## The processor

| | |
|---|---|
| Word size | 32-bit, little-endian, byte-addressable, 4 GB address space |
| General registers | `r0`–`r15`; `r14` = `sp`, `r15` = `pc` |
| Control registers | `status`, `handler` (interrupt routine address), `cause` |
| Start address | `0x40000000`; `sp` starts at `0xFFFFFF00`, the stack grows down |
| Memory-mapped I/O | `term_out` `0xFFFFFF00`, `term_in` `0xFFFFFF04`, `tim_cfg` `0xFFFFFF10` |
| Interrupt causes | 1 = illegal instruction, 2 = timer, 3 = terminal, 4 = software (`int`) |

On an interrupt the CPU pushes `status` and `pc`, writes `cause`, masks interrupts and jumps to
`handler`. `iret` pops both back.

Every instruction is 4 bytes:

```
 31     28 27   24 23   20 19   16 15   12 11              0
┌────────┬───────┬───────┬───────┬───────┬─────────────────┐
│   OC   │  MOD  │   A   │   B   │   C   │  D (signed 12)  │
└────────┴───────┴───────┴───────┴───────┴─────────────────┘
```

### Instruction set

| Group | Instructions |
|---|---|
| Control | `halt`, `int`, `iret`, `call op`, `ret` |
| Jumps | `jmp op`, `beq %rA, %rB, op`, `bne %rA, %rB, op`, `bgt %rA, %rB, op` |
| Stack | `push %r`, `pop %r` |
| Arithmetic | `add`, `sub`, `mul`, `div` with two registers, `%src, %dst` |
| Logic | `not %r`, `and`, `or`, `xor`, `shl`, `shr` |
| Memory | `ld op, %r`, `st %r, op`, `xchg %rA, %rB` |
| Control registers | `csrrd %csr, %r`, `csrwr %r, %csr` |

Operand forms for `ld` / `st`:

| Syntax | Meaning |
|---|---|
| `$5`, `$label` | the value itself (immediate) |
| `5`, `label` | memory at that address |
| `%r1` | register |
| `[%r1]` | memory at the address in `r1` |
| `[%r1 + 8]` | memory at `r1 + 8` (12-bit signed offset) |

### Assembler directives

`.global`, `.extern`, `.section name`, `.word value|symbol, ...`, `.skip n`, `.ascii "text"`,
`.end`. Comments start with `#`.

## How it works

### Assembler: two passes and literal pools

Instructions only have a 12-bit displacement, so a 32-bit constant or address can't be encoded
inline. Instead the **first pass** builds the symbol table, section sizes and a per-section
**literal pool** of every constant and symbol the section uses, deduplicated. The **second pass**
emits code, turning each `ld $value` into a `pc`-relative load from the pool. Relocations are only
ever needed for pool entries, never inside instructions, which keeps the linker simple.

The grammar is in [`misc/parser.y`](misc/parser.y) and the tokens in [`misc/lexer.l`](misc/lexer.l).
Code generation is in [`src/assembler.cpp`](src/assembler.cpp).

### Linker

[`src/linker.cpp`](src/linker.cpp):

1. Reads each object file's symbol, section and relocation tables.
2. Merges sections with the same name from different files, in command-line order.
3. Places sections named in `-place=section@address`; the rest follow after the highest placed one.
4. Checks that no two sections overlap.
5. Merges symbol tables, reporting undefined or multiply defined global symbols.
6. With `-hex`, patches every relocation with the final address and writes a loadable image. With
   `-relocatable`, it writes a new combined object file instead, which can itself be linked again.

### Emulator

[`src/emulator.cpp`](src/emulator.cpp) reserves the full 4 GB address space with
`mmap(MAP_NORESERVE)`, so memory is only allocated for pages the program touches. It copies each
segment of `program.hex` to its address, then runs a fetch–decode–execute loop. After every
instruction it checks the keyboard (the terminal is put into raw, non-blocking mode). A key press
is written to `term_in` and raises a terminal interrupt. Stores to `term_out` print a character.

## Examples

| Example | What it shows |
|---|---|
| [`hello`](examples/hello) | Literal pool, `call` across files, printing through `term_out` |
| [`level-a`](examples/level-a) | Software interrupt and handler dispatch on `cause`, calls into a `math` section placed at `0xF0000000`, passing arguments on the stack. Ends with `r1=0xABCD`, `r2..r6 = 2..6` |
| [`level-b`](examples/level-b) | Terminal interrupts: every `y` you type prints `press`; the program halts after 20 |

`level-a` and `level-b` are the public tests from the course.

## Command-line reference

```sh
assembler -o out.o in.s
linker -hex [-place=<section>@<address> ...] -o program.hex in1.o in2.o ...
linker -relocatable -o combined.o in1.o in2.o ...
emulator program.hex
```

## Project layout

```
misc/      lexer.l (flex) and parser.y (bison)
src/       assembler, linker and emulator implementation + their main_*.cpp
inc/       headers
examples/  example programs
scripts/   run-example.sh (assemble, link, emulate), run-tests.sh (CI)
```

## Limitations

- The timer is not implemented: `tim_cfg` can be written but no timer interrupts are generated.
- The emulator needs a real terminal for input. Piped stdin is not supported; the test
  script provides a pseudo-terminal through `script`.

## Credits

Processor specification, the assembly syntax and the `level-a`/`level-b` test programs come from
the System Software course, School of Electrical Engineering, University of Belgrade.
The toolchain implementation is my own work.
