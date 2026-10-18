module RISCV_top (
    /*ports to be defined*/
    input logic clk,
    input logic rst_n,
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
    .data_in(),
    .mem_ready(),
    .addr(),
    .data_out(),
    .write_en(),
    .read_en(),
    );

    memcontroler #(
      .BW(32)
    ) mem (
      .clk      (clk),
      .rst_n    (rst_n),
      .addr     (mem_addr),
      .data_in  (mem_adjwdata),
      .write_en (mem_we),
      .read_en  (MemRead),
      .mem_ready(mem_ready),
      .data_out (mem_rdata)
  );

endmodule