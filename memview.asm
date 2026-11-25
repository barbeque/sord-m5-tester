#define RAM_BASE $7000
#define ROM_START $2000
#define ROM_END $5fff ; for "16K" ROMs (8 + 8)

#define TEST_LENGTH $fff ; only testing 8K of RAM

#include "vdp_macros.asm"

#target rom
#data DATA, RAM_BASE, *
#code rom, $2000, *

; header values, read by BIOS
.db $00 ; unsure purpose (# of banks?)
.dw reset ; reset vector
.dw startup ; start vector

startup:
    im 1
    jr init

; TODO: reset, etc vectors?
reset:
    jr init

    ; The VDP gets reset at system startup, but it takes a lot
    ; longer than the CPU to be ready for action. We could do a
    ; bunch of setup stuff here, but instead we'll just spin until
    ; we think the VDP should be willing to listen to us.

    ; copied from the SG-1000: unsure if the Sord M5's monitor ROM takes care of this
BusyWait:
    ld d, $3 ; girls garden used $2 x $ffff
_busywait_outer:
    ld hl, $ffff
_busywait_inner:
    dec hl
    ld a,h
    or l
    jr nz, _busywait_inner
    dec d
    jr nz, _busywait_outer
    ret

init:
    call MutePSG ; we know for sure we are getting to here
    ;call BusyWait

_really_ready_now:

    di

    ; We may have to modify a bunch of this stuff
    ; if the M5 is in a weird configuration when it
    ; comes out of the BIOS. It seems to, at the very least,
    ; modify tiles.
    call ScreenInit
    call ClearVRAM
    call DefineFont
    call InitFontPalette

    ld b, 0
    ld c, 0
    ld hl, STR_BANNER
    call print_string

test_end_of_cart:
    ; Grab the value from the end of the cartridge and let's see
    ; what is there
    ld a, (ROM_END)
    ld h, 0
    ld l, a
    ld b, 1
    ld c, 1
    call get_hex_digit

done_testing:
busy_loop:
    jr busy_loop

get_hex_digit:
    ; arguments:
    ;   A - nibble (4-bit value, but we'll use the whole byte)
    and $f ; n & 0xf
    ld b, a
    cp a, 10
    jr c, _get_hex_digit_less_than_ten
; greater than or equal to ten
    ld a, $21 - 10 ; position of ascii 'A' in our font
    jr _get_hex_digit_finish
_get_hex_digit_less_than_ten:
    ld a, $10 ; position of ascii '0' in our font
    jr _get_hex_digit_finish
_get_hex_digit_finish:
    ;sub 10
    add b
    ret 

#include "psg.asm" ; MutePSG

print_hex:
    ; arguments:
    ;   B - X
    ;   C - Y
    ;   HL - value
    push hl
    calculate_write_address_from_xy
    call SetVDPWriteAddress
    pop hl

    ; print the $ first, of course
    ld a, $04
    out (VDP_DATA), a
#local
_print_hex_inner:
    ; thanks to https://chilliant.com/z80shift.html
    ld de, hl
    ; first digit: shift right 12
    srl h
    srl h
    srl h
    srl h
    ld l, h
    ld h, 0
    ld a, l
    call get_hex_digit
    out (VDP_DATA), a
    ld hl, de ; restore saved value
    ; second digit: shift right 8
    ld l, h
    ld h, 0
    ld a, l
    call get_hex_digit
    out (VDP_DATA), a
    ld hl, de
    ; third digit: shift right 4
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l
    ld a, l
    call get_hex_digit
    out (VDP_DATA), a
    ; fourth digit: the remainder
    ld hl, de
    ld a, l
    call get_hex_digit
    out (VDP_DATA), a
#endlocal
    ret

print_string:
    ; arguments:
    ;   B - X
    ;   C - Y
    ;   HL - pointer to null-terminated ASCII string
    push hl
    calculate_write_address_from_xy
    call SetVDPWriteAddress
    pop hl
#local
_print_string_inner:
    ld a, (hl)
    sub $20 ; our letter tiles start at 0, but that one is space (ascii 20)
    out (VDP_DATA), a
    nop_fudge ; FIXME: OPTIM: not sure if we have to nop here, since our loop is so slow

    inc hl
    ld a, (hl)
    cp a, 0
    ; is next character null?
    jr nz, _print_string_inner
#endlocal
    ret

STR_BANNER: .asciz "Hello Sord!"

#include "vdp.asm"
#include "font_8x8.asm"

.org ROM_END ; force the resulting file to be 16K
.db $ff