module INC (
    input logic [31:0] in,
    input logic [31:0] inc_val,
    output logic [31:0] out
);
    assign out = in + inc_val;
endmodule