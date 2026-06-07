module password_lock (
    input        clk,
    input        sw_mode,
    input        btn_u,
    input        btn_l,
    input        btn_r,
    input        btn_d,
    input        btn_c,
    output reg   led_locked,
    output reg   led_unlock,
    output reg   led_wrong
);

    // ─── Debounce ────────────────────────────────────────────
    wire db_u, db_l, db_r, db_d, db_c;
    debounce deb_u (.clk(clk), .btn_in(btn_u), .btn_out(db_u));
    debounce deb_l (.clk(clk), .btn_in(btn_l), .btn_out(db_l));
    debounce deb_r (.clk(clk), .btn_in(btn_r), .btn_out(db_r));
    debounce deb_d (.clk(clk), .btn_in(btn_d), .btn_out(db_d));
    debounce deb_c (.clk(clk), .btn_in(btn_c), .btn_out(db_c));

    // ─── Edge Detect ─────────────────────────────────────────
    wire pulse_u, pulse_l, pulse_r, pulse_d, pulse_c;
    edge_detect ed_u (.clk(clk), .signal_in(db_u), .pulse_out(pulse_u));
    edge_detect ed_l (.clk(clk), .signal_in(db_l), .pulse_out(pulse_l));
    edge_detect ed_r (.clk(clk), .signal_in(db_r), .pulse_out(pulse_r));
    edge_detect ed_d (.clk(clk), .signal_in(db_d), .pulse_out(pulse_d));
    edge_detect ed_c (.clk(clk), .signal_in(db_c), .pulse_out(pulse_c));

    // ─── Button Encoding ──────────────────────────────────────
    parameter BTN_U = 3'd1;
    parameter BTN_L = 3'd2;
    parameter BTN_R = 3'd3;
    parameter BTN_D = 3'd4;

    // ─── Password Storage ─────────────────────────────────────
    reg [2:0] saved_pass [0:4];
    reg [2:0] input_pass [0:4];
    reg [2:0] digit_buf;
    reg       pass_set = 0;   // FLAG: has a password been saved yet?

    // ─── FSM States ───────────────────────────────────────────
    localparam IDLE      = 3'd0;
    localparam COLLECT   = 3'd1;
    localparam SET_DONE  = 3'd2;
    localparam COMPARE   = 3'd3;
    localparam UNLOCKED  = 3'd4;
    localparam WRONG     = 3'd5;

    reg [2:0] state      = IDLE;
    reg [2:0] next_state = IDLE;       // ← separating next state
    reg [2:0] digit_count = 0;
    integer   i;

    wire any_digit = pulse_u | pulse_l | pulse_r | pulse_d;

    always @(*) begin
        if      (pulse_u) digit_buf = BTN_U;
        else if (pulse_l) digit_buf = BTN_L;
        else if (pulse_r) digit_buf = BTN_R;
        else if (pulse_d) digit_buf = BTN_D;
        else              digit_buf = 3'd0;
    end

    // ─── FIXED TIMER ──────────────────────────────────────────
    // Separate, self-contained timer module logic
    // 3 seconds @ 100MHz = 300,000,000 cycles
    parameter DISPLAY_TIME = 300_000_000;
    reg [28:0] timer      = 0;
    reg        timer_run  = 0;   // SET this to start timer
    reg        timer_done = 0;   // READ this to know timer finished

    always @(posedge clk) begin
        if (!timer_run) begin
            // Timer not running - reset everything
            timer      <= 0;
            timer_done <= 0;
        end else begin
            if (timer < DISPLAY_TIME - 1) begin
                timer      <= timer + 1;
                timer_done <= 0;
            end else begin
                timer      <= 0;         // reset so it doesn't latch
                timer_done <= 1;         // signal FSM
            end
        end
    end

    // ─── FSM ──────────────────────────────────────────────────
    always @(posedge clk) begin
        case (state)

            // ── IDLE: locked, waiting for first digit ──────────
            IDLE: begin
                led_locked  <= 1;
                led_unlock  <= 0;
                led_wrong   <= 0;
                timer_run   <= 0;
                digit_count <= 0;

                if (any_digit) begin
                    input_pass[0] <= digit_buf;
                    digit_count   <= 1;
                    state         <= COLLECT;
                end
            end

            // ── COLLECT: gather remaining 4 digits ────────────
            COLLECT: begin
                led_locked <= 1;
                led_unlock <= 0;
                led_wrong  <= 0;
                timer_run  <= 0;

                // Accept digit if we still need more
                if (any_digit && digit_count < 5) begin
                    input_pass[digit_count] <= digit_buf;
                    digit_count <= digit_count + 1;
                end

                // Only accept CONFIRM after exactly 5 digits
                if (pulse_c && digit_count == 5) begin
                    digit_count <= 0;
                    if (sw_mode)
                        state <= SET_DONE;
                    else begin
                        if (pass_set)
                            state <= COMPARE;
                        else
                            state <= WRONG;  // No password set yet!
                    end
                end
            end

            // ── SET_DONE: save password, blink LED[1] ─────────
            // ── SET_DONE: save password, show LED[1] for 3 sec ────
SET_DONE: begin
    led_locked    <= 0;
    led_unlock    <= 1;
    led_wrong     <= 0;
    timer_run     <= 1;
    pass_set      <= 1;

    // Always save (allows password change)
    saved_pass[0] <= input_pass[0];
    saved_pass[1] <= input_pass[1];
    saved_pass[2] <= input_pass[2];
    saved_pass[3] <= input_pass[3];
    saved_pass[4] <= input_pass[4];

    if (timer_done) begin
        timer_run <= 0;
        state     <= IDLE;
    end
end

            // ── COMPARE: check input vs saved ─────────────────
            COMPARE: begin
                led_locked <= 0;
                led_unlock <= 0;
                led_wrong  <= 0;
                timer_run  <= 0;

                if (input_pass[0] == saved_pass[0] &&
                    input_pass[1] == saved_pass[1] &&
                    input_pass[2] == saved_pass[2] &&
                    input_pass[3] == saved_pass[3] &&
                    input_pass[4] == saved_pass[4])
                    state <= UNLOCKED;
                else
                    state <= WRONG;
            end

            // ── UNLOCKED: correct password ────────────────────
            UNLOCKED: begin
                led_locked <= 0;
                led_unlock <= 1;    // LED[1] ON for 3 sec
                led_wrong  <= 0;
                timer_run  <= 1;

                if (timer_done) begin
                    timer_run <= 0;
                    state     <= IDLE;
                end
            end

            // ── WRONG: incorrect password ─────────────────────
            WRONG: begin
                led_locked <= 0;
                led_unlock <= 0;
                led_wrong  <= 1;    // LED[2] ON for 3 sec
                timer_run  <= 1;

                if (timer_done) begin
                    timer_run <= 0;
                    state     <= IDLE;
                end
            end

            default: state <= IDLE;

        endcase
    end

    // ─── Save password properly on SET_DONE entry ─────────────
    // (Moved array copy outside the !pass_set guard below)
    // ─── ILA Instantiation ────────────────────────────────────
ila_0 u_ila (
    .clk      (clk),           // same 100MHz clock

    .probe0   (state),         // 3-bit FSM state
    .probe1   (led_locked),    // 1-bit
    .probe2   (led_unlock),    // 1-bit
    .probe3   (led_wrong),     // 1-bit
    .probe4   (digit_count),   // 3-bit
    .probe5   (timer_run)      // 1-bit
);

endmodule