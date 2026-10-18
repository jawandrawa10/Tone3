module urbana_top (
    input  logic        CLK_100MHZ,
    input  logic [15:0] SW,
    output logic [15:0] LED,
    output logic [ 7:0] D0_SEG,
    output logic [ 3:0] D0_AN,
    output logic [ 7:0] D1_SEG,
    output logic [ 3:0] D1_AN
);

    /*
    • The reset signal must be connected to one of the Switches
    • CPU clock and reset signal must be connected to the LEDs
    • Strobe signals (read_en, write_en and mem_ready) must be connected to the LEDs
    • The lowest 16 bits of the latest written memory data must be connected to four 7-Segment Displays 
      of the FPGA and the program counter must be connected to the other four 7-segment displays
    • The Program must finish in approximately a minute and must be observable, use an
      appropriate clock frequency to achieve this.
    */

  logic rst_n, clk_cpu, load;
  logic [31:0] dpc, last_wdata;

  assign rst_n = SW[15];
  assign LED   = {clk_cpu, SW[15], 14'b0};

  // load the divisor once after reset is released
  always_ff @(posedge CLK_100MHZ or negedge rst_n)
    if (!rst_n) load <= 1'b1;
    else load <= 1'b0;

  // CPU clock: 100 MHz / (2 * (divisor + 1)) = 100 Hz
  configurable_clock_divider #(
      .DIVISOR_WIDTH(32)
  ) clk_div (
      .rst_n  (rst_n),
      .clk_in (CLK_100MHZ),
      .divisor(32'd499_999),
      .load   (load),
      .clk_out(clk_cpu)
  );

    RISCV_top riscv(
    .clk(clk_cpu),
    .rst_n(rst_n)
    );



  riscv cpu_inst (
      .clk       (clk_cpu),
      .rst_n     (rst_n),
      .dpc       (dpc),
      .last_wdata(last_wdata)
  );

  // D0: last value written to memory
  kw4281_driver disp0 (
      .rst_n     (1'b1),
      .clk       (CLK_100MHZ),
      .input_bcd (last_wdata[15:0]),
      .input_dots(4'b1111),
      .an        (D0_AN),
      .seg       (D0_SEG)
  );

  // D1: PC
  kw4281_driver disp1 (
      .rst_n     (1'b1),
      .clk       (CLK_100MHZ),
      .input_bcd (dpc[15:0]),
      .input_dots(4'b1111),
      .an        (D1_AN),
      .seg       (D1_SEG)
  );

endmodule
