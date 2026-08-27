import cpu_sv_package::*;

module osoc1_cpu_core (
    input  logic        clk_i,
    input  logic        rst_ni,

    // =========================================================================
    // Instruction Memory Interface (OUT to Wrapper)
    // =========================================================================
    output logic [31:0] pc_o,
    input  logic [31:0] instr_i,

    // =========================================================================
    // Data Memory Interface (OUT to Wrapper)
    // =========================================================================
    output logic [3:0]  dmem_we_o,
    output logic [31:0] dmem_addr_o,
    output logic [31:0] dmem_wdata_o,
    input  logic [31:0] dmem_rdata_i
);

    // =========================================================================
    // INTERNAL BUSES & WIRES
    // =========================================================================
    logic [31:0] pc_curr, pc_next, pc_plus_4;
    assign pc_o = pc_curr; 

    logic [6:0]  op;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  f3;
    logic [6:0]  f7;
    logic [31:0] imm;
    
    // Fixed Widths
    logic [2:0]  imm_src;
    logic [1:0]  s1_sel, pc_src; 
    logic        is_br, is_jal, is_jalr, s2_sel, mem_re, rf_we, master_mem_we;
    
    // Package Enums
    alu_op_e     alu_op;
    wb_sel_e     d2r; 

    // Datapath
    logic [31:0] rs1_val, rs2_val, rf_wd;
    logic [31:0] alu_a, alu_b, alu_res;
    logic        z_flag, s_flag, ov_flag, carry_flag;
    logic [3:0]  flags;

    // Memory Alignment
    logic [31:0] aligned_wdata, lau_res;
    logic        adrs_1, adrs_0;

    // =========================================================================
    // 0. THE CLOCK EDGE (PC Register Update)
    // =========================================================================
    pc_reg u_pc_reg (
        .clk_i   (clk_i),
        .rst_ni  (rst_ni),
        .pc_d_i  (pc_next),
        .pc_q_o  (pc_curr)
    );

    // =========================================================================
    // 1. FETCH (Instruction Tier)
    // =========================================================================
    pc_plus_4 u_pc_plus_4 (
        .pc_curr_i       (pc_curr),
        .pc_plus_4_o     (pc_plus_4)
    );

    // =========================================================================
    // 2. DECODE & CONTROL (Control Tier)
    // =========================================================================
    decoder u_decoder (
        .instr_i (instr_i),
        .op_o    (op),
        .rd_o    (rd),
        .rs1_o   (rs1),
        .rs2_o   (rs2),
        .f3_o    (f3),
        .f7_o    (f7),
        .imm_o   (imm)
    );

    ctrl u_ctrl (
        .opcode_i         (op),
        .funct3_i         (f3),
        .funct7_i         (f7),
        .is_cond_branch_o (is_br),
        .is_jal_o         (is_jal),
        .is_jalr_o        (is_jalr),
        .imm_src_o        (imm_src),
        .alu_src1_ctrl_o  (s1_sel),
        .alu_src2_ctrl_o  (s2_sel),
        .alu_ctrl_o       (alu_op),
        .datamem_re_o     (mem_re),
        .datamem_we_o     (master_mem_we),
        .dataMem2Reg_o    (d2r), 
        .regfile_we_o     (rf_we)
    );

    // =========================================================================
    // 3. REGISTER FILE READ (The Blue Wires)
    // =========================================================================
    reg_file u_reg_file (
        .clk_i   (clk_i),
        .we_i    (rf_we),
        .rs1_i   (rs1),
        .rs2_i   (rs2),
        .rd_i    (rd),
        .wd_i    (rf_wd),
        .rd1_o   (rs1_val),
        .rd2_o   (rs2_val)
    );

    // =========================================================================
    // 4. EXECUTION (Execution Tier)
    // =========================================================================
    alu_in_muxes u_alu_muxes (
        .pc_curr_i (pc_curr),
        .rs1_val_i (rs1_val),
        .rs2_val_i (rs2_val),
        .imm_i     (imm),
        .s1_sel_i  (s1_sel),
        .s2_sel_i  (s2_sel),
        .alu_a_o   (alu_a),
        .alu_b_o   (alu_b)
    );

    alu u_alu (
        .src1_i    (alu_a),
        .src2_i    (alu_b),
        .alu_op_i  (alu_op),
        .res_o     (alu_res),
        .z_o       (z_flag),
        .s_o       (s_flag),
        .ovfl_o    (ov_flag),
        .carry_o   (carry_flag)
    );

    assign flags = {z_flag, s_flag, ov_flag, carry_flag};

    // =========================================================================
    // 5. DATA MEMORY TIER (Memory Sub-system)
    // =========================================================================
    assign adrs_1 = alu_res[1];
    assign adrs_0 = alu_res[0];
    assign dmem_addr_o = alu_res;

    sau u_sau (
        .mem_we_i  (master_mem_we),
        .rs2_val_i (rs2_val),
        .adrs_1_i  (adrs_1),
        .adrs_0_i  (adrs_0),
        .f3_i      (f3),
        .wdata_o   (aligned_wdata),
        .strobe_o  (dmem_we_o) 
    );
    
    assign dmem_wdata_o = aligned_wdata;

    lau u_lau (
        .mem_data_i     (dmem_rdata_i),
        .adrs_1_i       (adrs_1),
        .adrs_0_i       (adrs_0),
        .funct3_i       (f3),
        .aligned_data_o (lau_res)
    );

    // =========================================================================
    // 6. WRITE-BACK SELECTION (Yellow Box)
    // =========================================================================
    rf_wb_mux u_rf_wb_mux (
        .alu_res_i   (alu_res),
        .lau_res_i   (lau_res),
        .pc_plus_4_i (pc_plus_4),
        .d2r_sel_i   (d2r),
        .rf_wd_o     (rf_wd)
    );

    // =========================================================================
    // 7. NEXT PC CALCULATION (Commit Phase Prep)
    // =========================================================================
    bcu u_bcu (
        .f3_i             (f3),
        .flags_i          (flags),
        .is_cond_branch_i (is_br),
        .is_jal_i         (is_jal),
        .is_jalr_i        (is_jalr),
        .pc_src_o         (pc_src)
    );

    next_pc_logic u_next_pc_logic (
        .pc_curr_i   (pc_curr),
        .pc_plus_4_i (pc_plus_4),
        .imm_i       (imm),
        .alu_res_i   (alu_res),
        .pc_src_i    (pc_src),
        .pc_next_o   (pc_next)
    );

endmodule
