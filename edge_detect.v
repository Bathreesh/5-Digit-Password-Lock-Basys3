module edge_detect (
    input  clk,
    input  signal_in,
    output pulse_out       // HIGH for exactly 1 clock cycle on rising edge
);
    reg prev;

    always @(posedge clk)
        prev <= signal_in;

    assign pulse_out = signal_in & ~prev;
endmodule