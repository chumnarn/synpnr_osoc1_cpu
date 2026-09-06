
// chip_core.sv — Core logic wrapper instantiating osoc1_cpu

module chip_core (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic [3:0] gpio_in,
  output logic [3:0] gpio_out
);

  // Instantiate osoc1_cpu — ปรับ port names ตาม module จริง
  osoc1_cpu u_cpu (
    .clk   (clk_i),
    .rst_n (rst_ni),
    // TODO: เชื่อม GPIO และ port อื่นๆ ตาม interface ของ osoc1_cpu
    .gpio_in  (gpio_in),
    .gpio_out (gpio_out)
  );

endmodule
