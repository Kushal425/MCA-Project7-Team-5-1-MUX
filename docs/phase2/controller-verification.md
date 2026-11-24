# Phase II Verification Evidence: Controller Protocol & Measured Response Timing

**Contributor:** Apoorva Choudhary (`apoorvachoudhary506@gmail.com`)  
**Branch:** `phase2/apoorva-controller-verification`  
**Module Under Test:** [`rtl/cache_2way.v`](../../rtl/cache_2way.v) (Top-level 2-Way Cache Controller & Datapath, interface unmodified)  
**Testbench Harness:** [`tb/tb_cache_2way.sv`](../../tb/tb_cache_2way.sv)  
**Memory Model:** [`tb/mem_block_model.v`](../../tb/mem_block_model.v)

---

## 1. Controller Architecture & Interface Contracts

The top-level module [`rtl/cache_2way.v`](../../rtl/cache_2way.v) coordinates the request/response handshaking, address latching, parallel tag comparison via [`rtl/cache_2way_store.v`](../../rtl/cache_2way_store.v), refill memory transactions via lower memory, and single-pulse response delivery.

### 1.1 Registered vs. Combinational Signal Classification

| Port / Internal Signal | Type | Driven By / Timing | Architectural Rationale |
| :--- | :---: | :--- | :--- |
| `req_ready` | `output wire` | Combinational: `(state == STATE_IDLE) && (!rst)` | Immediately reflects whether the cache can accept a new request; deasserts instantly upon entering reset or leaving IDLE. |
| `resp_valid` | `output reg` | Registered: latched at `posedge clk` leaving `LOOKUP` (hit) or `REFILL` (miss) | Guaranteed glitch-free single-cycle pulse for clean sampling by synchronous masters. |
| `resp_hit` | `output reg` | Registered: latched at `posedge clk` leaving `LOOKUP` (hit) or `REFILL` (miss) | Holds stable hit classification (`1` = Hit, `0` = Miss) concurrently with `resp_valid`. |
| `resp_data[31:0]` | `output reg` | Registered: latched at `posedge clk` leaving `LOOKUP` (hit) or `REFILL` (miss) | Holds stable 32-bit requested word concurrently with `resp_valid`. |
| `mem_block_addr[31:0]` | `output wire` | Combinational: `{saved_addr[31:4], 4'b0000}` | Driven directly from the registered `saved_addr`; guaranteed 16-byte aligned base address. |
| `saved_addr[31:0]` | Internal `reg` | Registered: latched at `posedge clk` on `req_valid && req_ready` | Freezes the accepted request address; completely isolates internal datapath from external bus mutations. |
| `state[1:0]` | Internal `reg` | Registered: latched at `posedge clk` | Sequences FSM states (`IDLE`, `LOOKUP`, `REFILL`, `RESP`). |
| `touch_en` | Internal `wire` | Combinational: `(state == STATE_LOOKUP) && store_hit` | Pulsed for exactly 1 cycle in `LOOKUP` on hit to update LRU recency in `cache_2way_store`. |
| `fill_en` | Internal `wire` | Combinational: `(state == STATE_REFILL)` | Pulsed for exactly 1 cycle in `REFILL` on miss to write refill block into victim way and update LRU. |

### 1.2 Synchronous Reset Contract

The module implements a synchronous, active-high reset (`rst`) evaluated on the rising edge of `clk`:
1. **Clock-Edge Reset Effects:**
   - `state <= STATE_IDLE`
   - `saved_addr <= 32'h00000000`
   - `resp_valid <= 1'b0`
   - `resp_hit <= 1'b0`
   - `resp_data <= 32'h00000000`
2. **Immediate Combinational Gating:**
   - Because `req_ready = (state == STATE_IDLE) && (!rst)`, `req_ready` is deasserted to `0` whenever `rst` is asserted, preventing request acceptance during reset.
3. **Deassertion Behavior:**
   - When `rst` transitions from `1` to `0`, `req_ready` asserts to `1` within the same clock cycle (since `state == STATE_IDLE`), allowing the cache to accept a request on the very next rising edge.

