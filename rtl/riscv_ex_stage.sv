// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Renzo Andri - andrire@student.ethz.ch                      //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    Execute stage                                              //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Execution stage: Hosts ALU and MAC unit                    //
//                 ALU: computes additions/subtractions/comparisons           //
//                 MULT: computes normal multiplications                      //
//                 APU_DISP: offloads instructions to the shared unit.        //
//                 SHARED_DSP_MULT, SHARED_INT_DIV allow                      //
//                 to offload also dot-product, int-div, int-mult to the      //
//                 shared unit.                                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`include "apu_macros.sv"

import apu_core_package::*;
import riscv_defines::*;

module riscv_ex_stage
#(
  parameter FPU              =  0,
  parameter SHARED_FP        =  0,
  parameter SHARED_DSP_MULT  =  0,
  parameter SHARED_INT_DIV   =  0,
  parameter APU_NARGS_CPU    =  3,
  parameter APU_WOP_CPU      =  6,
  parameter APU_NDSFLAGS_CPU = 15,
  parameter APU_NUSFLAGS_CPU =  5
)
(
  input  logic        clk,
  input  logic        rst_n,

  // ALU signals from ID stage
  input  logic [ALU_OP_WIDTH-1:0] alu_operator_i,
  input  logic [31:0] alu_operand_a_i,
  input  logic [31:0] alu_operand_b_i,
  input  logic [31:0] alu_operand_c_i,
  input  logic        alu_en_i,
  input  logic [ 4:0] bmask_a_i,
  input  logic [ 4:0] bmask_b_i,
  input  logic [ 1:0] imm_vec_ext_i,
  input  logic [ 1:0] alu_vec_mode_i,

  // Multiplier signals
  input  logic [ 2:0] mult_operator_i,
  input  logic [31:0] mult_operand_a_i,
  input  logic [31:0] mult_operand_b_i,
  input  logic [31:0] mult_operand_c_i,
  input  logic        mult_en_i,
  input  logic        mult_sel_subword_i,
  input  logic [ 1:0] mult_signed_mode_i,
  input  logic [ 4:0] mult_imm_i,

  input  logic [31:0] mult_dot_op_a_i,
  input  logic [31:0] mult_dot_op_b_i,
  input  logic [31:0] mult_dot_op_c_i,
  input  logic [ 1:0] mult_dot_signed_i,

  output logic        mult_multicycle_o,

  // FPU signals
  input  logic [C_CMD-1:0]            fpu_op_i,
  input  logic [C_PC-1:0]             fpu_prec_i,
  output logic [C_FFLAG-1:0]          fpu_fflags_o,
  output logic                        fpu_fflags_we_o,

  // XCrypto signals
  input  logic        cprs_init,       // init executing

  input  logic [ 8:0] id_class,        // Instruction class.
  input  logic [15:0] id_subclass,     // Instruction subclass.
  input  logic [ 2:0] id_pw,           // Instruction pack width.
  input  logic [31:0] id_imm,          // Decoded immediate.

  input  logic [31:0] gpr_rs1,         // GPR rs1
  input  logic [31:0] gpr_rs2,         // GPR rs1
  input  logic [31:0] crs1_rdata,      // CPR Port 1 read data
  input  logic [31:0] crs2_rdata,      // CPR Port 2 read data
  input  logic [31:0] crs3_rdata,      // CPR Port 3 read data

  output logic [ 3:0] crd_wen,         // CPR Port 4 write enable
  output logic [ 3:0] crd_addr,        // CPR Port 4 address
  output logic [31:0] crd_wdata,       // CPR Port 4 write data

  input  logic [ 3:0] id_crd,          // Instruction destination register
  input  logic [ 3:0] id_crd1,         // MP Instruction destination register 1
  input  logic [ 3:0] id_crd2,         // MP Instruction destination register 2

  output logic        malu_rdm_in_rs,  // Source destination registers in rs1/rs2

  // APU signals
  input  logic                        apu_en_i,
  input  logic [APU_WOP_CPU-1:0]      apu_op_i,
  input  logic [1:0]                  apu_lat_i,
  input  logic [31:0]                 apu_operands_i [APU_NARGS_CPU-1:0],
  input  logic [5:0]                  apu_waddr_i,
  input  logic [APU_NDSFLAGS_CPU-1:0] apu_flags_i,

  input  logic [2:0][5:0]             apu_read_regs_i,
  input  logic [2:0]                  apu_read_regs_valid_i,
  output logic                        apu_read_dep_o,
  input  logic [1:0][5:0]             apu_write_regs_i,
  input  logic [1:0]                  apu_write_regs_valid_i,
  output logic                        apu_write_dep_o,

  output logic                        apu_perf_type_o,
  output logic                        apu_perf_cont_o,
  output logic                        apu_perf_wb_o,

  output logic                        apu_busy_o,
  output logic                        apu_ready_wb_o,

  // apu-interconnect
  // handshake signals
  output logic                       apu_master_req_o,
  output logic                       apu_master_ready_o,
  input logic                        apu_master_gnt_i,
  // request channel
  output logic [31:0]                apu_master_operands_o [APU_NARGS_CPU-1:0],
  output logic [APU_WOP_CPU-1:0]     apu_master_op_o,
  // response channel
  input logic                        apu_master_valid_i,
  input logic [31:0]                 apu_master_result_i,

  input  logic        lsu_en_i,
  input  logic [31:0] lsu_rdata_i,

  // input from ID stage
  input  logic        branch_in_ex_i,
  input  logic [5:0]  regfile_alu_waddr_i,
  input  logic        regfile_alu_we_i,

  // directly passed through to WB stage, not used in EX
  input  logic        regfile_we_i,
  input  logic [5:0]  regfile_waddr_i,

  // CSR access
  input  logic        csr_access_i,
  input  logic [31:0] csr_rdata_i,

  // Output of EX stage pipeline
  output logic [5:0]  regfile_waddr_wb_o,
  output logic        regfile_we_wb_o,
  output logic [31:0] regfile_wdata_wb_o,

  // Forwarding ports : to ID stage
  output logic  [5:0] regfile_alu_waddr_fw_o,
  output logic        regfile_alu_we_fw_o,
  output logic [31:0] regfile_alu_wdata_fw_o,    // forward to RF and ID/EX pipe, ALU & MUL

  // To IF: Jump and branch target and decision
  output logic [31:0] jump_target_o,
  output logic        branch_decision_o,

  // Stall Control
  input  logic        lsu_ready_ex_i, // EX part of LSU is done

  output logic        ex_ready_o, // EX stage ready for new data
  output logic        ex_valid_o, // EX stage gets new data
  input  logic        wb_ready_i  // WB stage ready for new data
);

  logic [31:0]    alu_result;
  logic [31:0]    mult_result;
  logic           alu_cmp_result;

  logic           regfile_we_lsu;
  logic [5:0]     regfile_waddr_lsu;

  logic           wb_contention;
  logic           wb_contention_lsu;

  logic           alu_ready;
  logic           mult_ready;
  logic           fpu_busy;


  // APU signals
  logic           apu_valid;
  logic [5:0]     apu_waddr;
  logic [31:0]    apu_result;
  logic           apu_stall;
  logic           apu_active;
  logic           apu_singlecycle;
  logic           apu_multicycle;
  logic           apu_req;
  logic           apu_ready;
  logic           apu_gnt;

  // ALU write port mux
  always_comb
  begin
    regfile_alu_wdata_fw_o = '0;
    regfile_alu_waddr_fw_o = '0;
    regfile_alu_we_fw_o    = '0;
    wb_contention          = 1'b0;

    // APU single cycle operations, and multicycle operations (>2cycles) are written back on ALU port
    if (apu_valid & (apu_singlecycle | apu_multicycle)) begin
      regfile_alu_we_fw_o    = 1'b1;
      regfile_alu_waddr_fw_o = apu_waddr;
      regfile_alu_wdata_fw_o = apu_result;

      if(regfile_alu_we_i & ~apu_en_i) begin
        wb_contention = 1'b1;
      end
    end else begin
      regfile_alu_we_fw_o      = regfile_alu_we_i & ~apu_en_i; // private fpu incomplete?
      regfile_alu_waddr_fw_o   = regfile_alu_waddr_i;
      if (alu_en_i)
        regfile_alu_wdata_fw_o = alu_result;
      if (mult_en_i)
        regfile_alu_wdata_fw_o = mult_result;
      if (csr_access_i)
        regfile_alu_wdata_fw_o = csr_rdata_i;
    end
  end

  // LSU write port mux
  always_comb
  begin
    regfile_we_wb_o    = 1'b0;
    regfile_waddr_wb_o = regfile_waddr_lsu;
    regfile_wdata_wb_o = lsu_rdata_i;
    wb_contention_lsu  = 1'b0;

    if (regfile_we_lsu) begin
      regfile_we_wb_o = 1'b1;
      if (apu_valid & (!apu_singlecycle & !apu_multicycle)) begin
         wb_contention_lsu = 1'b1;
