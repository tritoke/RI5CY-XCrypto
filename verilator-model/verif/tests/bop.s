.text

_start:
    # c0 AND c1 -> c2
    # c2 == 0x0000FFFF
    xc.init
    xc.ld.liu c0, 0xFFFF
    xc.ld.hiu c0, 0xFFFF
    xc.ld.liu c1, 0xFFFF
    xc.bop c2, c1, c0, 0b10001000

    # c0 OR c1 -> c2
    # c2 == 0xFFFFFFFF
    xc.init
    xc.ld.liu c0, 0xFFFF
    xc.ld.hiu c1, 0xFFFF
    xc.bop c2, c1, c0, 0b11101110

    # c0 XOR c1 -> c2
    # c2 == 0x0000FFFF
    xc.init
    xc.ld.liu c0, 0xFFFF
    xc.ld.hiu c0, 0xFFFF
    xc.ld.hiu c1, 0xFFFF
    xc.bop c2, c1, c0, 0b01100110