---

## 2. Controller Finite State Machine (FSM)

The controller transitions through four discrete states:

```
                  +----------------------------------------------+
                  |                                              |
                  v                                              |
             +---------+                                         |
             |  IDLE   |                                         |
             +----+----+                                         |
                  | req_valid && req_ready                       |
                  | [Latch saved_addr <= req_addr]               |
                  v                                              |
            +------------+                                       |
            |   LOOKUP   |                                       |
            +-----+------+                                       |
                  |                                              |
        +---------+---------+                                    |
        | store_hit == 1    | store_hit == 0                     |
        | (Hit)             | (Miss)                             |
        v                   v                                    |
  [touch_en <= 1]      [touch_en <= 0]                           |
        |                   |                                    |
        |             +-----+------+                             |
        |             |   REFILL   |                             |
        |             +-----+------+                             |
        |                   |                                    |
        |                   | [fill_en <= 1]                     |
        |                   | [fill block into victim way]       |
        v                   v                                    |
   +------------------------------+                              |
   |             RESP             |                              |
   |  resp_valid <= 1             |                              |
   |  resp_hit   <= hit ? 1 : 0   |                              |
   |  resp_data  <= word          |                              |
   +--------------+---------------+                              |
                  |                                              |
                  | 1-cycle response pulse complete              |
                  +----------------------------------------------+
```

---

## 3. Measured Response Timing & Latency Analysis

### 3.1 Timing Metric Definitions

- **Acceptance Edge ($E_0$):** The rising clock edge where `req_valid && req_ready` evaluates to `1`. The controller latches `req_addr` into `saved_addr` and advances to `STATE_LOOKUP`.
- **Driver Visibility Edge ($E_{\text{driver}}$):** The rising clock edge at which the controller registers `resp_valid <= 1`. Immediately after this edge ($E_{\text{driver}} + t_{\text{cq}}$), the output signal `resp_valid` is high on the bus wires.
- **Receiver Sampling Edge ($E_{\text{sample}}$):** The subsequent rising clock edge at which an external synchronous master (CPU or testbench) samples `resp_valid == 1`, `resp_hit`, and `resp_data`.

### 3.2 Driver Visibility Edge vs. Receiver Sampling Edge

In synchronous digital systems, a receiver cannot sample a signal on the very clock edge that created it because the signal's value prior to the clock edge was `0` (setup time before the edge was `0`). Therefore:
$$\text{Receiver Sampling Edge} = E_{\text{driver}} + 1 \text{ clock cycle}$$

- **Driver Visibility Latency:** Measures internal FSM processing cycles ($E_0 \rightarrow E_{\text{driver}}$).
- **Receiver Sampling Latency:** Measures end-to-end bus transaction cycles as perceived by the synchronous master ($E_0 \rightarrow E_{\text{sample}}$).

### 3.3 Empirical Timing Measurements

Clock Period: $T = 10\text{ ns}$ ($100\text{ MHz}$).

| Access Scenario | Target Address | Classification | Driver Visibility Edge | Driver Latency | Receiver Sampling Edge | Receiver Latency |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Warm Hit** | `0x00000800` | **HIT** | $E_1$ ($E_0 + 1$ cycle) | **1 cycle (10 ns)** | $E_2$ ($E_0 + 2$ cycles) | **2 cycles (20 ns)** |
| **Cold Miss** | `0x00000800` | **MISS** | $E_2$ ($E_0 + 2$ cycles) | **2 cycles (20 ns)** | $E_3$ ($E_0 + 3$ cycles) | **3 cycles (30 ns)** |

### 3.4 Cycle-by-Cycle Waveform Traces

