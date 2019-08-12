// SCARV Project
//
// University of Bristol
//
// RISC-V Cryptographic Instruction Set Extension
//
// Reference Implementation
//
//

#define SCARV_COP_INSN_SUCCESS          0
#define SCARV_COP_INSN_ABORT            1
#define SCARV_COP_INSN_BAD_INS          2
#define SCARV_COP_INSN_BAD_LAD          3
#define SCARV_COP_INSN_BAD_SAD          4
#define SCARV_COP_INSN_LD_ERR           5
#define SCARV_COP_INSN_ST_ERR           6

#define SCARV_COP_ICLASS_PACKED_ARITH   0
#define SCARV_COP_ICLASS_PERMUTE        1
#define SCARV_COP_ICLASS_LOADSTORE      2
#define SCARV_COP_ICLASS_RANDOM         3
#define SCARV_COP_ICLASS_MOVE           4
#define SCARV_COP_ICLASS_MP             5
#define SCARV_COP_ICLASS_BITWISE        6
#define SCARV_COP_ICLASS_AES            7
#define SCARV_COP_ICLASS_SHA3           8

#define SCARV_COP_SCLASS_SHA3_XY        0
#define SCARV_COP_SCLASS_SHA3_X1        1
#define SCARV_COP_SCLASS_SHA3_X2        2
#define SCARV_COP_SCLASS_SHA3_X4        3
#define SCARV_COP_SCLASS_SHA3_YX        4
   
#define SCARV_COP_SCLASS_CMOV_T         0
#define SCARV_COP_SCLASS_CMOV_F         1
#define SCARV_COP_SCLASS_GPR2XCR        2
#define SCARV_COP_SCLASS_XCR2GPR        3

#define SCARV_COP_SCLASS_PERM_BIT       0
#define SCARV_COP_SCLASS_PERM_IBIT      1
#define SCARV_COP_SCLASS_PERM_BYTE      2
   
#define SCARV_COP_SCLASS_SCATTER_B      0
#define SCARV_COP_SCLASS_GATHER_B       1
#define SCARV_COP_SCLASS_SCATTER_H      2
#define SCARV_COP_SCLASS_GATHER_H       3
#define SCARV_COP_SCLASS_ST_W           4
#define SCARV_COP_SCLASS_LD_W           5
#define SCARV_COP_SCLASS_ST_H           6
#define SCARV_COP_SCLASS_LH_CR          7
#define SCARV_COP_SCLASS_ST_B           8
#define SCARV_COP_SCLASS_LB_CR          9
#define SCARV_COP_SCLASS_LDR_W          10
#define SCARV_COP_SCLASS_LDR_H          11
#define SCARV_COP_SCLASS_LDR_B          12
#define SCARV_COP_SCLASS_STR_W          13
#define SCARV_COP_SCLASS_STR_H          14
#define SCARV_COP_SCLASS_STR_B          15
   
#define SCARV_COP_SCLASS_BMV            0
#define SCARV_COP_SCLASS_BOP            1
#define SCARV_COP_SCLASS_INS            2
#define SCARV_COP_SCLASS_EXT            3
#define SCARV_COP_SCLASS_LD_LIU         4
#define SCARV_COP_SCLASS_LD_HIU         5
#define SCARV_COP_SCLASS_LUT            6

#define SCARV_COP_SCLASS_PADD           0
#define SCARV_COP_SCLASS_PSUB           1
#define SCARV_COP_SCLASS_PMUL_L         2
#define SCARV_COP_SCLASS_PMUL_H         3
#define SCARV_COP_SCLASS_PCLMUL_L       4
#define SCARV_COP_SCLASS_PCLMUL_H       5
#define SCARV_COP_SCLASS_PSLL           6
#define SCARV_COP_SCLASS_PSRL           7
#define SCARV_COP_SCLASS_PROT           8
#define SCARV_COP_SCLASS_PSLL_I         9
#define SCARV_COP_SCLASS_PSRL_I         10
#define SCARV_COP_SCLASS_PROT_I         11

#define SCARV_COP_SCLASS_MEQU           0
#define SCARV_COP_SCLASS_MLTE           1
#define SCARV_COP_SCLASS_MGTE           2
#define SCARV_COP_SCLASS_MADD_3         3
#define SCARV_COP_SCLASS_MADD_2         4
#define SCARV_COP_SCLASS_MSUB_3         5
#define SCARV_COP_SCLASS_MSUB_2         6
#define SCARV_COP_SCLASS_MSLL_I         7
#define SCARV_COP_SCLASS_MSLL           8
#define SCARV_COP_SCLASS_MSRL_I         9
#define SCARV_COP_SCLASS_MSRL           10
#define SCARV_COP_SCLASS_MACC_2         11
#define SCARV_COP_SCLASS_MACC_1         12
#define SCARV_COP_SCLASS_MMUL_3         13
#define SCARV_COP_SCLASS_MCLMUL_3       14

#define SCARV_COP_SCLASS_RSEED          0
#define SCARV_COP_SCLASS_RSAMP          1
#define SCARV_COP_SCLASS_RTEST          2

#define SCARV_COP_SCLASS_AESSUB_ENC     0
#define SCARV_COP_SCLASS_AESSUB_ENCROT  1
#define SCARV_COP_SCLASS_AESSUB_DEC     2
#define SCARV_COP_SCLASS_AESSUB_DECROT  3
#define SCARV_COP_SCLASS_AESMIX_ENC     4
#define SCARV_COP_SCLASS_AESMIX_DEC     5

#define SCARV_COP_RNG_TYPE_LFSR32       0

#define SCARV_COP_PW_1                  5
#define SCARV_COP_PW_2                  4
#define SCARV_COP_PW_4                  3
#define SCARV_COP_PW_8                  2
#define SCARV_COP_PW_16                 1
