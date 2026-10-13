# file: isr_terminal.s

.global isr_terminal
.section isr
isr_terminal:
    push %r1
    push %r2

    ld $message_start, %r1

    ld [%r1+0], %r2
    st %r2, 0xFFFFFF00 # term_out
    ld [%r1+1], %r2
    st %r2, 0xFFFFFF00 # term_out
    ld [%r1+2], %r2
    st %r2, 0xFFFFFF00 # term_out
    ld [%r1+3], %r2
    st %r2, 0xFFFFFF00 # term_out
    ld [%r1+4], %r2
    st %r2, 0xFFFFFF00 # term_out
    ld [%r1+5], %r2
    st %r2, 0xFFFFFF00 # term_out
    ld [%r1+6], %r2
    st %r2, 0xFFFFFF00 # term_out
    ld [%r1+7], %r2
    st %r2, 0xFFFFFF00 # term_out
    ld [%r1+8], %r2
    st %r2, 0xFFFFFF00 # term_out
    ld [%r1+9], %r2
    st %r2, 0xFFFFFF00 # term_out
    ld [%r1+10], %r2
    st %r2, 0xFFFFFF00 # term_out

    pop %r2
    pop %r1

    ret
message_start:
.ascii "Hello world"

.end
