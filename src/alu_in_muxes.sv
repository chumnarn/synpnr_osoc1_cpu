import cpu_sv_package::*;

module alu_in_muxes #(
    parameter int WIDTH = 32
)(
    // Data Inputs
    input  logic [WIDTH-1:0] pc_curr_i,
    input  logic [WIDTH-1:0] rs1_val_i,
    input  logic [WIDTH-1:0] rs2_val_i,
    input  logic [WIDTH-1:0] imm_i,
    
    // Control Inputs (Using strongly-typed Enums)
    input  sel_alu_a_e       s1_sel_i,
    input  sel_alu_b_e       s2_sel_i,
    
    // Data Outputs
    output logic [WIDTH-1:0] alu_a_o,
    output logic [WIDTH-1:0] alu_b_o
);

    // --- Mux A: 3-to-1 Selection ---
    always_comb begin
        unique case (s1_sel_i)
            OP_A_PC:   alu_a_o = pc_curr_i;
            OP_A_RS1:  alu_a_o = rs1_val_i;
            OP_A_ZERO: alu_a_o = '0;
            default:   alu_a_o = '0; 
        endcase
    end

    // --- Mux B: 2-to-1 Selection ---
    // Using the Ternary Operator for clean 2-input logic
    assign alu_b_o = (s2_sel_i == OP_B_IMM) ? imm_i : rs2_val_i;

endmodule

