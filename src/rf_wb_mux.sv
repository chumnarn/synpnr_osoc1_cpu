// File location: osoc1_sim/rf_wb_mux/rf_wb_mux.sv

// Import everything (::*) from the cpu package
import cpu_sv_package::*;

module rf_wb_mux #(
    parameter int WIDTH = 32
)(
    input  logic [WIDTH-1:0] alu_res_i,
    input  logic [WIDTH-1:0] lau_res_i,
    input  logic [WIDTH-1:0] pc_plus_4_i,
    input  wb_sel_e          d2r_sel_i,   // Now perfectly understands the enum
    output logic [WIDTH-1:0] rf_wd_o
);

    always_comb begin
        unique case (d2r_sel_i)
            SEL_ALU: rf_wd_o = alu_res_i;
            SEL_LAU: rf_wd_o = lau_res_i;
            SEL_PC4: rf_wd_o = pc_plus_4_i;
            default: rf_wd_o = '0; 
        endcase
    end

endmodule