#### Cold Miss Execution (`0x00000800`)
```
Cycle:          |     0     |     1     |     2     |     3     |     4     |
Clock Edge:     ^ E0        ^ E1        ^ E2        ^ E3        ^ E4
State:          | IDLE      | LOOKUP    | REFILL    | RESP      | IDLE      |
req_valid:      |___/‾‾‾\___|___________|___________|___________|___________|
req_ready:      |‾‾‾\_______|___________|___________|_____/‾‾‾‾‾|‾‾‾‾‾‾‾‾‾‾‾|
saved_addr:     |---< 0x800 >-----------------------------------|-----------|
mem_block_addr: |---< 0x800 >-----------------------------------|-----------|
fill_en:        |___________|___________|___/‾‾‾\___|___________|___________|
resp_valid:     |___________|___________|_____/‾‾‾‾‾\___________|___________|
resp_hit:       |-----------|-----------|-----<  0  >-----------|-----------|
resp_data:      |-----------|-----------|-----<0x800>-----------|-----------|
                ^ Handshake             ^ Driver    ^ Master
                  Accepted                Visible     Samples
```

#### Warm Hit Execution (`0x00000800`)
```
Cycle:          |     0     |     1     |     2     |     3     |
Clock Edge:     ^ E0        ^ E1        ^ E2        ^ E3
State:          | IDLE      | LOOKUP    | RESP      | IDLE      |
req_valid:      |___/‾‾‾\___|___________|___________|___________|
req_ready:      |‾‾‾\_______|___________|_____/‾‾‾‾‾|‾‾‾‾‾‾‾‾‾‾‾|
saved_addr:     |---< 0x800 >-----------------------|-----------|
touch_en:       |___________|___/‾‾‾\___|___________|___________|
resp_valid:     |___________|_____/‾‾‾‾‾\___________|___________|
resp_hit:       |-----------|-----<  1  >-----------|-----------|
resp_data:      |-----------|-----<0x800>-----------|-----------|
                ^ Handshake ^ Driver    ^ Master
                  Accepted    Visible     Samples
```

---

## 4. Targeted Protocol Scenarios & Invariant Verification

The expanded integration testbench [`tb/tb_cache_2way.sv`](../../tb/tb_cache_2way.sv) evaluates 12 rigorous test categories:

### 4.1 In-Flight Reset During LOOKUP (Test 7)
- **Stimulus:** Request to `0x00000500` accepted at $E_0$. During `STATE_LOOKUP`, `rst` is asserted before $E_1$.
- **Observed Behavior:**
  - On $E_1$, the controller immediately returns to `STATE_IDLE`.
  - `resp_valid` remains strictly `0` (transaction aborted without response leakage).
  - `req_ready` remains `0` while `rst` is held.
  - Upon deassertion of `rst`, `req_ready` asserts to `1` in `IDLE`.
  - A follow-up access to `0x00000500` executes normally as a clean cold miss.

### 4.2 In-Flight Reset During REFILL (Test 8)
- **Stimulus:** Request to `0x00000600` accepted at $E_0$, evaluates miss in `LOOKUP` at $E_1$, and enters `REFILL`. Before refill finishes at $E_2$, `rst` is asserted.
- **Observed Behavior:**
  - On $E_2$, the controller immediately aborts `REFILL` and returns to `STATE_IDLE`.
  - Refill write is aborted; `resp_valid` remains strictly `0`.
  - Upon reset release, `req_ready` returns to `1`.
  - Subsequent access to `0x00000600` behaves as a fresh cold miss, proving that no corrupted tag or data remained in the cache.

### 4.3 Busy-Handshake & Follow-Up Holding (Tests 9 & 10)
- **Miss $\rightarrow$ Hit Handover (Test 9):**
  - Master issues Request 1 (`0x00000700`, miss). While the controller is busy in `LOOKUP` and `REFILL`, the master asserts Request 2 (`0x00000704`, spatial hit) and **holds `req_valid = 1` continuously**.
  - `req_ready` remains `0` throughout `LOOKUP`, `REFILL`, and `RESP`.
  - Request 1 delivers `resp_valid = 1` during `RESP`.
  - At the clock edge where Request 1 finishes and FSM enters `IDLE`, `req_ready` rises to `1`.
  - Request 2 is accepted on that exact clock edge without losing any request or bubble cycles.
  - Request 2 completes with `resp_hit = 1` and `resp_data = 0x00000704`.
