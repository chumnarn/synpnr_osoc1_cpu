module pc_reg (
    input  logic        clk_i,
    input  logic        rst_ni, // Active-low reset
    input  logic [31:0] pc_d_i, // D-input (from next_pc_logic)
    
    output logic [31:0] pc_q_o  // Q-output (Current PC)
);

    // always_ff is used strictly for sequential, clocked logic
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pc_q_o <= 32'h00000000; // Reset PC to boot address
        end else begin
            pc_q_o <= pc_d_i;       // Non-blocking assignment!
        end
    end

endmodule
