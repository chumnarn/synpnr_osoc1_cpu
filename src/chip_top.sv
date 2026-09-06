// chip_top.sv — Top-level full chip wrapper for osoc1_cpu
// IHP SG13G2 — LibreLane Full Chip Flow

module chip_top #(
  parameter int NUM_VDD_PADS   = 2,
  parameter int NUM_VSS_PADS   = 2,
  parameter int NUM_IOVDD_PADS = 2,
  parameter int NUM_IOVSS_PADS = 2,
  parameter int NUM_INPUT_PADS = 4,
  parameter int NUM_OUTPUT_PADS = 4,
  parameter int NUM_BIDIR_PADS  = 0,
  parameter int NUM_ANALOG_PADS = 0
) (
  input  logic clk_pad,
  input  logic rst_n_pad,
  input  logic [NUM_INPUT_PADS-1:0]  gpio_in_pad,
  output logic [NUM_OUTPUT_PADS-1:0] gpio_out_pad
);

  // Internal signals (after pad buffer)
  logic clk_i, rst_ni;
  logic [NUM_INPUT_PADS-1:0]  gpio_in;
  logic [NUM_OUTPUT_PADS-1:0] gpio_out;

  // Instantiate chip_core (contains osoc1_cpu)
  chip_core u_chip_core (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .gpio_in   (gpio_in),
    .gpio_out  (gpio_out)
  );

endmodule
