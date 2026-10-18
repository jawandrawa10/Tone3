module RISCV_top (
    /*ports to be defined*/
    input logic clk,
    input logic rst_n
);

    logic[31:0] data_in;
    logic[31:0] addr;
    logic[31:0] data_out;
    logic[3:0] write_en;
    logic mem_ready;
    logic read_en;
    
    CPU_top CPU(
    .clk(clk),
    .rst_n(rst_n),
    .data_in(data_in),
    .mem_ready(mem_ready),
    .addr(addr),
    .data_out(data_out),
    .write_en(write_en),
    .read_en(read_en)
    );

    SRAMcontroller mem (
      .clk      (clk),
      .rst_n    (rst_n),
      .addr     (addr),
      .data_in  (data_in),
      .write_en (write_en),
      .read_en  (read_en),
      .mem_ready(mem_ready),
      .data_out (data_out)
  );

endmodule