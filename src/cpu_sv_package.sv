package cpu_sv_package;

    // --- Write-Back Mux Selection ---
    typedef enum logic [1:0] {
        SEL_ALU = 2'b00,
        SEL_LAU = 2'b01,
        SEL_PC4 = 2'b10
    } wb_sel_e;

    // --- ALU Operand A Mux Selection ---
    typedef enum logic [1:0] {
        OP_A_PC   = 2'b00,
        OP_A_RS1  = 2'b01,
        OP_A_ZERO = 2'b10
    } sel_alu_a_e;

    // --- ALU Operand B Mux Selection ---
    typedef enum logic {
        OP_B_RS2 = 1'b0,
        OP_B_IMM = 1'b1
    } sel_alu_b_e;

    // --- ALU Operations (Aligned with Python Controller) ---
    typedef enum logic [3:0] {
        ALU_ADD  = 4'd0,
        ALU_SUB  = 4'd1,
        ALU_SLL  = 4'd2,  // Fixed to match Python model
        ALU_SLT  = 4'd3,  // Fixed to match Python model
        ALU_SLTU = 4'd4,  // Fixed to match Python model
        ALU_XOR  = 4'd5,
        ALU_SRL  = 4'd6,
        ALU_SRA  = 4'd7,
        ALU_OR   = 4'd8,
        ALU_AND  = 4'd9
    } alu_op_e;


    // --- RISC-V Base Opcodes [6:0] ---
    // Standardized by Instruction Format
    typedef enum logic [6:0] {
        OPCODE_R_TYPE       = 7'h33,  // 0110011 (add, sub, etc.)
        OPCODE_I_TYPE_ALU   = 7'h13,  // 0010011 (addi, slli, etc.)
        OPCODE_I_TYPE_LOAD  = 7'h03,  // 0000011 (lw, lh, lb)
        OPCODE_I_TYPE_JALR  = 7'h67,  // 1100111 (jalr)
        OPCODE_S_TYPE       = 7'h23,  // 0100011 (sw, sh, sb)
        OPCODE_B_TYPE       = 7'h63,  // 1100011 (beq, bne, etc.)
        OPCODE_U_TYPE_LUI   = 7'h37,  // 0110111 (lui)
        OPCODE_U_TYPE_AUIPC = 7'h17,  // 0010111 (auipc)
        OPCODE_J_TYPE       = 7'h6F   // 1101111 (jal)
    } opcode_e;

endpackage


