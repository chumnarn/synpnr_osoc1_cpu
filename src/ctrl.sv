// Bring in the global definitions (opcodes, ALU operations, etc.)
import cpu_sv_package::*;

module ctrl (
    input  logic [6:0] opcode_i,
    input  logic [2:0] funct3_i,
    input  logic [6:0] funct7_i,

    output logic       is_cond_branch_o,
    output logic       is_jal_o,
    output logic       is_jalr_o,
    output logic [2:0] imm_src_o,
    output logic [1:0] alu_src1_ctrl_o, // 0=PC, 1=RS1, 2=Zero
    output logic       alu_src2_ctrl_o, // 0=RS2, 1=Imm
    output logic [3:0] alu_ctrl_o,      // 0=ADD, 1=SUB, etc.
    output logic       datamem_re_o,
    output logic       datamem_we_o,
    output logic [1:0] dataMem2Reg_o,   // 0=ALU, 1=DataMem, 2=PC+4
    output logic       regfile_we_o
);

    logic [6:0] op;
    assign op = opcode_i & 7'h7F;

    always_comb begin
        // --- Hardware Defaults (Reset State) ---
        is_cond_branch_o = 1'b0;
        is_jal_o         = 1'b0;
        is_jalr_o        = 1'b0;
        imm_src_o        = 3'd0;    // Default: 0 (I-Type)
        alu_src1_ctrl_o  = 2'd1;    // Default: 1 (RS1)
        alu_src2_ctrl_o  = 1'b0;    // Default: 0 (RS2)
        alu_ctrl_o       = 4'd0;    // Default: 0 (ADD)
        datamem_re_o     = 1'b0;
        datamem_we_o     = 1'b0;
        dataMem2Reg_o    = 2'd0;    // Default: 0 (ALU Out)
        regfile_we_o     = 1'b0;

        // --- Instruction Decoding Logic ---
        case (op)
            // R-TYPE (0x33)
            7'd51: begin
                regfile_we_o = 1'b1;
                case (funct3_i)
                    3'd0: alu_ctrl_o = (funct7_i == 7'd32) ? 4'd1 : 4'd0; // SUB : ADD
                    3'd1: alu_ctrl_o = 4'd2; // SLL
                    3'd2: alu_ctrl_o = 4'd3; // SLT
                    3'd3: alu_ctrl_o = 4'd4; // SLTU
                    3'd4: alu_ctrl_o = 4'd5; // XOR
                    3'd5: alu_ctrl_o = (funct7_i == 7'd32) ? 4'd7 : 4'd6; // SRA : SRL
                    3'd6: alu_ctrl_o = 4'd8; // OR
                    3'd7: alu_ctrl_o = 4'd9; // AND
                endcase
            end

            // I-TYPE ALU (0x13)
            7'd19: begin
                regfile_we_o    = 1'b1;
                alu_src2_ctrl_o = 1'b1;
                case (funct3_i)
                    3'd0: alu_ctrl_o = 4'd0; // ADDI
                    3'd1: alu_ctrl_o = 4'd2; // SLLI
                    3'd2: alu_ctrl_o = 4'd3; // SLTI
                    3'd3: alu_ctrl_o = 4'd4; // SLTIU
                    3'd4: alu_ctrl_o = 4'd5; // XORI
                    3'd5: alu_ctrl_o = (funct7_i == 7'd32) ? 4'd7 : 4'd6; // SRAI : SRLI
                    3'd6: alu_ctrl_o = 4'd8; // ORI
                    3'd7: alu_ctrl_o = 4'd9; // ANDI
                endcase
            end

            // LOAD (0x03)
            7'd3: begin
                regfile_we_o    = 1'b1;
                alu_src2_ctrl_o = 1'b1;
                datamem_re_o    = 1'b1;
                dataMem2Reg_o   = 2'd1;
            end

            // STORE (0x23)
            7'd35: begin
                imm_src_o       = 3'd1;
                alu_src2_ctrl_o = 1'b1;
                datamem_we_o    = 1'b1;
            end

            // BRANCH (0x63)
            7'd99: begin
                is_cond_branch_o = 1'b1;
                imm_src_o        = 3'd2;
                alu_ctrl_o       = 4'd1; // SUB
            end

            // LUI (0x37)
            7'd55: begin
                regfile_we_o    = 1'b1;
                imm_src_o       = 3'd3;
                alu_src1_ctrl_o = 2'd2; // Zero
                alu_src2_ctrl_o = 1'b1;
            end

            // AUIPC (0x17)
            7'd23: begin
                regfile_we_o    = 1'b1;
                imm_src_o       = 3'd3;
                alu_src1_ctrl_o = 2'd0; // PC
                alu_src2_ctrl_o = 1'b1;
            end

            // JALR (0x67)
            7'd103: begin
                is_jalr_o       = 1'b1;
                regfile_we_o    = 1'b1;
                alu_src1_ctrl_o = 2'd1;
                alu_src2_ctrl_o = 1'b1;
                alu_ctrl_o      = 4'd0;
                dataMem2Reg_o   = 2'd2;
            end

            // JAL (0x6F)
            7'd111: begin
                is_jal_o        = 1'b1;
                regfile_we_o    = 1'b1;
                imm_src_o       = 3'd4;
                dataMem2Reg_o   = 2'd2;
            end

            default: begin
                // Retain safe reset states
            end
        endcase
    end
endmodule