- **Hit $\rightarrow$ Hit Handover (Test 10):**
  - Master issues Request 3 (`0x00000700`, hit) and holds follow-up Request 4 (`0x00000708`, hit) while busy.
  - Request 4 is held through `LOOKUP` and `RESP`, and accepted cleanly upon entering `IDLE`.

### 4.4 Bus Mutation Isolation & Block Alignment
- In Tests 4 and 11, `req_addr` is intentionally mutated to `0xDEADBEEF`, `0xFFFFFFFF`, and `0x12345678` immediately after acceptance.
- The testbench monitors internal `dut.saved_addr` on every clock cycle:
  - `saved_addr` remains invariant.
  - `mem_block_addr` is verified strictly 16-byte aligned (`mem_block_addr[3:0] == 4'b0000` and `mem_block_addr[31:4] == req_addr[31:4]`).
  - Returned response data and hit classifications are completely unaffected by external bus chatter.

### 4.5 Missing, Duplicate, and Unsolicited Response Protection (Test 12)
- **Unsolicited Response Sweep:** The testbench drives 20 consecutive idle clock cycles with randomized, changing addresses on `req_addr` while `req_valid = 0`. Verified `resp_valid === 1'b0` continuously.
- **End-to-End Accounting:** Synchronous counters monitor all transactions:
  $$\text{total\_accepted\_requests} (28) - \text{total\_aborted\_requests} (2) = \text{total\_completed\_requests} (26)$$
  $$\text{total\_valid\_responses} = 26$$
  - Every completed request produced **strictly one** response pulse.
  - Aborted in-flight requests produced **zero** response pulses.
  - No duplicate or phantom response pulses were observed.

---

## 5. Failure & Timeout Exit Behavior Verification

All testbench assertion checks, ready waits, response waits, and simulation watchdogs in [`tb/tb_cache_2way.sv`](../../tb/tb_cache_2way.sv) invoke `$fatal(1, ...)` upon error:
```systemverilog
    task check(input string msg, input logic condition);
        if (condition) begin
            $display("  [PASS] %s", msg);
            pass_count++;
        end else begin
            $display("  [FAIL] %s", msg);
            fail_count++;
            $fatal(1, "[ASSERTION FAILED] %s", msg);
        end
    endtask
```

### Deliberate Mismatch Negative Check (Temporary Directory)

To verify that the testbench detects real bugs and exits nonzero without modifying repository RTL, a temporary copy of `tb/tb_cache_2way.sv` was executed with a deliberate expectation mismatch (expecting a hit on cold miss Request 1):

```bash
TMP_DIR=$(mktemp -d)
cp tb/tb_cache_2way.sv "$TMP_DIR/tb_cache_2way_buggy.sv"
sed -i '' 's/execute_transaction(32'\''h00000000, 1'\''b0, 32'\''h00000000, 1'\''b0, 32'\''h0, "Demo Req 1 (0x00000000)");/execute_transaction(32'\''h00000000, 1'\''b1, 32'\''h00000000, 1'\''b0, 32'\''h0, "Demo Req 1 (0x00000000)");/' "$TMP_DIR/tb_cache_2way_buggy.sv"

iverilog -g2012 -Wall -s tb_cache_2way -o "$TMP_DIR/sim_buggy.vvp" \
    rtl/cache_2way.v rtl/cache_2way_store.v tb/mem_block_model.v "$TMP_DIR/tb_cache_2way_buggy.sv"
vvp "$TMP_DIR/sim_buggy.vvp"
```

**Observed Terminal Output:**
```text
--- Test 2: Standard 5-Request Benchmark Demo Trace ---
  [PASS] Demo Req 1 (0x00000000): req_ready must be low while busy (cycle 0)
  [PASS] Demo Req 1 (0x00000000): req_ready must be low while busy (cycle 1)
  [PASS] Demo Req 1 (0x00000000): req_ready must be low while busy (cycle 2)
  [PASS] Demo Req 1 (0x00000000): resp_valid asserted within bounds
  [FAIL] Demo Req 1 (0x00000000): hit outcome (exp=1, got=0)
FATAL: /var/folders/.../tb_cache_2way_buggy.sv:102: [ASSERTION FAILED] Demo Req 1 (0x00000000): hit outcome (exp=1, got=0)
       Time: 85000  Scope: tb_cache_2way.check
Deliberate mismatch simulation exited with code: 1
SUCCESS: Deliberate mismatch exited nonzero as expected!
```

