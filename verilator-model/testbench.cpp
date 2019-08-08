// Copyright 2017 Embecosm Limited <www.embecosm.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Simple Verilator model test bench
// Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>
// Contributor Graham Markall <graham.markall@embecosm.com>

#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vtop.h"
#include "Vtop__Syms.h"

#include <iostream>
#include <cstdint>
#include <cstdlib>

using std::cout;
using std::cerr;
using std::endl;

// Count of clock ticks

static vluint64_t  cpuTime = 0;

// Debug registers

const uint16_t DBG_CTRL    = 0x0000;  //!< Debug control
const uint16_t DBG_HIT     = 0x0004;  //!< Debug hit
const uint16_t DBG_IE      = 0x0008;  //!< Debug interrupt enable
const uint16_t DBG_CAUSE   = 0x000c;  //!< Debug cause (why entered debug)
const uint16_t DBG_GPR0    = 0x0400;  //!< General purpose register 0
const uint16_t DBG_GPR31   = 0x047c;  //!< General purpose register 41
const uint16_t DBG_NPC     = 0x2000;  //!< Next PC
const uint16_t DBG_PPC     = 0x2004;  //!< Prev PC

// Debug register flags

const uint32_t DBG_CTRL_HALT = 0x00010000;    //!< Halt core
const uint32_t DBG_CTRL_SSTE = 0x00000001;    //!< Single step core

static uint64_t mCycleCnt = 0;

Vtop *cpu;
VerilatedVcdC * tfp;
bool passed = true;

