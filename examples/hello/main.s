# file: main.s

.extern isr_terminal

.section my_code
my_start:
    ld $7, %r1
    ld %r1, %r2
    call isr_terminal
    halt

.end
