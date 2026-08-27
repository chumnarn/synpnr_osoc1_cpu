module egs (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       sel,
    output reg  [7:0] out_sync
);

    // 1. Continuous logic (Outside always block)
    wire [7:0] sum = a + b;
    wire [7:0] logic_and = a & b;

    // 2. Sequential logic (Clocked always block)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_sync <= 8'b0;
        end else if (sel) begin
            out_sync <= sum;
        end else begin
            out_sync <= logic_and;
        end
    end

endmodule