void checkProperties(void) {
  #include "scarv_cop_common.h"
  auto idecode = cpu->top->riscv_core_i->id_stage_i->decoder_i->scarv_cop_idecode_i;
  uint32_t encoded = idecode->read_encoded();
  if ((encoded & 0xFFFFFFFF) == 0x1110082B) { // xc.init
    uint32_t init = idecode->read_id_cprs_init();
    if (!init) {
      std::cout << "Init not asserted for xc.init." << std::endl;
      passed = false;
    }
  }

  uint32_t subclass_aes = idecode->read_subclass_aes();
  uint32_t subclass_bitwise = idecode->read_subclass_bitwise();
  uint32_t subclass_load_store = idecode->read_subclass_load_store();
  uint32_t subclass_move = idecode->read_subclass_move();
  uint32_t subclass_mp = idecode->read_subclass_mp();
  uint32_t subclass_palu = idecode->read_subclass_palu();
  uint32_t subclass_permute = idecode->read_subclass_permute();
  uint32_t subclass_random = idecode->read_subclass_random();
  uint32_t subclass_sha3 = idecode->read_subclass_sha3();

  if ((encoded & 0xfff8707f) == 0x1000002b) {
    if (!(subclass_move&(1<<SCARV_COP_SCLASS_XCR2GPR))) {
      std::cout << "dec_xcr2gpr not asserted for xc.xcr2gpr" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xfff0787f) == 0x1100002b) {
    if (!(subclass_move & (1<<SCARV_COP_SCLASS_GPR2XCR))) {
      std::cout << "dec_gpr2xcr not asserted for xc.gpr2xcr" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xfff87fff) == 0x800002b) {
    if (!(subclass_random & (1<<SCARV_COP_SCLASS_RSEED))) {
      std::cout << "dec_rngseed not asserted for xc.rngseed" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xfffff87f) == 0x810082b) {
    if (!(subclass_random & (1<<SCARV_COP_SCLASS_RSAMP))) {
      std::cout << "dec_rngsamp not asserted for xc.dec_rngsamp" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xfffff07f) == 0x820002b) {
    if (!(subclass_random & (1<<SCARV_COP_SCLASS_RTEST))) {
      std::cout << "dec_rngtest not asserted for xc.rngtest" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff08787f) == 0x1800082b) {
    if (!(subclass_move & (1<<SCARV_COP_SCLASS_CMOV_T))) {
      std::cout << "dec_cmov_t not asserted for xc.cmov_t" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff08787f) == 0x1800002b) {
    if (!(subclass_move & (1<<SCARV_COP_SCLASS_CMOV_F))) {
      std::cout << "dec_cmov_f not asserted for xc.cmov_f" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1f08787f) == 0x600002b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PADD))) {
      std::cout << "dec_padd not asserted for xc.padd" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1f08787f) == 0x600082b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PSUB))) {
      std::cout << "dec_psub not asserted for xc.psub" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1f08787f) == 0xe00002b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PMUL_L))) {
      std::cout << "dec_pmul_l not asserted for xc.pmul_l" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1f08787f) == 0xe00082b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PMUL_H))) {
      std::cout << "dec_pmul_h not asserted for xc.pmul_h" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1f08787f) == 0xe08002b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PCLMUL_L))) {
      std::cout << "dec_pclmul_l not asserted for xc.pclmul_l" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1f08787f) == 0xe08082b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PCLMUL_H))) {
      std::cout << "dec_pclmul_h not asserted for xc.pclmul_h" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1f08787f) == 0x1600002b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PSLL))) {
      std::cout << "dec_psll not asserted for xc.psll" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1f08787f) == 0x1600082b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PSRL))) {
      std::cout << "dec_psrl not asserted for xc.psrl" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1f08787f) == 0x1608082b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PROT))) {
      std::cout << "dec_prot not asserted for xc.prot" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1e08787f) == 0x1e00002b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PSLL_I))) {
      std::cout << "dec_psll_i not asserted for xc.psll_i" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1e08787f) == 0x1e00082b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PSRL_I))) {
      std::cout << "dec_psrl_i not asserted for xc.psrl_i" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x1e08787f) == 0x1e08082b) {
    if (!(subclass_palu & (1<<SCARV_COP_SCLASS_PROT_I))) {
      std::cout << "dec_prot_i not asserted for xc.prot_i" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x3e00707f) == 0xc00002b) {
    if (!(subclass_sha3 & (1<<SCARV_COP_SCLASS_SHA3_XY))) {
      std::cout << "dec_sha3_xy not asserted for xc.sha3_xy" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x3e00707f) == 0x1400002b) {
    if (!(subclass_sha3 & (1<<SCARV_COP_SCLASS_SHA3_X1))) {
      std::cout << "dec_sha3_x1 not asserted for xc.sha3_x1" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x3e00707f) == 0x2400002b) {
    if (!(subclass_sha3 & (1<<SCARV_COP_SCLASS_SHA3_X2))) {
      std::cout << "dec_sha3_x2 not asserted for xc.sha3_x2" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x3e00707f) == 0x1c00002b) {
    if (!(subclass_sha3 & (1<<SCARV_COP_SCLASS_SHA3_X4))) {
      std::cout << "dec_sha3_x4 not asserted for xc.sha3_x4" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x3e00707f) == 0x3400002b) {
    if (!(subclass_sha3 & (1<<SCARV_COP_SCLASS_SHA3_YX))) {
      std::cout << "dec_sha3_yx not asserted for xc.sha3_yx" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff08787f) == 0x400002b) {
    if (!(subclass_aes & (1<<SCARV_COP_SCLASS_AESSUB_ENC))) {
      std::cout << "dec_aessub_enc not asserted for xc.aessub_enc" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff08787f) == 0x400082b) {
    if (!(subclass_aes & (1<<SCARV_COP_SCLASS_AESSUB_ENCROT))) {
      std::cout << "dec_aessub_encrot not asserted for xc.aessub_encrot" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff08787f) == 0x408002b) {
    if (!(subclass_aes & (1<<SCARV_COP_SCLASS_AESSUB_DEC))) {
      std::cout << "dec_aessub_dec not asserted for xc.aessub_dec" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff08787f) == 0x408082b) {
    if (!(subclass_aes & (1<<SCARV_COP_SCLASS_AESSUB_DECROT))) {
      std::cout << "dec_aessub_decrot not asserted for xc.aessub_decrot" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff08787f) == 0x500002b) {
    if (!(subclass_aes & (1<<SCARV_COP_SCLASS_AESMIX_ENC))) {
      std::cout << "dec_aesmix_enc not asserted for xc.aesmix_enc" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff08787f) == 0x508002b) {
    if (!(subclass_aes & (1<<SCARV_COP_SCLASS_AESMIX_DEC))) {
      std::cout << "dec_aesmix_dec not asserted for xc.aesmix_dec" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x3e00787f) == 0x200002b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_LDR_B))) {
      std::cout << "dec_ldr_bu not asserted for xc.ldr_bu" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x3e00787f) == 0x1200002b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_LDR_H))) {
      std::cout << "dec_ldr_hu not asserted for xc.ldr_hu" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xfe00787f) == 0x2200002b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_LDR_W))) {
      std::cout << "dec_ldr_w not asserted for xc.ldr_w" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x3e00787f) == 0x200082b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_STR_B))) {
      std::cout << "dec_str_b not asserted for xc.str_b" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x3e00787f) == 0x1200082b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_STR_H))) {
      std::cout << "dec_str_h not asserted for xc.str_h" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xfe00787f) == 0x2200082b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_STR_W))) {
      std::cout << "dec_str_w not asserted for xc.str_w" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff00787f) == 0xa00082b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_SCATTER_B))) {
      std::cout << "dec_scatter_b not asserted for xc.scatter_b" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff00787f) == 0xa00002b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_GATHER_B))) {
      std::cout << "dec_gather_b not asserted for xc.gather_b" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff00787f) == 0xb00082b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_SCATTER_H))) {
      std::cout << "dec_scatter_h not asserted for xc.scatter_h" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff00787f) == 0xb00002b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_GATHER_H))) {
      std::cout << "dec_gather_h not asserted for xc.gather_h" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x8787f) == 0x682b) {
    if (!(subclass_bitwise & (1<<SCARV_COP_SCLASS_BOP))) {
      std::cout << "dec_bop not asserted for xc.bop" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xf000707f) == 0x702b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MEQU))) {
      std::cout << "dec_mequ not asserted for xc.mequ" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xf000707f) == 0x1000702b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MLTE))) {
      std::cout << "dec_mlte not asserted for xc.mlte" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xf000707f) == 0x2000702b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MGTE))) {
      std::cout << "dec_mgte not asserted for xc.mgte" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xf008787f) == 0x3008702b) {
    if (!(subclass_bitwise & (1<<SCARV_COP_SCLASS_LUT))) {
      std::cout << "dec_lut not asserted for xc.lut" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xf0087c7f) == 0x4000702b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MADD_3))) {
      std::cout << "dec_madd_3 not asserted for xc.madd_3" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xf0087c7f) == 0x6000702b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MSUB_3))) {
      std::cout << "dec_msub_3 not asserted for xc.msub_3" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff087c7f) == 0x5000702b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MADD_2))) {
      std::cout << "dec_madd_2 not asserted for xc.madd_2" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff087c7f) == 0x5100702b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MSUB_2))) {
      std::cout << "dec_msub_2 not asserted for xc.msub_2" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xff087c7f) == 0x5200702b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MACC_2))) {
      std::cout << "dec_macc_2 not asserted for xc.macc_2" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xfff87c7f) == 0x5f00702b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MACC_1))) {
      std::cout << "dec_macc_1 not asserted for xc.macc_1" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xf0087c7f) == 0x7000782b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MSLL))) {
      std::cout << "dec_msll not asserted for xc.msll" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xf0087c7f) == 0x8000782b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MSRL))) {
      std::cout << "dec_msrl not asserted for xc.msrl" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xf0087c7f) == 0x9000782b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MMUL_3))) {
      std::cout << "dec_mmul_3 not asserted for xc.mmul_3" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xf0087c7f) == 0xa000782b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MCLMUL_3))) {
      std::cout << "dec_mclmul_3 not asserted for xc.mclmul_3" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xc0087c7f) == 0xc000742b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MSLL_I))) {
      std::cout << "dec_msll_i not asserted for xc.msll_i" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xc0087c7f) == 0x8000742b) {
    if (!(subclass_mp & (1<<SCARV_COP_SCLASS_MSRL_I))) {
      std::cout << "dec_msrl_i not asserted for xc.msrl_i" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x707f) == 0x102b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_LB_CR))) {
      std::cout << "dec_ld_bu not asserted for xc.ld_bu" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x10707f) == 0x202b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_LH_CR))) {
      std::cout << "dec_ld_hu not asserted for xc.ld_hu" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x10787f) == 0x302b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_LD_W))) {
      std::cout << "dec_ld_w not asserted for xc.ld_w" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x10787f) == 0x10302b) {
    if (!(subclass_bitwise & (1<<SCARV_COP_SCLASS_LD_HIU))) {
      std::cout << "dec_ld_hiu not asserted for xc.ld_hiu" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x10787f) == 0x10382b) {
    if (!(subclass_bitwise & (1<<SCARV_COP_SCLASS_LD_LIU))) {
      std::cout << "dec_ld_liu = not asserted for xc.ld_liu =" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x7f8787f) == 0x10202b) {
    if (!(subclass_permute & (1<<SCARV_COP_SCLASS_PERM_IBIT))) {
      std::cout << "dec_ipbit not asserted for xc.ipbit" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x7f8787f) == 0x10282b) {
    if (!(subclass_permute & (1<<SCARV_COP_SCLASS_PERM_BIT))) {
      std::cout << "dec_pbit not asserted for xc.pbit" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0xf8787f) == 0x30202b) {
    if (!(subclass_permute & (1<<SCARV_COP_SCLASS_PERM_BYTE))) {
      std::cout << "dec_pbyte not asserted for xc.pbyte" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x38787f) == 0x30282b) {
    if (!(subclass_bitwise & (1<<SCARV_COP_SCLASS_INS))) {
      std::cout << "dec_ins not asserted for xc.ins" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x38787f) == 0x38202b) {
    if (!(subclass_bitwise & (1<<SCARV_COP_SCLASS_BMV))) {
      std::cout << "dec_bmv not asserted for xc.bmv" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x38787f) == 0x38282b) {
    if (!(subclass_bitwise & (1<<SCARV_COP_SCLASS_EXT))) {
      std::cout << "dec_ext not asserted for xc.ext" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x707f) == 0x402b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_ST_B))) {
      std::cout << "dec_st_b not asserted for xc.st_b" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x100707f) == 0x502b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_ST_H))) {
      std::cout << "dec_st_h not asserted for xc.st_h" << std::endl;
      passed = false;
    }
  }

  if ((encoded & 0x100787f) == 0x602b) {
    if (!(subclass_load_store & (1<<SCARV_COP_SCLASS_ST_W))) {
      std::cout << "dec_st_w not asserted for xc.st_w" << std::endl;
      passed = false;
    }
  }

}

