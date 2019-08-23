.text

_start:
    xc.ld.liu c0, 0xADDE
    xc.ld.hiu c0, 0xEFBE
    xc.st.w c0, 0x200(x0)
    xc.ld.w c1, 0x200(x0)
    xc.ld.liu c2, 0xFFFF
    xc.st.h c2, (0), 0x200(x0)
    xc.ld.hu c3, (1), 0x200(x0)
