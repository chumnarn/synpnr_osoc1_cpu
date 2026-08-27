module bcu (
    input  logic [2:0] f3_i,
    input  logic [3:0] flags_i, // Unpacked inside as {Z, S, O, C}
    input  logic       is_cond_branch_i,
    input  logic       is_jal_i,
    input  logic       is_jalr_i,

    output logic [1:0] pc_src_o // 0=PC+4, 1=Target_Imm, 2=ALU_Res
);

    // Internal wires
    logic z_i, s_i, o_i, c_i;
    logic take_branch;

    // Unpack the flags bus for readability
    assign {z_i, s_i, o_i, c_i} = flags_i;

    // =========================================================================
    // 1. Evaluate Conditional Branch Logic (The Comparator Cloud)
    // =========================================================================
    always_comb begin
        take_branch = 1'b0; // Hardware default

        if (is_cond_branch_i) begin
            case (f3_i)
                3'b000: take_branch = (z_i == 1'b1); // BEQ: Zero flag is 1
                3'b001: take_branch = (z_i == 1'b0); // BNE: Zero flag is 0
                3'b100: take_branch = (s_i != o_i);  // BLT: Sign != Overflow
                3'b101: take_branch = (s_i == o_i);  // BGE: Sign == Overflow
                3'b110: take_branch = (c_i == 1'b0); // BLTU: No Carry (Borrow)
                3'b111: take_branch = (c_i == 1'b1); // BGEU: Carry (No Borrow)
                default: take_branch = 1'b0;
            endcase
        end
    end

    // =========================================================================
    // 2. Priority Encoder Logic (The Multiplexer Chain)
    // =========================================================================
    always_comb begin
        // Highest Priority: JALR forces PC to ALU Result
        if (is_jalr_i) begin
            pc_src_o = 2'b10;
        end 
        // Second Priority: JAL or successful Conditional Branch
        else if (is_jal_i || take_branch) begin
            pc_src_o = 2'b01;
        end 
        // Default: PC + 4 (Fallthrough)
        else begin
            pc_src_o = 2'b00;
        end
    end

endmodule