---

## 6. Measured Results Summary

### Integration Test Suite Breakdown ([`tb/tb_cache_2way.sv`](../../tb/tb_cache_2way.sv))

| Test Section | Focus Area | Assertions | Passed | Failed |
| :--- | :--- | :---: | :---: | :---: |
| **Test 1** | Synchronous reset & initial protocol invariants | 4 | 4 | 0 |
| **Test 2** | Standard 5-request benchmark trace (40% hit rate) | 35 | 35 | 0 |
| **Test 3** | Nonzero word offsets (Words 0..3) & spatial locality | 77 | 77 | 0 |
| **Test 4** | Request-address mutation resilience under bus chatter | 14 | 14 | 0 |
| **Test 5** | Idle stability & zero phantom responses | 20 | 20 | 0 |
| **Test 6** | Post-reset cold cache restoration | 7 | 7 | 0 |
| **Test 7** | In-flight reset during `STATE_LOOKUP` | 16 | 16 | 0 |
| **Test 8** | In-flight reset during `STATE_REFILL` | 14 | 14 | 0 |
| **Test 9** | Busy handshake: follow-up held during cold miss $\rightarrow$ spatial hit | 15 | 15 | 0 |
| **Test 10** | Busy handshake: follow-up held during warm hit $\rightarrow$ warm hit | 13 | 13 | 0 |
| **Test 11** | Measured response timing & cycle checks (Cold Miss vs Warm Hit) | 18 | 18 | 0 |
| **Test 12** | Missing, duplicate, and unsolicited response protection | 43 | 43 | 0 |
| **Total** | **Full Integration Suite** | **276** | **276** | **0** |

### Full Prototype Verification Suite ([`scripts/run_all.sh`](../../scripts/run_all.sh))

```text
==================================================================
           MCA PROJECT 7: VERIFICATION SUMMARY REPORT
==================================================================
  [PASS] Unit: 2-Way Storage & LRU Datapath
  [PASS] Integration: Top-Level 2-Way Cache & Memory
  [PASS] Baseline: Direct-Mapped Cache Baseline
  [PASS] Comparison: Trace A & Trace B Comparative Harness
  [PASS] Regression: Targeted System Regressions (Reset/LRU/B2B)
------------------------------------------------------------------
 Total Suites Executed : 5
 Passed Suites         : 5
 Failed Suites         : 0
==================================================================
SUCCESS: ALL FIVE TEST SUITES PASSED (EXIT 0)
```

---

## 7. Reproducible Verification Commands

Run from the repository root:

```bash
# 1. Run top-level 2-way cache integration suite (276 assertions)
./scripts/run_cache_2way_integration_test.sh

# 2. Run master verification workflow across all 5 prototype suites
./scripts/run_all.sh

# 3. Deliberate mismatch negative check (must exit with code 1)
TMP_DIR=$(mktemp -d)
cp tb/tb_cache_2way.sv "$TMP_DIR/tb_cache_2way_buggy.sv"
sed -i '' 's/execute_transaction(32'\''h00000000, 1'\''b0, 32'\''h00000000, 1'\''b0, 32'\''h0, "Demo Req 1 (0x00000000)");/execute_transaction(32'\''h00000000, 1'\''b1, 32'\''h00000000, 1'\''b0, 32'\''h0, "Demo Req 1 (0x00000000)");/' "$TMP_DIR/tb_cache_2way_buggy.sv"
iverilog -g2012 -Wall -s tb_cache_2way -o "$TMP_DIR/sim_buggy.vvp" \
    rtl/cache_2way.v rtl/cache_2way_store.v tb/mem_block_model.v "$TMP_DIR/tb_cache_2way_buggy.sv"
vvp "$TMP_DIR/sim_buggy.vvp" ; echo "exit_code=$?"
rm -rf "$TMP_DIR"
```