//         $error("%t, wb-contention", $time);
      end
    // APU two-cycle operations are written back on LSU port
    end else if (apu_valid & (!apu_singlecycle & !apu_multicycle)) begin
      regfile_we_wb_o    = 1'b1;
      regfile_waddr_wb_o = apu_waddr;
      regfile_wdata_wb_o = apu_result;
    end
  end

  // branch handling
  assign branch_decision_o = alu_cmp_result;
  assign jump_target_o     = alu_operand_c_i;


  ////////////////////////////
  //     _    _    _   _    //
  //    / \  | |  | | | |   //
  //   / _ \ | |  | | | |   //
  //  / ___ \| |__| |_| |   //
  // /_/   \_\_____\___/    //
  //                        //
  ////////////////////////////

  riscv_alu
  #(
    .SHARED_INT_DIV( SHARED_INT_DIV ),
    .FPU           ( FPU            )
    )
   alu_i
  (
    .clk                 ( clk             ),
    .rst_n               ( rst_n           ),
    .enable_i            ( alu_en_i        ),
    .operator_i          ( alu_operator_i  ),
    .operand_a_i         ( alu_operand_a_i ),
    .operand_b_i         ( alu_operand_b_i ),
    .operand_c_i         ( alu_operand_c_i ),

    .vector_mode_i       ( alu_vec_mode_i  ),
    .bmask_a_i           ( bmask_a_i       ),
    .bmask_b_i           ( bmask_b_i       ),
    .imm_vec_ext_i       ( imm_vec_ext_i   ),

    .result_o            ( alu_result      ),
    .comparison_result_o ( alu_cmp_result  ),

    .ready_o             ( alu_ready       ),
    .ex_ready_i          ( ex_ready_o      )
  );


  ////////////////////////////////////////////////////////////////
  //  __  __ _   _ _   _____ ___ ____  _     ___ _____ ____     //
  // |  \/  | | | | | |_   _|_ _|  _ \| |   |_ _| ____|  _ \    //
  // | |\/| | | | | |   | |  | || |_) | |    | ||  _| | |_) |   //
  // | |  | | |_| | |___| |  | ||  __/| |___ | || |___|  _ <    //
  // |_|  |_|\___/|_____|_| |___|_|   |_____|___|_____|_| \_\   //
  //                                                            //
  ////////////////////////////////////////////////////////////////

  riscv_mult
  #(
    .SHARED_DSP_MULT(SHARED_DSP_MULT)
   )
   mult_i
  (
    .clk             ( clk                  ),
    .rst_n           ( rst_n                ),

    .enable_i        ( mult_en_i            ),
    .operator_i      ( mult_operator_i      ),

    .short_subword_i ( mult_sel_subword_i   ),
    .short_signed_i  ( mult_signed_mode_i   ),

    .op_a_i          ( mult_operand_a_i     ),
    .op_b_i          ( mult_operand_b_i     ),
    .op_c_i          ( mult_operand_c_i     ),
    .imm_i           ( mult_imm_i           ),

    .dot_op_a_i      ( mult_dot_op_a_i      ),
    .dot_op_b_i      ( mult_dot_op_b_i      ),
    .dot_op_c_i      ( mult_dot_op_c_i      ),
    .dot_signed_i    ( mult_dot_signed_i    ),

    .result_o        ( mult_result          ),

    .multicycle_o    ( mult_multicycle_o    ),
    .ready_o         ( mult_ready           ),
    .ex_ready_i      ( ex_ready_o           )
  );

   generate
      if (FPU == 1) begin
         ////////////////////////////////////////////////////
         //     _    ____  _   _   ____ ___ ____  ____     //
         //    / \  |  _ \| | | | |  _ \_ _/ ___||  _ \    //
         //   / _ \ | |_) | | | | | | | | |\___ \| |_) |   //
         //  / ___ \|  __/| |_| | | |_| | | ___) |  __/    //
         // /_/   \_\_|    \___/  |____/___|____/|_|       //
         //                                                //
         ////////////////////////////////////////////////////

         riscv_apu_disp apu_disp_i
         (
         .clk_i              ( clk                            ),
         .rst_ni             ( rst_n                          ),

         .enable_i           ( apu_en_i                       ),
         .apu_lat_i          ( apu_lat_i                      ),
         .apu_waddr_i        ( apu_waddr_i                    ),

         .apu_waddr_o        ( apu_waddr                      ),
         .apu_multicycle_o   ( apu_multicycle                 ),
         .apu_singlecycle_o  ( apu_singlecycle                ),

         .active_o           ( apu_active                     ),
         .stall_o            ( apu_stall                      ),

         .read_regs_i        ( apu_read_regs_i                ),
         .read_regs_valid_i  ( apu_read_regs_valid_i          ),
         .read_dep_o         ( apu_read_dep_o                 ),
         .write_regs_i       ( apu_write_regs_i               ),
         .write_regs_valid_i ( apu_write_regs_valid_i         ),
         .write_dep_o        ( apu_write_dep_o                ),

         .perf_type_o        ( apu_perf_type_o                ),
         .perf_cont_o        ( apu_perf_cont_o                ),

         // apu-interconnect
         // handshake signals
         .apu_master_req_o   ( apu_req                        ),
         .apu_master_ready_o ( apu_ready                      ),
         .apu_master_gnt_i   ( apu_gnt                        ),
         // response channel
         .apu_master_valid_i ( apu_valid                      )
         );

         assign apu_perf_wb_o  = wb_contention | wb_contention_lsu;
         assign apu_ready_wb_o = ~(apu_active | apu_en_i | apu_stall) | apu_valid;

         if ( SHARED_FP == 1) begin
            assign apu_master_req_o      = apu_req;
            assign apu_master_ready_o    = apu_ready;
            assign apu_gnt               = apu_master_gnt_i;
            assign apu_valid             = apu_master_valid_i;
            assign apu_master_operands_o = apu_operands_i;
            assign apu_master_op_o       = apu_op_i;
            assign apu_result            = apu_master_result_i;
            assign fpu_fflags_we_o       = apu_valid;
         end
         else begin

         //////////////////////////////
         //   ______ _____  _    _   //
         //  |  ____|  __ \| |  | |  //
         //  | |__  | |__) | |  | |  //
         //  |  __| |  ___/| |  | |  //
         //  | |    | |    | |__| |  //
         //  |_|    |_|     \____/   //
         //////////////////////////////

            fpu_private fpu_i
             (
              .clk_i          ( clk               ),
              .rst_ni         ( rst_n             ),
              // enable
              .fpu_en_i       ( apu_req           ),
              // inputs
              .operand_a_i    ( apu_operands_i[0] ),
              .operand_b_i    ( apu_operands_i[1] ),
              .operand_c_i    ( apu_operands_i[2] ),
              .rm_i           ( apu_flags_i[2:0]  ),
              .fpu_op_i       ( fpu_op_i          ),
              .prec_i         ( fpu_prec_i        ),
              // outputs
              .result_o       ( apu_result        ),
              .valid_o        ( apu_valid         ),
              .flags_o        ( fpu_fflags_o      ),
              .divsqrt_busy_o ( fpu_busy          )
              );

            assign fpu_fflags_we_o          = apu_valid;
            assign apu_master_req_o         = '0;
            assign apu_master_ready_o       = 1'b1;
            assign apu_master_operands_o[0] = '0;
            assign apu_master_operands_o[1] = '0;
            assign apu_master_operands_o[2] = '0;
            assign apu_master_op_o          = '0;
            assign apu_gnt                  = 1'b1;

         end

      end
      else begin
         // default assignements for the case when no FPU/APU is attached.
         assign apu_master_req_o         = '0;
         assign apu_master_ready_o       = 1'b1;
         assign apu_master_operands_o[0] = '0;
         assign apu_master_operands_o[1] = '0;
         assign apu_master_operands_o[2] = '0;
         assign apu_master_op_o          = '0;
         assign apu_valid       = 1'b0;
         assign apu_waddr       = 6'b0;
         assign apu_stall       = 1'b0;
         assign apu_active      = 1'b0;
         assign apu_ready_wb_o  = 1'b1;
         assign apu_perf_wb_o   = 1'b0;
         assign apu_perf_cont_o = 1'b0;
         assign apu_perf_type_o = 1'b0;
         assign apu_singlecycle = 1'b0;
         assign apu_multicycle  = 1'b0;
         assign apu_read_dep_o  = 1'b0;
         assign apu_write_dep_o = 1'b0;
         assign fpu_fflags_we_o = 1'b0;
         assign fpu_fflags_o    = '0;
      end
   endgenerate

   assign apu_busy_o = apu_active;

  //////////////////////////////////////////////
  //  __  ______ ______   ______ _____ ___    //
  //  \ \/ / ___|  _ \ \ / /  _ \_   _/ _ \   // 
  //   \  / |   | |_) \ V /| |_) || || | | |  //   
  //   /  \ |___|  _ < | | |  __/ | || |_| |  // 
  //  /_/\_\____|_| \_\|_| |_|    |_| \___/   // 
  //                                          //
  //////////////////////////////////////////////

  `include "scarv_cop_common.vh"

  logic          palu_ivalid;      // Valid instruction input
  logic          palu_idone;       // Instruction complete
  logic [ 3:0]   palu_cpr_rd_ben;  // Writeback byte enable
  logic [31:0]   palu_cpr_rd_wdata;// Writeback data

//logic         mem_ivalid;        // Valid instruction input
//logic         mem_idone;         // Instruction complete
//logic         mem_is_store;      // Instruction is a store / nload
//logic         mem_addr_error;    // Memory address exception
//logic         mem_bus_error;     // Memory bus exception
//logic[ 3:0]   mem_cpr_rd_ben;    // Writeback byte enable
//logic[31:0]   mem_cpr_rd_wdata;  // Writeback data

  logic         malu_ivalid;       // Valid instruction input
  logic         malu_idone;        // Instruction complete
  logic [ 3:0]  malu_cpr_rd_ben;   // Writeback byte enable
  logic [31:0]  malu_cpr_rd_wdata; // Writeback data

  logic         rng_ivalid;        // Valid instruction input
  logic         rng_idone;         // Instruction complete
  logic [ 3:0]  rng_cpr_rd_ben;    // Writeback byte enable
  logic [31:0]  rng_cpr_rd_wdata;  // Writeback data

  logic         aes_ivalid;        // Valid instruction input
  logic         aes_idone;         // Instruction complete
  logic [ 3:0]  aes_cpr_rd_ben;    // Writeback byte enable
  logic [31:0]  aes_cpr_rd_wdata;  // Writeback data

  logic         sha3_ivalid;        // Valid instruction input
  logic         sha3_idone;         // Instruction complete
  logic [ 3:0]  sha3_cpr_rd_ben;    // Writeback byte enable
  logic [31:0]  sha3_cpr_rd_wdata;  // Writeback data

  logic         perm_ivalid;       // Valid instruction input
  logic         perm_idone;        // Instruction complete
  logic [ 3:0]  perm_cpr_rd_ben;   // Writeback byte enable
  logic [31:0]  perm_cpr_rd_wdata; // Writeback data

  assign palu_ivalid = 
    ( id_class[SCARV_COP_ICLASS_PACKED_ARITH] ||
      id_class[SCARV_COP_ICLASS_MOVE        ] ||
      id_class[SCARV_COP_ICLASS_BITWISE     ] );

  assign aes_ivalid   = id_class[SCARV_COP_ICLASS_AES];

  assign sha3_ivalid  = id_class[SCARV_COP_ICLASS_SHA3];

  assign malu_ivalid  = id_class[SCARV_COP_ICLASS_MP];

//assign mem_ivalid   = id_class[SCARV_COP_ICLASS_LOADSTORE];

  assign rng_ivalid   = id_class[SCARV_COP_ICLASS_RANDOM];

  assign perm_ivalid  = id_class[SCARV_COP_ICLASS_PERMUTE];

  assign crd_wen   = palu_cpr_rd_ben |
                     malu_cpr_rd_ben |
                     rng_cpr_rd_ben  |
                     aes_cpr_rd_ben  |
                     perm_cpr_rd_ben ;
                     //mem_cpr_rd_ben  |

  assign crd_addr  = !malu_ivalid ? id_crd :
                     !malu_idone  ? id_crd1:
                                    id_crd2;

  assign crd_wdata = palu_cpr_rd_wdata |
                     malu_cpr_rd_wdata |
                     rng_cpr_rd_wdata  |
                     aes_cpr_rd_wdata  |
                     perm_cpr_rd_wdata ;
                     //mem_cpr_rd_wdata  |

  //
  // instance: scarv_cop_palu
  //
  //  Combinatorial Packed arithmetic and shift module.
  //
  // notes:
  //  - INS expects crd value to be in palu_rs3
  //
  scarv_cop_palu i_scarv_cop_palu (
    .g_clk              ( clk               ), // Global clock
    .g_resetn           ( rst_n             ), // Synchronous active low reset.
    .palu_ivalid        ( palu_ivalid       ), // Valid instruction input
    .palu_idone         ( palu_idone        ), // Instruction complete
    .gpr_rs1            ( gpr_rs1             ), // GPR rs1
    .palu_rs1           ( crs1_rdata        ), // Source register 1
    .palu_rs2           ( crs2_rdata        ), // Source register 2
    .palu_rs3           ( crs3_rdata        ), // Source register 3
    .id_imm             ( id_imm            ), // Source immedate
    .id_pw              ( id_pw             ), // Pack width
    .id_class           ( id_class          ), // Instruction class
    .id_subclass        ( id_subclass       ), // Instruction subclass
    .palu_cpr_rd_ben    ( palu_cpr_rd_ben   ), // Writeback byte enable
    .palu_cpr_rd_wdata  ( palu_cpr_rd_wdata )  // Writeback data
  );


  //
  // instance: scarv_cop_aes
  //
  //  AES instruction implementations
  //
  //
  scarv_cop_aes i_scarv_cop_aes(
    .g_clk            (clk           ), // Global clock
    .g_resetn         (rst_n        ), // Synchronous active low reset.
    .aes_ivalid       (aes_ivalid      ), // Valid instruction input
    .aes_idone        (aes_idone       ), // Instruction complete
    .aes_rs1          (crs1_rdata      ), // Source register 1
    .aes_rs2          (crs2_rdata      ), // Source register 2
    .id_subclass      (id_subclass     ), // Instruction subclass
    .aes_cpr_rd_ben   (aes_cpr_rd_ben  ), // Writeback byte enable
    .aes_cpr_rd_wdata (aes_cpr_rd_wdata)  // Writeback data
  );

  //
  // instance: scarv_cop_sha3
  //
  //  SHA3 instruction implementations
  //
  //
  scarv_cop_sha3 i_scarv_cop_sha3 (
    .g_clk            (clk           ), // Global clock
    .g_resetn         (rst_n        ), // Synchronous active low reset.
    .sha3_ivalid      (sha3_ivalid     ), // Valid instruction input
    .sha3_idone       (sha3_idone      ), // Instruction complete
    .sha3_rs1         (gpr_rs1           ), // Source register 1
    .sha3_rs2         (gpr_rs2           ), // Source register 2
    .id_subclass      (id_subclass     ), // Instruction subclass
    .id_imm           (id_imm           ), // Source immedate
    .sha3_cpr_rd_ben  (sha3_cpr_rd_ben  ), // Writeback byte enable
    .sha3_cpr_rd_wdata(sha3_cpr_rd_wdata)  // Writeback data
  );

  //
  // instance: scarv_cop_mem
  //
  //  Load/store memory access module.
  //
//scarv_cop_mem i_scarv_cop_mem (
//  .g_clk           (clk           ), // Global clock
//  .g_resetn        (rst_n        ), // Synchronous active low reset.
//  .mem_ivalid      (mem_ivalid      ), // Valid instruction input
//  .mem_idone       (mem_idone       ), // Instruction complete
//  .mem_is_store    (mem_is_store    ), // Is the instruction a store?
//  .mem_addr_error  (mem_addr_error  ), // Memory address exception
//  .mem_bus_error   (mem_bus_error   ), // Memory bus exception
//  .gpr_rs1         (gpr_rs1           ), // GPR Source register 1
//  .gpr_rs2         (gpr_rs2           ), // GPR Source register 2
//  .cpr_rs1         (crs1_rdata      ), // XCR Source register 2
//  .cpr_rs2         (crs2_rdata      ), // XCR Source register 3
//  .cpr_rs3         (crs3_rdata      ), // XCR Source register 3
//  .id_wb_h         (id_wb_h         ), // Halfword index (load/store)
//  .id_wb_b         (id_wb_b         ), // Byte index (load/store)
//  .id_imm          (id_imm          ), // Source immedate
//  .id_subclass     (id_subclass     ), // Instruction subclass
//  .mem_cpr_rd_ben  (mem_cpr_rd_ben  ), // Writeback byte enable
//  .mem_cpr_rd_wdata(mem_cpr_rd_wdata), // Writeback data
//  .cop_mem_cen     (cop_mem_cen     ), // Chip enable
//  .cop_mem_wen     (cop_mem_wen     ), // write enable
//  .cop_mem_addr    (cop_mem_addr    ), // Read/write address (word aligned)
//  .cop_mem_wdata   (cop_mem_wdata   ), // Memory write data
//  .cop_mem_rdata   (cop_mem_rdata   ), // Memory read data
//  .cop_mem_ben     (cop_mem_ben     ), // Write Byte enable
//  .cop_mem_stall   (cop_mem_stall   ), // Stall
//  .cop_mem_error   (cop_mem_error   )  // Error
//);


  //
  // instance: scarv_cop_malu
  //
  //  Multi-precision arithmetic and shift module.
  //
  scarv_cop_malu i_scarv_cop_malu (
    .g_clk            (clk           ), // Global clock
    .g_resetn         (rst_n        ), // Synchronous active low reset.
    .malu_ivalid      (malu_ivalid      ), // Valid instruction input
    .malu_idone       (malu_idone       ), // Instruction complete
    .malu_rdm_in_rs   (malu_rdm_in_rs   ),
    .gpr_rs1          (gpr_rs1            ),
    .malu_rs1         (crs1_rdata       ), // Source register 1
    .malu_rs2         (crs2_rdata       ), // Source register 2
    .malu_rs3         (crs3_rdata       ), // Source register 3
    .id_imm           (id_imm           ), // Source immedate
    .id_subclass      (id_subclass      ), // Instruction subclass
    .malu_cpr_rd_ben  (malu_cpr_rd_ben  ), // Writeback byte enable
    .malu_cpr_rd_wdata(malu_cpr_rd_wdata)  // Writeback data
  );


  //
  // instance: scarv_cop_permute
  //
  //  Bit level permutation instructions.
  //
  scarv_cop_permute i_scarv_cop_permute (
  .perm_ivalid      (perm_ivalid      ), // Valid instruction input
  .perm_idone       (perm_idone       ), // Instruction complete
  .perm_rs1         (crs1_rdata       ), // Source register 1
  .perm_rs3         (crs3_rdata       ), // Source register 3 / rd
  .id_imm           (id_imm           ), // Source immedate
  .id_subclass      (id_subclass      ), // Instruction subclass
  .perm_cpr_rd_ben  (perm_cpr_rd_ben  ), // Writeback byte enable
  .perm_cpr_rd_wdata(perm_cpr_rd_wdata)  // Writeback data
  );


  //
  // Random number generator
  //
  scarv_cop_rng i_scarv_cop_rng(
    .g_clk           (clk           ), // Global clock
    .g_resetn        (rst_n        ), // Synchronous active low reset.
    .rng_ivalid      (rng_ivalid      ), // Valid instruction input
    .rng_idone       (rng_idone       ), // Instruction complete
  //`ifdef FORMAL
  //.cop_random      (cop_random      ), // Latest random sample value
  //.cop_rand_sample (cop_rand_sample ), // random sample value valid
  //`endif
    .rng_rs1         (crs1_rdata      ), // Source register 1
    .id_imm          (id_imm          ), // Source immedate
    .id_subclass     (id_subclass     ), // Instruction subclass
    .rng_cpr_rd_ben  (rng_cpr_rd_ben  ), // Writeback byte enable
    .rng_cpr_rd_wdata(rng_cpr_rd_wdata) // Writeback data
  );


  ///////////////////////////////////////
  // EX/WB Pipeline Register           //
  ///////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
  begin : EX_WB_Pipeline_Register
    if (~rst_n)
    begin
      regfile_waddr_lsu   <= '0;
      regfile_we_lsu      <= 1'b0;
    end
    else
    begin
      if (ex_valid_o) // wb_ready_i is implied
      begin
        regfile_we_lsu    <= regfile_we_i;
        if (regfile_we_i) begin
          regfile_waddr_lsu <= regfile_waddr_i;
        end
      end else if (wb_ready_i) begin
        // we are ready for a new instruction, but there is none available,
        // so we just flush the current one out of the pipe
        regfile_we_lsu    <= 1'b0;
      end
    end
  end

  // As valid always goes to the right and ready to the left, and we are able
  // to finish branches without going to the WB stage, ex_valid does not
  // depend on ex_ready.
  assign ex_ready_o = (~apu_stall & alu_ready & mult_ready & lsu_ready_ex_i
                       & wb_ready_i & ~wb_contention & ~cprs_init) | (branch_in_ex_i);
  assign ex_valid_o = (apu_valid | alu_en_i | mult_en_i | csr_access_i | lsu_en_i)
                       & (alu_ready & mult_ready & lsu_ready_ex_i & wb_ready_i & ~cprs_init);

endmodule
