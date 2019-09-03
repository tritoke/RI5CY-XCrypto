# test_sparx.elf
# xc.bop
# xc.ld.hu
# xc.padd
# xc.prot.i
# xc.st.h

.text

_start:
    # clear registers
    xc.init
    xc.ld.liu c0, 0x3412
    xc.ld.hiu c0, 0x7856

    # store value in memory
    xc.st.h c0, (0), 0x200(x0)
    xc.st.h c0, (1), 0x202(x0)

    # load value back from memory
    xc.ld.hu c1, (0), 0x200(x0)
    xc.ld.hu c1, (1), 0x202(x0)

    # c1 == c0

    # c2 = c1 OR c0
    xc.bop c2, c1, c0, 0b11101110

    # c2 == c1 == c0

    # c2 = c1 XOR c1
    xc.bop c2, c1, c1, 0b01100110

    # c2 == 0

    



    li t0, 0x100
    li t1, 0x100
    xc.ldr.w c3, t0, t1

    # c3 == 0x12345678

    xc.ld.liu  c4, 0x3412
    xc.xcr2gpr a0, c4
    add a1, a0, x0
    xc.gpr2xcr c5, a1
    xc.gpr2xcr c6, a0

    # a1 == 0x00001234





    xc.prot.i w, c1, c1, 16
    xc.prot.i h, c1, c1, 8
    xc.prot.i b, c1, c1, 4

    # c1 == 0x87654321

    xc.padd b, c2, c1, c0

    # c2 == 0x99999999

    xc.padd c, c2, c1, c0

    # c2 == 0x95599559
