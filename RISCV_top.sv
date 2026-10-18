module RISCV_top (
    /*ports to be defined*/
    input logic clk,
    input logic rst_n
);

    logic[31:0] CPUdata_out;
    logic[31:0] addr;
    logic[31:0] CPUdata_in;
    logic[3:0] write_en;
    logic mem_ready;
    logic read_en;
    
    CPU_top CPU(
    .clk(clk),
    .rst_n(rst_n),
    .data_in(CPUdata_in),
    .mem_ready(mem_ready),
    .addr(addr),
    .data_out(CPUdata_out),
    .write_en(write_en),
    .read_en(read_en)
    );

    SRAMcontroller mem (
      .clk      (clk),
      .rst_n    (rst_n),
      .addr     (addr),
      .data_in  (CPUdata_out),
      .write_en (write_en),
      .read_en  (read_en),
      .mem_ready(mem_ready),
      .data_out (CPUdata_in)
  );

endmodule