// Clock the CPU for a given number of cycles, dumping to the trace file at
// each clock edge.
void clockSpin(uint32_t cycles)
{
  for (uint32_t i = 0; i < cycles; i++)
  {
    cpu->clk_i = 0;
    cpu->eval ();
    cpuTime += 1;
    tfp->dump (cpuTime);
    cpu->clk_i = 1;
    cpu->eval ();
    cpuTime += 1;
    tfp->dump (cpuTime);
    mCycleCnt++;
    checkProperties();
    //std::cout << "XCrypto illegal: " << cpu->top->riscv_core_i->id_stage_i->decoder_i->read_xcrypto_illegal() << std::endl;
  }
}

// Read/write a debug register.
void debugAccess(uint32_t addr, uint32_t& val, bool write_enable)
{
  cpu->debug_req_i   = 1;
  cpu->debug_addr_i  = addr;
  cpu->debug_we_i    = write_enable ? 1 : 0;

  if (write_enable)
  {
    cpu->debug_wdata_i = val;
  }

  // Access has been acknowledged when we get the grant signal asserted.
  do
    {
      clockSpin(1);
    }
  while (cpu->debug_gnt_o == 0);

  // Don't need to request once we get the grant.
  cpu->debug_req_i = 0;

  if (!write_enable)
  {
    // For reads, we need to read the data when we get rvalid_o.
    // This could be on the same cycle as the grant, or later.
    while (cpu->debug_rvalid_o == 0)
    {
      clockSpin(1);
    }
    val = cpu->debug_rdata_o;
  }
}

