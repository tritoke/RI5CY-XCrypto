.text

_start:
    # overflowing packed add of 4 bytes
    # c2 == 0xFFFFFFFF
    xc.init
    xc.ld.liu c0, 0xFFFF
    xc.ld.hiu c0, 0xFFFF
    xc.ld.liu c1, 0xFFFF
    xc.ld.hiu c1, 0xFFFF
    xc.padd b, c2, c1, c0

    # packed add of 4 bytes
    # c2 == 0xF00F0FF0
    xc.init
    xc.ld.liu c0, 0xF00F
    xc.ld.hiu c1, 0x0FF0
    xc.padd b, c2, c1, c0

    # packed add of 8 nibbles 
    # c2 == 0x99999999
    xc.init
    xc.ld.liu c0, 0x1234
    xc.ld.hiu c0, 0x5678
    xc.ld.liu c1, 0x8765
    xc.ld.hiu c1, 0x4321
    xc.padd n, c2, c1, c0
