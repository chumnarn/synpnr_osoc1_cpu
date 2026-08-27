import cpu_sv_package::*;

module decoder (
    input  logic [31:0] instr_i,

    // Wire Stripper Outputs
    output opcode_e     op_o,
    output logic [4:0]  rd_o,
    output logic [2:0]  f3_o,
    output logic [4:0]  rs1_o,
    output logic [4:0]  rs2_o,
    output logic [6:0]  f7_o,
    
    // Immediate Generation Output
    output logic [31:0] imm_o
);

    // --- 1. The Wire Stripper ---
    assign op_o  = opcode_e'(instr_i[6:0]); 
    assign rd_o  = instr_i[11:7];
    assign f3_o  = instr_i[14:12];
    assign rs1_o = instr_i[19:15];
    assign rs2_o = instr_i[24:20];
    assign f7_o  = instr_i[31:25];

    // --- Icarus Bug Fix: Pre-slice wires to enforce strict boundaries ---
    wire        i31     = instr_i[31];
    wire [11:0] i31_20  = instr_i[31:20];
    wire [6:0]  i31_25  = instr_i[31:25];
    wire [4:0]  i11_7   = instr_i[11:7];
    wire        i7      = instr_i[7];
    wire [5:0]  i30_25  = instr_i[30:25];
    wire [3:0]  i11_8   = instr_i[11:8];
    wire [19:0] i31_12  = instr_i[31:12];
    wire [7:0]  i19_12  = instr_i[19:12];
    wire        i20     = instr_i[20];
    wire [9:0]  i30_21  = instr_i[30:21];

    // --- 2. Immediate Generation ---
    always_comb begin
        // Default to zero to prevent synthesis latches
        imm_o = '0;

        case (op_o)
            OPCODE_R_TYPE: begin
                imm_o = '0;
            end

            OPCODE_I_TYPE_ALU, OPCODE_I_TYPE_LOAD, OPCODE_I_TYPE_JALR: begin
                imm_o = { {20{i31}}, i31_20 };
            end

            OPCODE_S_TYPE: begin
                imm_o = { {20{i31}}, i31_25, i11_7 };
            end

            OPCODE_B_TYPE: begin
                imm_o = { {19{i31}}, i31, i7, i30_25, i11_8, 1'b0 };
            end

            OPCODE_U_TYPE_LUI, OPCODE_U_TYPE_AUIPC: begin
                imm_o = { i31_12, 12'b0 };
            end

            OPCODE_J_TYPE: begin
                imm_o = { {11{i31}}, i31, i19_12, i20, i30_21, 1'b0 };
            end

            default: begin
                imm_o = '0;
            end
        endcase
    end

endmodule
