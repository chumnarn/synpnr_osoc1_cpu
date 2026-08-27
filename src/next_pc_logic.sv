module next_pc_logic (
    input  logic [31:0] pc_curr_i,
    input  logic [31:0] pc_plus_4_i,
    input  logic [31:0] imm_i,
    input  logic [31:0] alu_res_i,
    input  logic [1:0]  pc_src_i,

    output logic [31:0] pc_next_o
);

    // Internal wires
    logic [31:0] branch_target;
    logic [31:0] jalr_target;

    // --- Internal Hardware: Branch Target Adder ---
    assign branch_target = pc_curr_i + imm_i;

    // --- Internal Hardware: JALR LSB Masking ---
    // Physically disconnects the 0th wire and solders it to ground
    assign jalr_target = alu_res_i & 32'hFFFFFFFE;

    // --- 3:1 Mux Selection Logic ---
    always_comb begin
        case (pc_src_i)
            2'b10:   pc_next_o = jalr_target;
            2'b01:   pc_next_o = branch_target;
            2'b00:   pc_next_o = pc_plus_4_i;
            default: pc_next_o = pc_plus_4_i; // Safe fallthrough
        endcase
    end

endmodule
