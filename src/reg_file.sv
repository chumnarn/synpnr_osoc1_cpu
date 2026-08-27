module reg_file (
    input  logic        clk_i,
    input  logic        we_i,       // ONLY a Write Enable
    input  logic [4:0]  rs1_i,
    input  logic [4:0]  rs2_i,
    input  logic [4:0]  rd_i,
    input  logic [31:0] wd_i,

    output logic [31:0] rd1_o,
    output logic [31:0] rd2_o
);

    logic [31:0] registers [31:0];

    // =========================================================================
    // 1. Continuous, Mux-Based Reads (No Read Enable)
    // =========================================================================
    // The moment rs1_i or rs2_i changes, the output updates instantly.
    assign rd1_o = (rs1_i == 5'd0) ? 32'h00000000 : registers[rs1_i];
    assign rd2_o = (rs2_i == 5'd0) ? 32'h00000000 : registers[rs2_i];

    // =========================================================================
    // 2. Synchronous, Clocked Writes (Uses we_i)
    // =========================================================================
    always_ff @(posedge clk_i) begin
        if (we_i && (rd_i != 5'd0)) begin
            registers[rd_i] <= wd_i;
        end
    end

endmodule
