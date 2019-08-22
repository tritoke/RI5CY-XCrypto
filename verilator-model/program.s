.text

_start:
    xc.init
    xc.ld.liu c0, 0xADDE
    xc.ld.hiu c0, 0xEFBE
    xc.init
    xc.ld.liu c0, 0xADDE
    xc.ld.hiu c0, 0xEFBE
;   xc.st.w c0, 0x200(x0)
;   xc.ld.w c1, 0x200(x0)
