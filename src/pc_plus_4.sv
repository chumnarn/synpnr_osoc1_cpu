module pc_plus_4 (
    input  logic [31:0] pc_curr_i,
    output logic [31:0] pc_plus_4_o
);

    // Hardware: A dedicated 32-bit adder constantly computing the next sequential address
    assign pc_plus_4_o = pc_curr_i + 32'd4;

endmodule
