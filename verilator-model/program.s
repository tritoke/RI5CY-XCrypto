.text

_start:
    xc.ld.liu c0, 0xADDE
    xc.ld.hiu c0, 0xEFBE

    xc.ld.liu c1, 0x0400
    xc.ld.hiu c1, 0x0C08

    li t0, 0x200

    xc.scatter.b c0, c1, t0

    xc.ld.bu c1, (0), 0, 0x0(t0)
    xc.ld.bu c1, (0), 1, 0x4(t0)
    xc.ld.bu c1, (1), 0, 0x8(t0)
    xc.ld.bu c1, (1), 1, 0xC(t0)
