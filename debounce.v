module debounce (
    input  clk,
    input  btn_in,
    output reg btn_out
);
    // 100MHz clock → 20ms debounce = 2,000,000 cycles
    parameter DEBOUNCE_LIMIT = 2_000_000;
    
    reg [21:0] counter = 0;
    reg btn_sync_0, btn_sync_1;

    // Two-stage synchronizer (metastability protection)
    always @(posedge clk) begin
        btn_sync_0 <= btn_in;
        btn_sync_1 <= btn_sync_0;
    end

    always @(posedge clk) begin
        if (btn_sync_1 == btn_out) begin
            counter <= 0;           // No change, reset counter
        end else begin
            counter <= counter + 1;
            if (counter >= DEBOUNCE_LIMIT - 1) begin
                btn_out <= btn_sync_1; // Stable → accept
                counter <= 0;
            end
        end
    end
endmodule