// Read a debug register
uint32_t debugRead(uint32_t addr)
{
  uint32_t val;
  debugAccess(addr, val, false);
  return val;
}

// Write a debug register
void debugWrite(uint32_t addr, uint32_t val)
{
  debugAccess(addr, val, true);
}

// Cycle the clock until the debug unit reports that the CPU is halted.
void waitForDebugStall()
{
  // Assume that stall could happen at any point - we don't need to wait a cycle
  // to check if it's stalled before reading
  while (!(debugRead(DBG_CTRL) & DBG_CTRL_HALT))
  {
    clockSpin(1);
  }
}

void writeInstr(uint32_t addr, uint32_t instr) {
  const auto &dp_ram = cpu->top->ram_i->dp_ram_i;
  //auto wbyte = cpu->top->ram_i->dp_ram_i->writeByte;
  dp_ram->writeByte(addr + 0x0, (instr >> 0 ) & 0xFF);
  dp_ram->writeByte(addr + 0x1, (instr >> 8 ) & 0xFF);
  dp_ram->writeByte(addr + 0x2, (instr >> 16) & 0xFF);
  dp_ram->writeByte(addr + 0x3, (instr >> 24) & 0xFF);
}

// Execution begins at 0x80, so that's where we write our code.
void loadProgram()
{
  uint32_t addr = 0x80;

  const uint32_t instructions[] = {0x1000002b, 0x1100002b, 0x1110082b, 0x800002b, 0x810082b, 0x820002b, 0x1800082b, 0x1800002b, 0x2600002b, 0x2600082b, 0x2e00002b, 0x2e00082b, 0x2e08002b, 0x2e08082b, 0x3600002b, 0x3600082b, 0x3608082b, 0x3e00002b, 0x3e00082b, 0x3e08082b, 0xc00002b, 0x1400002b, 0x2400002b, 0x1c00002b, 0x3400002b, 0x400002b, 0x400082b, 0x408002b, 0x408082b, 0x500002b, 0x508002b, 0x200002b, 0x1200002b, 0x2200002b, 0x200082b, 0x1200082b, 0x2200082b, 0xa00082b, 0xa00002b, 0xb00082b, 0xb00002b, 0x682b, 0x702b, 0x1000702b, 0x2000702b, 0x3008702b, 0x4000702b, 0x6000702b, 0x5000702b, 0x5100702b, 0x5200702b, 0x5f00702b, 0x7000782b, 0x8000782b, 0x9000782b, 0xa000782b, 0xc000742b, 0x8000742b, 0x102b, 0x202b, 0x302b, 0x10302b, 0x10382b, 0x10202b, 0x10282b, 0x30202b, 0x30282b, 0x38202b, 0x38282b, 0x402b, 0x502b, 0x602b};

  // write every instruction type to memory
  for (const uint32_t instr : instructions) {
    writeInstr(addr, instr);
    addr += 4;
  }
}

