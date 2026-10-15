module Register(
    parameter BW = 32
    )(
    input logic clk,rst,
    input logic ld, clr,
    input logic [BW:0] in,
    output logic [BW:0] out
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