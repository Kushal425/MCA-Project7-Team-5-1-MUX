// ==============================================================================
// Testbench: tb_cache_2way_store_stress
// Description: Independent, self-checking randomized stress verification for
//              cache_2way_store using an ordered-pair recency scoreboard.
// Author: KrishnaDubale
// Standard: SystemVerilog (compiled with iverilog -g2012)
// ==============================================================================

`timescale 1ns / 1ps

module tb_cache_2way_store_stress;

    // --------------------------------------------------------------------------
    // Configuration & Reproducibility Parameters
    // --------------------------------------------------------------------------
    localparam int unsigned DEFAULT_SEED  = 32'h5A7C_1357;
    localparam int          NUM_SETS      = 4;
    localparam int          STRESS_STEPS  = 2000;
    localparam int          TAGS_PER_SET  = 6;

    // --------------------------------------------------------------------------
    // DUT Interface Signals
    // --------------------------------------------------------------------------
    reg          clk;
    reg          rst;
    reg  [31:0]  addr;
    reg          touch_en;
    reg          fill_en;
    reg  [127:0] fill_block;

    wire         hit;
    wire         hit_way;
    wire         victim_way;
    wire [31:0]  read_word;

    // --------------------------------------------------------------------------
    // DUT Instantiation (Interface Unchanged)
    // --------------------------------------------------------------------------
    cache_2way_store u_store (
        .clk        (clk),
        .rst        (rst),
        .addr       (addr),
        .touch_en   (touch_en),
        .fill_en    (fill_en),
        .fill_block (fill_block),
        .hit        (hit),
        .hit_way    (hit_way),
        .victim_way (victim_way),
        .read_word  (read_word)
    );

    // --------------------------------------------------------------------------
    // 100 MHz Clock & Watchdog Timer
    // --------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        #5000000; // 5 ms hard watchdog ceiling
        $fatal(1, "[WATCHDOG] Simulation timeout exceeded in tb_cache_2way_store_stress");
    end

    // --------------------------------------------------------------------------
    // Independent Ordered-Pair Reference Scoreboard
    // --------------------------------------------------------------------------
    // For each set s in 0..3:
    //   sb_count[s] == 0 : empty
    //   sb_count[s] == 1 : index [0] holds the lone resident entry
    //   sb_count[s] == 2 : index [0] = LRU entry, index [1] = MRU entry
    reg         sb_valid [0:NUM_SETS-1][0:1];
    reg  [25:0] sb_tag   [0:NUM_SETS-1][0:1];
    reg [127:0] sb_data  [0:NUM_SETS-1][0:1];
    reg         sb_way   [0:NUM_SETS-1][0:1];
    integer     sb_count [0:NUM_SETS-1];

    // --------------------------------------------------------------------------
    // Deterministic PRNG & Tracking Counters
    // --------------------------------------------------------------------------
    reg [31:0] seed_used;
    reg [31:0] rng_state;
    reg [31:0] fill_seq;

    integer op_count    = 0;
    integer check_count = 0;
    integer step_id     = 0;

    // Functional Coverage Counters
    integer cov_hit_way0            = 0;
    integer cov_hit_way1            = 0;
    integer cov_word_w0 [0:3];
    integer cov_word_w1 [0:3];
    integer cov_fill_empty_w0       = 0;
    integer cov_fill_empty_w1       = 0;
    integer cov_evict_w0            = 0;
    integer cov_evict_w1            = 0;
    integer cov_touch_lru_to_mru_w0 = 0;
    integer cov_touch_lru_to_mru_w1 = 0;
    integer cov_touch_mru_noop      = 0;
    integer cov_touch_miss_noop     = 0;
    integer cov_comb_lookup_no_en   = 0;
    integer cov_reset_after_fill    = 0;
    integer cov_set_fill [0:3];
    integer cov_set_touch [0:3];

    task automatic init_coverage();
        integer i;
        begin
            for (i = 0; i < 4; i = i + 1) begin
                cov_word_w0[i]   = 0;
                cov_word_w1[i]   = 0;
                cov_set_fill[i]  = 0;
                cov_set_touch[i] = 0;
            end
        end
    endtask

    function automatic [31:0] next_rand();
        reg [31:0] x;
        begin
            x = rng_state;
            x = x ^ (x << 13);
            x = x ^ (x >> 17);
            x = x ^ (x << 5);
            if (x == 32'd0) begin
                x = 32'h9E37_79B9;
            end
            rng_state = x;
            next_rand = x;
        end
    endfunction

    function automatic [31:0] make_addr(
        input [25:0] tag,
        input [1:0]  set_idx,
        input [1:0]  word_sel
    );
        begin
            make_addr = {tag, set_idx, word_sel, 2'b00};
        end
    endfunction

    function automatic [127:0] make_distinct_block(
        input [25:0] tag,
        input [1:0]  set_idx,
        input [31:0] seq_num
    );
        reg [31:0] w0, w1, w2, w3;
        begin
            w0 = ({seq_num[11:0], set_idx, 2'b00, tag[15:0]} ^ 32'hA5A5_0001) | 32'h0000_0001;
            w1 = ({seq_num[11:0], set_idx, 2'b01, tag[15:0]} ^ 32'h5A5A_0012) | 32'h0000_0002;
            w2 = ({seq_num[11:0], set_idx, 2'b10, tag[15:0]} ^ 32'h3C3C_0123) | 32'h0000_0004;
            w3 = ({seq_num[11:0], set_idx, 2'b11, tag[15:0]} ^ 32'hC3C3_1234) | 32'h0000_0008;
            make_distinct_block = {w3, w2, w1, w0};
        end
    endfunction

    function automatic [25:0] pool_tag(input [1:0] set_idx, input integer idx);
        begin
            // Distinct tags per set so cross-set aliasing is immediately visible
            pool_tag = {18'h00100, 2'b00, set_idx, idx[3:0]} + 26'h000010;
        end
    endfunction

    task automatic sb_reset();
        integer s, w;
        begin
            for (s = 0; s < NUM_SETS; s = s + 1) begin
                sb_count[s] = 0;
                for (w = 0; w < 2; w = w + 1) begin
                    sb_valid[s][w] = 1'b0;
                    sb_tag[s][w]   = 26'd0;
                    sb_data[s][w]  = 128'd0;
                    sb_way[s][w]   = 1'b0;
                end
            end
        end
    endtask

    task automatic sb_lookup(
        input  [31:0] target_addr,
        output        exp_hit,
        output        exp_hit_way,
        output [31:0] exp_read_word,
        output        exp_victim_way
    );
        reg [1:0]   s;
        reg [1:0]   wsel;
        reg [25:0]  t;
        reg [127:0] blk;
        integer     i;
        begin
            s    = target_addr[5:4];
            wsel = target_addr[3:2];
            t    = target_addr[31:6];

            // Victim rule from ordered-pair capacity & recency:
            //   0 resident -> Way 0 (empty Way 0 priority)
            //   1 resident -> complementary empty way
            //   2 resident -> LRU entry at index [0]
            if (sb_count[s] == 0) begin
                exp_victim_way = 1'b0;
            end else if (sb_count[s] == 1) begin
                exp_victim_way = ~sb_way[s][0];
            end else begin
                exp_victim_way = sb_way[s][0];
            end

            exp_hit       = 1'b0;
            exp_hit_way   = 1'b0;
            exp_read_word = 32'h0000_0000;

            for (i = 0; i < sb_count[s]; i = i + 1) begin
                if (sb_valid[s][i] && (sb_tag[s][i] == t)) begin
                    exp_hit     = 1'b1;
                    exp_hit_way = sb_way[s][i];
                    blk         = sb_data[s][i];
                    case (wsel)
                        2'b00: exp_read_word = blk[31:0];
                        2'b01: exp_read_word = blk[63:32];
                        2'b10: exp_read_word = blk[95:64];
                        2'b11: exp_read_word = blk[127:96];
                    endcase
                end
            end
        end
    endtask

    task automatic sb_apply_cycle(
        input         do_rst,
        input [31:0]  target_addr,
        input         do_touch,
        input         do_fill,
        input [127:0] new_block
    );
        reg [1:0]   s;
        reg [25:0]  t;
        reg         v_way;
        reg         tmp_valid;
        reg [25:0]  tmp_tag;
        reg [127:0] tmp_data;
        reg         tmp_way;
        begin
            if (do_rst) begin
                if ((sb_count[0] > 0) || (sb_count[1] > 0) || (sb_count[2] > 0) || (sb_count[3] > 0)) begin
                    cov_reset_after_fill = cov_reset_after_fill + 1;
                end
                sb_reset();
            end else if (do_fill) begin
                s = target_addr[5:4];
                t = target_addr[31:6];
                cov_set_fill[s] = cov_set_fill[s] + 1;

                if (sb_count[s] == 0) begin
                    cov_fill_empty_w0 = cov_fill_empty_w0 + 1;
                    sb_valid[s][0] = 1'b1;
                    sb_tag[s][0]   = t;
                    sb_data[s][0]  = new_block;
                    sb_way[s][0]   = 1'b0;
                    sb_count[s]    = 1;
                end else if (sb_count[s] == 1) begin
                    if (sb_way[s][0] == 1'b0) begin
                        cov_fill_empty_w1 = cov_fill_empty_w1 + 1;
                    end else begin
                        cov_fill_empty_w0 = cov_fill_empty_w0 + 1;
                    end
                    sb_valid[s][1] = 1'b1;
                    sb_tag[s][1]   = t;
                    sb_data[s][1]  = new_block;
                    sb_way[s][1]   = ~sb_way[s][0];
                    sb_count[s]    = 2;
                end else begin
                    // Evict LRU entry [0]; shift MRU [1] -> [0]; place new block at MRU [1]
                    v_way = sb_way[s][0];
                    if (v_way == 1'b0) begin
                        cov_evict_w0 = cov_evict_w0 + 1;
                    end else begin
                        cov_evict_w1 = cov_evict_w1 + 1;
                    end
                    sb_valid[s][0] = sb_valid[s][1];
                    sb_tag[s][0]   = sb_tag[s][1];
                    sb_data[s][0]  = sb_data[s][1];
                    sb_way[s][0]   = sb_way[s][1];

                    sb_valid[s][1] = 1'b1;
                    sb_tag[s][1]   = t;
                    sb_data[s][1]  = new_block;
                    sb_way[s][1]   = v_way;
                end
            end else if (do_touch) begin
                s = target_addr[5:4];
                t = target_addr[31:6];
                cov_set_touch[s] = cov_set_touch[s] + 1;
                if ((sb_count[s] == 2) && sb_valid[s][0] && (sb_tag[s][0] == t)) begin
                    if (sb_way[s][0] == 1'b0) begin
                        cov_touch_lru_to_mru_w0 = cov_touch_lru_to_mru_w0 + 1;
                    end else begin
                        cov_touch_lru_to_mru_w1 = cov_touch_lru_to_mru_w1 + 1;
                    end
                    // LRU entry touched: promote [0] to MRU [1], demote [1] to LRU [0]
                    tmp_valid      = sb_valid[s][0];
                    tmp_tag        = sb_tag[s][0];
                    tmp_data       = sb_data[s][0];
                    tmp_way        = sb_way[s][0];

                    sb_valid[s][0] = sb_valid[s][1];
                    sb_tag[s][0]   = sb_tag[s][1];
                    sb_data[s][0]  = sb_data[s][1];
                    sb_way[s][0]   = sb_way[s][1];

                    sb_valid[s][1] = tmp_valid;
                    sb_tag[s][1]   = tmp_tag;
                    sb_data[s][1]  = tmp_data;
                    sb_way[s][1]   = tmp_way;
                end else if (((sb_count[s] == 2) && sb_valid[s][1] && (sb_tag[s][1] == t)) ||
                           ((sb_count[s] == 1) && sb_valid[s][0] && (sb_tag[s][0] == t))) begin
                    cov_touch_mru_noop = cov_touch_mru_noop + 1;
                end else begin
                    cov_touch_miss_noop = cov_touch_miss_noop + 1;
                end
            end
        end
    endtask

    task automatic dump_set_state(input [1:0] s);
        begin
            $display("  Scoreboard Set %0d (count=%0d):", s, sb_count[s]);
            $display("    [0/LRU] valid=%b way=%b tag=0x%07x data=0x%032x",
                     sb_valid[s][0], sb_way[s][0], sb_tag[s][0], sb_data[s][0]);
            $display("    [1/MRU] valid=%b way=%b tag=0x%07x data=0x%032x",
                     sb_valid[s][1], sb_way[s][1], sb_tag[s][1], sb_data[s][1]);
        end
    endtask

    task automatic verify_combinational(
        input string  phase_name,
        input [31:0]  target_addr
    );
        reg        exp_hit;
        reg        exp_hit_way;
        reg [31:0] exp_read_word;
        reg        exp_victim_way;
        reg [1:0]  s;
        reg [1:0]  wsel;
        begin
            s    = target_addr[5:4];
            wsel = target_addr[3:2];
            sb_lookup(target_addr, exp_hit, exp_hit_way, exp_read_word, exp_victim_way);

            if (!rst && !touch_en && !fill_en) begin
                cov_comb_lookup_no_en = cov_comb_lookup_no_en + 1;
            end

            if (exp_hit) begin
                if (exp_hit_way == 1'b0) begin
                    cov_hit_way0      = cov_hit_way0 + 1;
                    cov_word_w0[wsel] = cov_word_w0[wsel] + 1;
                end else begin
                    cov_hit_way1      = cov_hit_way1 + 1;
                    cov_word_w1[wsel] = cov_word_w1[wsel] + 1;
                end
            end

            check_count = check_count + 4;
            if ((hit        !== exp_hit)        ||
                (hit_way    !== exp_hit_way)    ||
                (read_word  !== exp_read_word)  ||
                (victim_way !== exp_victim_way)) begin
                $display("==================================================================");
                $display("[FAIL] Mismatch at step=%0d phase=%s seed=0x%08x (%0d)",
                         step_id, phase_name, seed_used, seed_used);
                $display("  addr=0x%08x (tag=0x%07x set=%0d word=%0d) touch_en=%b fill_en=%b rst=%b",
                         target_addr, target_addr[31:6], s, target_addr[3:2], touch_en, fill_en, rst);
                $display("  DUT : hit=%b hit_way=%b read_word=0x%08x victim_way=%b",
                         hit, hit_way, read_word, victim_way);
                $display("  EXP : hit=%b hit_way=%b read_word=0x%08x victim_way=%b",
                         exp_hit, exp_hit_way, exp_read_word, exp_victim_way);
                dump_set_state(s);
                $display("==================================================================");
                $fatal(1, "Scoreboard mismatch detected");
            end
        end
    endtask

    task automatic exec_reset();
        integer s;
        begin
            step_id = step_id + 1;
            op_count = op_count + 1;
            @(negedge clk);
            rst        = 1'b1;
            touch_en   = 1'b0;
            fill_en    = 1'b0;
            fill_block = 128'd0;
            @(negedge clk);
            rst = 1'b0;
            sb_apply_cycle(1'b1, addr, 1'b0, 1'b0, 128'd0);

            for (s = 0; s < NUM_SETS; s = s + 1) begin
                addr = make_addr(26'h000001, s[1:0], 2'b00);
                #1;
                verify_combinational("post_reset_cold", addr);
            end
        end
    endtask

    task automatic exec_lookup_only(
        input [25:0] tag,
        input [1:0]  set_idx,
        input [1:0]  word_sel
    );
        begin
            step_id = step_id + 1;
            op_count = op_count + 1;
            @(negedge clk);
            addr       = make_addr(tag, set_idx, word_sel);
            touch_en   = 1'b0;
            fill_en    = 1'b0;
            fill_block = 128'd0;
            #1;
            verify_combinational("comb_lookup_pre_clk", addr);
            @(negedge clk);
            #1;
            verify_combinational("comb_lookup_post_clk", addr);
        end
    endtask

    task automatic exec_touch(
        input [25:0] tag,
        input [1:0]  set_idx,
        input [1:0]  word_sel
    );
        begin
            step_id = step_id + 1;
            op_count = op_count + 1;
            @(negedge clk);
            addr       = make_addr(tag, set_idx, word_sel);
            touch_en   = 1'b1;
            fill_en    = 1'b0;
            fill_block = 128'd0;
            #1;
            verify_combinational("touch_pre_clk", addr);
            @(negedge clk);
            touch_en = 1'b0;
            sb_apply_cycle(1'b0, addr, 1'b1, 1'b0, 128'd0);
            #1;
            verify_combinational("touch_post_clk", addr);
        end
    endtask

    task automatic exec_fill(
        input [25:0] tag,
        input [1:0]  set_idx,
        input [1:0]  word_sel
    );
        reg [127:0] blk;
        begin
            step_id = step_id + 1;
            op_count = op_count + 1;
            fill_seq = fill_seq + 32'd1;
            blk      = make_distinct_block(tag, set_idx, fill_seq);
            @(negedge clk);
            addr       = make_addr(tag, set_idx, word_sel);
            touch_en   = 1'b0;
            fill_en    = 1'b1;
            fill_block = blk;
            #1;
            verify_combinational("fill_pre_clk", addr);
            @(negedge clk);
            fill_en = 1'b0;
            sb_apply_cycle(1'b0, addr, 1'b0, 1'b1, blk);
            #1;
            verify_combinational("fill_post_clk", addr);
        end
    endtask

    // Helper: pick a tag not currently resident in set s (legal miss candidate)
    function automatic [25:0] pick_miss_tag(input [1:0] set_idx, input integer start_idx);
        integer k;
        reg [25:0] cand;
        begin
            pick_miss_tag = pool_tag(set_idx, 0);
            for (k = 0; k < TAGS_PER_SET; k = k + 1) begin
                cand = pool_tag(set_idx, (start_idx + k) % TAGS_PER_SET);
                if (!((sb_count[set_idx] >= 1 && sb_tag[set_idx][0] == cand) ||
                      (sb_count[set_idx] >= 2 && sb_tag[set_idx][1] == cand))) begin
                    pick_miss_tag = cand;
                    k = TAGS_PER_SET; // break
                end
            end
        end
    endfunction

    // Probe all resident entries in all 4 sets using pure combinational lookups
    // without asserting touch_en or fill_en, verifying state invariance.
    task automatic sweep_all_sets_combinational();
        integer s, slot, w;
        reg [25:0] miss_t;
        begin
            for (s = 0; s < NUM_SETS; s = s + 1) begin
                for (slot = 0; slot < sb_count[s]; slot = slot + 1) begin
                    for (w = 0; w < 4; w = w + 1) begin
                        addr = make_addr(sb_tag[s][slot], s[1:0], w[1:0]);
                        #1;
                        verify_combinational("sweep_resident_comb", addr);
                    end
                end
                miss_t = pick_miss_tag(s[1:0], 0);
                addr = make_addr(miss_t, s[1:0], 2'b00);
                #1;
                verify_combinational("sweep_miss_comb", addr);
            end
        end
    endtask

    // --------------------------------------------------------------------------
    // Targeted Coverage Suite
    // --------------------------------------------------------------------------
    task automatic run_targeted_coverage_suite();
        integer s, w;
        reg [25:0] t0, t1, t2, t3, t_miss;
        begin
            $display("[PHASE 1] Targeted Coverage Cases (4 sets x 2 ways x 4 word offsets)");

            // Case 1: Empty-way priority (0 -> 1) and all 4 word offsets across both ways in all 4 sets
            exec_reset();
            for (s = 0; s < NUM_SETS; s = s + 1) begin
                t0 = pool_tag(s[1:0], 0);
                t1 = pool_tag(s[1:0], 1);

                // Cold miss lookup without enable -> victim must be Way 0
                exec_lookup_only(t0, s[1:0], 2'b00);

                // First fill -> Way 0; subsequent victim must be empty Way 1
                exec_fill(t0, s[1:0], 2'b00);
                for (w = 0; w < 4; w = w + 1) begin
                    exec_lookup_only(t0, s[1:0], w[1:0]);
                end

                // Second fill -> Way 1; set now full, Way 0 is LRU victim
                exec_fill(t1, s[1:0], 2'b00);
                for (w = 0; w < 4; w = w + 1) begin
                    exec_lookup_only(t1, s[1:0], w[1:0]);
                end
            end

            // Case 2: Both victim directions, touch-on-LRU, touch-on-MRU no-op, touch-on-miss no-op
            t0     = pool_tag(2'd0, 0); // Currently LRU in Set 0 (Way 0)
            t1     = pool_tag(2'd0, 1); // Currently MRU in Set 0 (Way 1)
            t2     = pool_tag(2'd0, 2);
            t3     = pool_tag(2'd0, 3);
            t_miss = pool_tag(2'd0, 5);

            // Touch already-MRU Way 1 (victim stays Way 0) and touch miss tag (victim stays Way 0)
            exec_touch(t1, 2'd0, 2'b10);
            exec_touch(t_miss, 2'd0, 2'b01);

            // Evict Way 0 (t0 evicted, t1 preserved in Way 1, t2 enters Way 0 as MRU)
            exec_fill(t2, 2'd0, 2'b11);
            exec_lookup_only(t0, 2'd0, 2'b00); // Verify t0 evicted
            exec_lookup_only(t1, 2'd0, 2'b11); // Verify t1 preserved on Way 1

            // Touch Way 1 (t1, currently LRU) -> victim flips to Way 0; then touch Way 0 (t2) -> flips to Way 1
            exec_touch(t1, 2'd0, 2'b01);
            exec_touch(t2, 2'd0, 2'b10);

            // Evict Way 1 (t1 evicted, t2 preserved in Way 0, t3 enters Way 1 as MRU)
            exec_fill(t3, 2'd0, 2'b00);
            exec_lookup_only(t1, 2'd0, 2'b00); // Verify t1 evicted
            exec_lookup_only(t2, 2'd0, 2'b10); // Verify t2 preserved on Way 0

            // Case 3: Cross-set independence (all 4 sets populated, mutate Sets 1 & 3, verify Sets 0 & 2)
            exec_touch(pool_tag(2'd1, 0), 2'd1, 2'b01); // Flip Set 1 victim to Way 1
            exec_fill(pool_tag(2'd1, 2), 2'd1, 2'b10);  // Evict Way 1 in Set 1
            exec_fill(pool_tag(2'd3, 2), 2'd3, 2'b11);  // Evict Way 0 in Set 3
            @(negedge clk);
            touch_en = 1'b0;
            fill_en  = 1'b0;
            sweep_all_sets_combinational();

            // Case 4: Combinational lookups within a single cycle (no clock edge, no enable)
            @(negedge clk);
            touch_en = 1'b0;
            fill_en  = 1'b0;
            for (w = 0; w < 4; w = w + 1) begin
                addr = make_addr(pool_tag(2'd2, 0), 2'd2, w[1:0]);
                #1;
                verify_combinational("same_cycle_comb_w0", addr);
                addr = make_addr(pool_tag(2'd2, 1), 2'd2, w[1:0]);
                #1;
                verify_combinational("same_cycle_comb_w1", addr);
            end
            addr = make_addr(pool_tag(2'd2, 5), 2'd2, 2'b00);
            #1;
            verify_combinational("same_cycle_comb_miss", addr);

            // Case 5: Reset after full 4-set / 8-way population & clean post-reset refill
            exec_reset();
            for (s = 0; s < NUM_SETS; s = s + 1) begin
                exec_lookup_only(pool_tag(s[1:0], 0), s[1:0], 2'b00);
                exec_lookup_only(pool_tag(s[1:0], 1), s[1:0], 2'b00);
                exec_lookup_only(pool_tag(s[1:0], 2), s[1:0], 2'b00);
                exec_fill(pool_tag(s[1:0], 4), s[1:0], 2'b01);
            end
        end
    endtask

    task automatic report_and_assert_coverage();
        integer i;
        integer missing_bins;
        begin
            missing_bins = 0;
            $display("------------------------------------------------------------------");
            $display("Functional Coverage Report:");
            $display("  Hit Way 0 / Way 1          : %0d / %0d", cov_hit_way0, cov_hit_way1);
            $display("  Way 0 Word Offsets [0..3]  : %0d, %0d, %0d, %0d",
                     cov_word_w0[0], cov_word_w0[1], cov_word_w0[2], cov_word_w0[3]);
            $display("  Way 1 Word Offsets [0..3]  : %0d, %0d, %0d, %0d",
                     cov_word_w1[0], cov_word_w1[1], cov_word_w1[2], cov_word_w1[3]);
            $display("  Empty-Way Fills (W0 / W1)  : %0d / %0d", cov_fill_empty_w0, cov_fill_empty_w1);
            $display("  LRU Evictions   (W0 / W1)  : %0d / %0d", cov_evict_w0, cov_evict_w1);
            $display("  Touch LRU->MRU  (W0 / W1)  : %0d / %0d", cov_touch_lru_to_mru_w0, cov_touch_lru_to_mru_w1);
            $display("  Touch No-Op (MRU / Miss)   : %0d / %0d", cov_touch_mru_noop, cov_touch_miss_noop);
            $display("  Comb Lookups (no enable)   : %0d", cov_comb_lookup_no_en);
            $display("  Reset After Fills          : %0d", cov_reset_after_fill);
            $display("  Per-Set Fills   [0..3]     : %0d, %0d, %0d, %0d",
                     cov_set_fill[0], cov_set_fill[1], cov_set_fill[2], cov_set_fill[3]);
            $display("  Per-Set Touches [0..3]     : %0d, %0d, %0d, %0d",
                     cov_set_touch[0], cov_set_touch[1], cov_set_touch[2], cov_set_touch[3]);

            if (cov_hit_way0 == 0 || cov_hit_way1 == 0) missing_bins = missing_bins + 1;
            for (i = 0; i < 4; i = i + 1) begin
                if (cov_word_w0[i] == 0)   missing_bins = missing_bins + 1;
                if (cov_word_w1[i] == 0)   missing_bins = missing_bins + 1;
                if (cov_set_fill[i] == 0)  missing_bins = missing_bins + 1;
                if (cov_set_touch[i] == 0) missing_bins = missing_bins + 1;
            end
            if (cov_fill_empty_w0 == 0 || cov_fill_empty_w1 == 0) missing_bins = missing_bins + 1;
            if (cov_evict_w0 == 0 || cov_evict_w1 == 0)           missing_bins = missing_bins + 1;
            if (cov_touch_lru_to_mru_w0 == 0 || cov_touch_lru_to_mru_w1 == 0) missing_bins = missing_bins + 1;
            if (cov_touch_mru_noop == 0 || cov_touch_miss_noop == 0) missing_bins = missing_bins + 1;
            if (cov_comb_lookup_no_en == 0 || cov_reset_after_fill == 0) missing_bins = missing_bins + 1;

            if (missing_bins != 0) begin
                $fatal(1, "Coverage check failed: %0d required bins had zero hits", missing_bins);
            end
        end
    endtask

    // --------------------------------------------------------------------------
    // Randomized Fixed-Seed Stress Sequence
    // --------------------------------------------------------------------------
    task automatic run_random_stress(input integer num_steps);
        integer iter;
        reg [31:0] r;
        reg [1:0]  s;
        reg [1:0]  w;
        integer    action;
        reg [25:0] chosen_tag;
        integer    slot_pick;
        begin
            for (iter = 0; iter < num_steps; iter = iter + 1) begin
                r      = next_rand();
                s      = r[1:0];
                w      = r[3:2];
                action = r[11:4] % 100;

                if (action < 3) begin
                    // Periodic reset after fills
                    exec_reset();
                end else if (action < 35) begin
                    // Pure combinational lookup (no state mutation)
                    if ((sb_count[s] > 0) && (r[12] == 1'b1)) begin
                        slot_pick  = (sb_count[s] == 2) ? r[13] : 0;
                        chosen_tag = sb_tag[s][slot_pick];
                    end else begin
                        chosen_tag = pool_tag(s, r[15:13] % TAGS_PER_SET);
                    end
                    exec_lookup_only(chosen_tag, s, w);
                end else if (action < 68) begin
                    // Touch cycle (prefer resident hits, also exercise miss touch_en)
                    if ((sb_count[s] > 0) && (r[15:12] != 4'h0)) begin
                        slot_pick  = (sb_count[s] == 2) ? r[16] : 0;
                        chosen_tag = sb_tag[s][slot_pick];
                    end else begin
                        chosen_tag = pick_miss_tag(s, r[18:16]);
                    end
                    exec_touch(chosen_tag, s, w);
                end else begin
                    // Fill cycle on a non-resident tag (exercises empty priority + both victim ways)
                    chosen_tag = pick_miss_tag(s, r[18:16]);
                    exec_fill(chosen_tag, s, w);
                end

                // Periodic pure combinational cross-set sweep without clock edge
                if ((iter % 100) == 99) begin
                    @(negedge clk);
                    touch_en = 1'b0;
                    fill_en  = 1'b0;
                    sweep_all_sets_combinational();
                end
            end
        end
    endtask

    // --------------------------------------------------------------------------
    // Main Entrypoint
    // --------------------------------------------------------------------------
    initial begin
        seed_used = DEFAULT_SEED;
        if ($value$plusargs("SEED=%d", seed_used)) begin
            $display("[INFO] Using runtime +SEED=%0d (0x%08x)", seed_used, seed_used);
        end else begin
            $display("[INFO] Using default fixed SEED=%0d (0x%08x)", seed_used, seed_used);
        end
        rng_state = (seed_used == 32'd0) ? DEFAULT_SEED : seed_used;
        fill_seq  = 32'd0;

        rst        = 1'b0;
        addr       = 32'd0;
        touch_en   = 1'b0;
        fill_en    = 1'b0;
        fill_block = 128'd0;
        init_coverage();
        sb_reset();

        $display("==================================================================");
        $display("Starting Independent Stress Verification: cache_2way_store");
        $display("==================================================================");

        run_targeted_coverage_suite();
        $display("[PHASE 2] Fixed-Seed Randomized Stress (%0d steps)", STRESS_STEPS);
        exec_reset();
        run_random_stress(STRESS_STEPS);
        sweep_all_sets_combinational();

        report_and_assert_coverage();

        $display("==================================================================");
        $display("Stress Verification Summary:");
        $display("  Seed       : 0x%08x (%0d)", seed_used, seed_used);
        $display("  Operations : %0d", op_count);
        $display("  Checks     : %0d (0 failed)", check_count);
        $display("==================================================================");
        $display("TEST RESULT: ALL %0d CHECKS PASSED SUCCESSFULLY", check_count);
        $finish(0);
    end

endmodule
