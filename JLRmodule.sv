module JLRmodule(
    input logic[31:0]   in,
    output logic[31:0]  out
);
    //assign out=in&~3'd3;
    assign out = in & ~32'd3;
endmodule