int
main (int    argc,
      char * argv[])
{
  // Instantiate the model
  cpu = new Vtop;

  // Open VCD
  Verilated::traceEverOn (true);
  tfp = new VerilatedVcdC;
  cpu->trace (tfp, 99);
  tfp->open ("model.vcd");

  // Fix some signals for now.
  cpu->irq_i          = 0;
  cpu->debug_req_i    = 0;
  cpu->fetch_enable_i = 0;

  // Cycle through reset
  cpu->rstn_i = 0;
  clockSpin(5);
  cpu->rstn_i = 1;

  // Put a few instructions in memory
  loadProgram();

  cout << "About to halt and set traps on exceptions" << endl;

  // Try to halt the CPU in the same way as in spi_debug_test.svh
  debugWrite(DBG_CTRL, debugRead(DBG_CTRL) | DBG_CTRL_HALT);

  // Let things run for a few cycles while the CPU waits in a halted state,
  // simply to check that doing so doesn't cause any errors.
  clockSpin(5);

  // Set traps on exceptions
  debugWrite(DBG_IE, 0xF);

  cout << "About to resume" << endl;

  uint32_t new_ctrl = debugRead(DBG_CTRL) & ~DBG_CTRL_HALT;
  debugWrite(DBG_CTRL, new_ctrl);

  cpu->fetch_enable_i = 1;

  cout << "Cycling clock to run for a few instructions" << endl;
  clockSpin(73);

  cout << "Halting" << endl;

  debugWrite(DBG_CTRL, debugRead(DBG_CTRL) | DBG_CTRL_HALT);
  waitForDebugStall();

  // Close VCD

  tfp->close ();

  // Tidy up

  delete tfp;
  delete cpu;

  return !passed;
}

//! Function to handle $time calls in the Verilog

double
sc_time_stamp ()
{
  return cpuTime;
}

// Local Variables:
// mode: C++
// c-file-style: "gnu"
// show-trailing-whitespace: t
// End:
