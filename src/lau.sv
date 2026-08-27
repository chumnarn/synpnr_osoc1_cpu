module lau (
    input  logic [31:0] mem_data_i,
    input  logic        adrs_1_i,
    input  logic        adrs_0_i,
    input  logic [2:0]  funct3_i,

    output logic [31:0] aligned_data_o
);

    // Internal wires matching your schematic nodes
    logic [31:0] stage1_mux_out;
    logic [31:0] stage2_mux_out;

    // =========================================================================
    // 1. DATA PATH: The Cascaded Right-Shift Multiplexers
    // =========================================================================
    assign stage1_mux_out = adrs_1_i ? (mem_data_i >> 16) : mem_data_i;
    assign stage2_mux_out = adrs_0_i ? (stage1_mux_out >> 8) : stage1_mux_out;

    // --- Icarus Bug Fix: Extract physical data slices and sign bits ---
    wire [7:0]  s2_byte      = stage2_mux_out[7:0];
    wire        s2_byte_sign = stage2_mux_out[7];
    wire [15:0] s2_hw        = stage2_mux_out[15:0];
    wire        s2_hw_sign   = stage2_mux_out[15];

    // =========================================================================
    // 2. MASK UNIT & SIGN EXTENSION (SE)
    // =========================================================================
    always_comb begin
        // Hardware default to prevent latches
        aligned_data_o = '0;

        case (funct3_i)
            // lb (Load Byte - Signed)
            3'b000: begin 
                aligned_data_o = { {24{s2_byte_sign}}, s2_byte };
            end

            // lh (Load Halfword - Signed)
            3'b001: begin 
                aligned_data_o = { {16{s2_hw_sign}}, s2_hw };
            end

            // lw (Load Word)
            3'b010: begin 
                aligned_data_o = stage2_mux_out;
            end

            // lbu (Load Byte - Unsigned)
            3'b100: begin 
                aligned_data_o = { 24'b0, s2_byte };
            end

            // lhu (Load Halfword - Unsigned)
            3'b101: begin 
                aligned_data_o = { 16'b0, s2_hw };
            end

            default: aligned_data_o = '0;
        endcase
    end

endmodule
