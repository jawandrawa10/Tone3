module Register(
    input logic clk,rst,
    input logic ld, clr,
    input logic [31:0] in,
    output logic [31:0] out
);
    always_ff @(posedge clk or negedge rst ) begin
        if(!rst) out <= 'b0;
        else if (clr) out <= 'b0;
        else if (ld) out <= in;
    end
endmodule

module INC (
    input logic [31:0] in,
    input logic [31:0] inc_val,
    output logic [31:0] out
)
    assign out = in + inc_val;
endmodule

module mux2to1 #(parameter N) (
    input logic [N-1:0] in0, in1,
    input logic sel0, sel,
    output logic [N-1:0] out
) 
    always_comb begin
        out = 'b0;
        if (sel0) 
            out = in0;
        else if (sel1) 
            out = in1;
    end
endmodule