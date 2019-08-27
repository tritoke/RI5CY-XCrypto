.text

_start:
    xc.ld.liu c0, 0xADDE
    xc.ld.hiu c0, 0xEFBE
    xc.st.w c0, 0x200(x0)
    xc.ld.w c1, 0x200(x0)
    xc.ld.liu c2, 0xFFFF
    xc.st.h c2, (0), 0x204(x0)
    xc.ld.hu c2, (1), 0x204(x0)
    xc.init
    xc.ld.w c0, 0x200(x0)
    xc.ld.bu c0, (0), 0, 0x200(x0)
    xc.ld.bu c0, (0), 1, 0x201(x0)
    xc.ld.bu c0, (1), 0, 0x202(x0)
    xc.ld.bu c0, (1), 1, 0x203(x0)
