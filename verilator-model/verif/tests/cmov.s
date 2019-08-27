.text

_start:
    xc.init 
    xc.ld.liu c0, 0xADDE
    xc.ld.hiu c0, 0xEFBE
    xc.cmov.t c1, c0, c15
    xc.cmov.f c2, c0, c15
