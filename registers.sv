module Register
    #(parameter BW = 32)
(
    input logic clk,rst,
    input logic ld,
    input logic [BW-1:0] in,
    output logic [BW-1:0] out
);
    always_ff @(posedge clk or negedge rst ) begin
        if(!rst) out <= 'b0;
        else if (ld) out <= in;
    end
endmodule