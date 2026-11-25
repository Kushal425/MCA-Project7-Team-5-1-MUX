# Phase II Verification Evidence: Comparative Cache Benchmarks & Latency Evaluation

**Contributor:** Prachee Dhar (`prachee.dhar2024@nst.rishihood.edu.in`)  
**Branch:** `phase2/prachee-cache-benchmarks`  
**Modules Evaluated:**  
- [`rtl/cache_direct.v`](../../rtl/cache_direct.v) (Direct-Mapped Baseline, 128 bytes, 8 sets x 1 way x 16 B)
- [`rtl/cache_2way.v`](../../rtl/cache_2way.v) (2-Way Set-Associative Cache, 128 bytes, 4 sets x 2 ways x 16 B)
- [`rtl/cache_2way_store.v`](../../rtl/cache_2way_store.v) (Internal storage, tag match & LRU)  
**Verification Harness:** [`tb/tb_cache_compare.sv`](../../tb/tb_cache_compare.sv) & [`tb/tb_cache_direct.sv`](../../tb/tb_cache_direct.sv)  
**Authoritative Trace Directory:** [`tb/traces/`](../../tb/traces/)  
**Execution Script:** [`scripts/run_cache_compare.sh`](../../scripts/run_cache_compare.sh)

---

## 1. Executive Summary

This document presents the rigorous Phase II comparative benchmark evaluation between the **Direct-Mapped Cache baseline** (`cache_direct`) and the **2-Way Set-Associative Cache with LRU** (`cache_2way`). 

Both caches implement identical external interfaces, identical total storage capacity (128 bytes), identical block geometry (16 bytes per block, 4 words per block), and identical synchronous handshaking protocols (`req_valid`/`req_ready` master interface, `resp_valid`/`resp_hit`/`resp_data` response interface).

### Key Architectural Findings:
1. **Associativity Eliminates 2-Block Thrashing:** In conflict workloads where two or more blocks map to the same set (Traces A and C), 2-way set-associativity with LRU replacement achieves up to **87.5% hit rate**, whereas the direct-mapped cache suffers catastrophic 100% conflict eviction (**0.0% hit rate**).
2. **Spatial Locality Parity:** Under purely sequential and within-block access patterns (Traces B and D), both designs perform identically (**66.7%** and **75.0% hit rates**), showing that set indexing differences do not degrade contiguous spatial locality.
3. **Set Indexing Anomaly (Direct-Mapped Outperforms 2-Way):** Under a 3-block repeating cycle (`0x00, 0x40, 0x80`), direct-mapped strictly **outperforms** the 2-way cache (**30.0% vs. 0.0% hit rate**). Because the direct-mapped cache has 8 sets vs. 4 sets in 2-way, address bit 6 acts as an index bit in direct-mapped, placing `0x40` in Set 4 while `0x00` and `0x80` conflict in Set 0. In 2-way, all three blocks map to Set 0, exceeding the 2-way capacity of the set and triggering continuous LRU thrashing.
4. **Latency Characterization:** Across all 89 evaluated trace requests, measured acceptance-to-registered-response latency averages **2.506 cycles/req** for 2-way vs. **2.584 cycles/req** for direct-mapped (12.112 vs. 13.685 cycles under modeled 20-cycle DRAM refill penalty).

---

## 2. Cache Architecture & Address Mapping Comparison

Both caches store 128 bytes of data divided into 8 blocks of 16 bytes each.

```
Byte Address [31:0] Breakdown:
Bits [1:0]  : Byte offset within 32-bit word (assumed aligned 2'b00)
Bits [3:2]  : Word select within 16-byte block (4 words: W0, W1, W2, W3)
```

### 2.1 Geometric Parameter Comparison

| Parameter | Direct-Mapped Baseline (`cache_direct`) | 2-Way Set-Associative (`cache_2way`) |
| :--- | :---: | :---: |
| **Total Capacity** | 128 Bytes (8 blocks) | 128 Bytes (8 blocks) |
| **Block Size** | 16 Bytes (4 words) | 16 Bytes (4 words) |
| **Number of Sets** | **8 Sets** ($2^3$) | **4 Sets** ($2^2$) |
| **Associativity (Ways/Set)**| **1 Way** | **2 Ways** |
| **Set Index Bits** | **`addr[6:4]` (3 bits)** | **`addr[5:4]` (2 bits)** |
| **Tag Bits** | **`addr[31:7]` (25 bits)** | **`addr[31:6]` (26 bits)** |
| **Replacement Policy** | Direct overwrite | True 1-bit LRU per set |
| **Controller FSM** | 4-state (`IDLE`, `LOOKUP`, `REFILL`, `RESP`) | 4-state (`IDLE`, `LOOKUP`, `REFILL`, `RESP`) |

### 2.2 Address Mapping Decomposition for Key Benchmark Addresses

| Address (Hex) | Binary (lower 8 bits) | 2-Way Set `addr[5:4]` | 2-Way Tag `addr[31:6]` | Direct Set `addr[6:4]` | Direct Tag `addr[31:7]` |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `0x00000000` | `0000 0000` | **Set 0** | `0x0000000` | **Set 0** | `0x0000000` |
| `0x00000040` | `0100 0000` | **Set 0** | `0x0000001` | **Set 4** | `0x0000000` |
| `0x00000080` | `1000 0000` | **Set 0** | `0x0000002` | **Set 0** | `0x0000001` |
| `0x000000C0` | `1100 0000` | **Set 0** | `0x0000003` | **Set 4** | `0x0000001` |
| `0x00000100` | `...0 0000` | **Set 0** | `0x0000004` | **Set 0** | `0x0000002` |

> [!IMPORTANT]
> **Correct Mapping Metadata for `0x40` and `0xC0`:**
> - `0x00000040`: `addr[6:4] = 3'b100` (Set 4), `addr[31:7] = 25'd0` (Tag 0).
> - `0x000000C0`: `addr[6:4] = 3'b100` (Set 4), `addr[31:7] = 25'd1` (Tag 1).
> - Therefore, **`0x40` and `0xC0` both map to direct set 4** with tags 0 and 1 respectively.
> - In `cache_2way`, `0x40` and `0xC0` both map to Set 0 with tags 1 and 3 respectively, where they reside simultaneously across Way 0 and Way 1.

---

## 3. Timing, Latency Conventions, and AMAT Formulation

### 3.1 Measured Simulation Latency (Per-Request Acceptance-to-Registered-Response)

Latency is measured in discrete clock cycles from request acceptance to registered response availability:

```
Clock Edge:     T0                T1                T2                T3
                |                 |                 |                 |
clk:            +---+   +---+     +---+   +---+     +---+   +---+     +---+   +---+
                |   |   |   |     |   |   |   |     |   |   |   |     |   |   |   |
req_valid/ready: ---\___/----------------------------------------------------------
                [T0: Req Accepted]

HIT PATH:
state:          ...IDLE |  LOOKUP |  RESP           |  IDLE           |
resp_valid:     ------------------/-----------------\_________________
                                  [T1: Driver Pulse] [T2: Receiver Registers]
                                  <---- 2 Cycles Acceptance-to-Registered ---->

MISS PATH:
state:          ...IDLE |  LOOKUP |  REFILL         |  RESP           |  IDLE
resp_valid:     ------------------------------------/-----------------\________
                                                    [T2: Driver Pulse] [T3: Receiver Registers]
                                  <------- 3 Cycles Acceptance-to-Registered ------->
```

1. **Acceptance Clock Edge ($T_0$):** Rising clock edge where `req_valid && req_ready` evaluates to 1. The controller latches `saved_addr <= req_addr` and enters `STATE_LOOKUP`.
2. **Cache Output Assertion ($T_1$ or $T_2$):** 
   - On a **Hit**, tag comparison completes combinationally during `LOOKUP`; at clock edge $T_1$, the controller enters `STATE_RESP` and asserts `resp_valid <= 1`.
   - On a **Miss**, the controller enters `STATE_REFILL` at $T_1$, combinational memory data is latched, and at clock edge $T_2$, the controller enters `STATE_RESP` and asserts `resp_valid <= 1`.
3. **Receiver Sampling Edge ($T_2$ or $T_3$):** 
   - A synchronous receiver (CPU core or bus master) clocked on the rising clock edge samples `resp_valid == 1` and latches `resp_data` and `resp_hit`.
   - **Hit Latency:** $T_2 - T_0 = \mathbf{2 \text{ clock cycles}}$.
   - **Miss Latency:** $T_3 - T_0 = \mathbf{3 \text{ clock cycles}}$ (under 1-cycle combinational lower memory model).

### 3.2 Distinction: Measured Simulation Cycles vs. Modeled AMAT vs. FPGA Frequency

To ensure academic and professional rigor, three distinct timing domains are explicitly decoupled:

1. **Measured RTL Simulation Cycles:**
   $$\text{Measured Latency} = (\text{Hits} \times 2 + \text{Misses} \times 3) / \text{Total Accesses}$$
   This metric measures the actual hardware pipeline depth when connected to the deterministic 1-cycle memory model (`mem_block_model`).
2. **Modeled AMAT (Average Memory Access Time):**
   $$\text{AMAT} = t_{\text{hit}} + (1 - \text{Hit Rate}) \times M_{\text{penalty}}$$
   Where $t_{\text{hit}} = 2.0 \text{ cycles}$ and assumed DRAM/L2 refill penalty $M_{\text{penalty}} = 20.0 \text{ cycles}$.
   This models system-level CPU stall cycles under realistic off-chip memory latency.
3. **FPGA Clock Frequency:**
   The design is synthesized targeting a 100 MHz clock period ($T_{\text{clk}} = 10 \text{ ns}$). Wall-clock execution time is computed as:
   $$t_{\text{wall-clock}} = \text{Cycles} \times 10 \text{ ns}$$

---

## 4. Benchmark Workload Profiles & Authoritative Traces

All trace addresses are consumed directly from disk in `tb/traces/` using dynamic `$fopen` / `$fgets` line parsing, ensuring complete independence from RTL implementation.

### 4.1 Trace A: 5-Access Conflict Thrashing Baseline (`tb/traces/conflict_trace.hex`)
- **Addresses:** `0x00000000`, `0x00000080`, `0x00000000`, `0x00000100`, `0x00000000`
- **Mapping:** All 3 distinct blocks map to Set 0 in both designs.
- **Architectural Behavior:**
  - `cache_2way`: Holds 2 ways in Set 0. The return to `0x00` hits in Way 0 after `0x80` fills Way 1. (Hit rate: 2/5 = 40.0%).
  - `cache_direct`: Only 1 block per set. Every alternating access evicts the previous block. (Hit rate: 0/5 = 0.0%).

### 4.2 Trace B: 6-Access Within-Block Spatial Locality (`tb/traces/locality_trace.hex`)
- **Addresses:** `0x00000040`, `0x00000044`, `0x00000048`, `0x0000004C`, `0x000000C0`, `0x000000C4`
- **Mapping:** `0x40` and `0xC0` both map to Direct Set 4 (tags 0 and 1); in 2-way both map to Set 0 (tags 1 and 3).
- **Architectural Behavior:** Successive word accesses within refilled blocks (`W0->W1->W2->W3`) produce consecutive spatial hits in both designs. (Hit rate: 4/6 = 66.7%).

### 4.3 Trace C: 16-Access Extended Two-Block Conflict (`tb/traces/conflict_long_trace.hex`)
- **Addresses:** `0x00000000` and `0x00000080` alternating 16 times.
- **Mapping:** Both map to Set 0 in direct-mapped; both map to Set 0 in 2-way.
- **Architectural Behavior:**
  - `cache_2way`: After 2 initial cold misses, both blocks reside stably in Way 0 and Way 1. All remaining 14 accesses hit! (Hit rate: 14/16 = 87.5%).
  - `cache_direct`: Endless ping-pong conflict thrashing. All 16 accesses miss. (Hit rate: 0/16 = 0.0%).

### 4.4 Trace D: 32-Access Full-Capacity Sequential Locality (`tb/traces/sequential_trace.hex`)
- **Addresses:** 32 sequential words across 8 blocks (`0x00` through `0x7C`), covering 128 bytes.
- **Mapping:** Exactly matches the full 128-byte capacity of both caches without any evictions.
- **Architectural Behavior:** In each 4-word block, Word 0 triggers a cold miss refill; Words 1, 2, and 3 are spatial hits. (Hit rate: 24/32 = 75.0% for both designs).

### 4.5 Trace E: 30-Access Mapping-Sensitive 3-Block Cycle (`tb/traces/mapping_sensitive_trace.hex`)
- **Addresses:** `0x00000000`, `0x00000040`, `0x00000080` repeated 10 times (30 accesses).
- **Architectural Analysis:**
  - **In `cache_2way` (4 sets):** All 3 blocks have index `addr[5:4] = 2'b00` (Set 0). Because Set 0 only holds 2 blocks, accessing 3 blocks in round-robin order (`0x00 -> 0x40 -> 0x80 -> 0x00...`) constantly evicts the block that will be requested next under LRU. **Every single access is a miss!** (0 hits / 30 accesses = **0.0% hit rate**).
  - **In `cache_direct` (8 sets):** The set index is `addr[6:4]`.
    - `0x00000000`: `addr[6:4] = 3'b000` (Set 0)
    - `0x00000040`: `addr[6:4] = 3'b100` (**Set 4**)
    - `0x00000080`: `addr[6:4] = 3'b000` (Set 0)
    Notice that **`0x40` maps to Set 4, while only `0x00` and `0x80` share Set 0**.
    Block `0x40` is never touched or evicted by accesses to Set 0! After its initial cold miss on Access 2, **every subsequent access to `0x40` is a guaranteed HIT** (9 hits out of 10 accesses to `0x40`).
    Direct-Mapped achieves **9 hits / 30 accesses (30.0% hit rate, 33.3% steady state)**, decisively beating the 2-way cache!

---

## 5. Measured Benchmark Results

The following table summarizes authentic simulation results executed via `./scripts/run_cache_compare.sh` on Icarus Verilog:

### 5.1 Per-Workload Performance Comparison

| Workload Trace | Reads | 2-Way Hits | Direct Hits | 2-Way Hit Rate | Direct Hit Rate | 2-Way Measured Latency | Direct Measured Latency | 2-Way Modeled AMAT ($M=20$) | Direct Modeled AMAT ($M=20$) | Favored Design |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Trace A (Conflict)** | 5 | 2 | 0 | **40.00%** (2/5) | **0.00%** (0/5) | 2.60 cyc | 3.00 cyc | 14.00 cyc | 22.00 cyc | **2-Way** (+40.0%) |
| **Trace B (Locality)** | 6 | 4 | 4 | **66.67%** (4/6) | **66.67%** (4/6) | 2.33 cyc | 2.33 cyc | 8.67 cyc | 8.67 cyc | **Tie** (Parity) |
| **Trace C (Ext. Conflict)**| 16 | 14 | 0 | **87.50%** (14/16)| **0.00%** (0/16)| 2.13 cyc | 3.00 cyc | 4.50 cyc | 22.00 cyc | **2-Way** (+87.5%) |
| **Trace D (Sequential)** | 32 | 24 | 24 | **75.00%** (24/32)| **75.00%** (24/32)| 2.25 cyc | 2.25 cyc | 7.00 cyc | 7.00 cyc | **Tie** (Parity) |
| **Trace E (Mapping Cycle)**| 30 | 0 | 9 | **0.00%** (0/30) | **30.00%** (9/30)| 3.00 cyc | 2.70 cyc | 22.00 cyc | 16.00 cyc | **Direct** (+30.0%) |

### 5.2 Grand Benchmark Summary (All 5 Workloads Aggregated)

```
==================================================================
            GRAND COMPARATIVE BENCHMARK SUMMARY (ALL 5 TRACES)
==================================================================
  Metric                          2-Way Set-Associative   Direct-Mapped Baseline
  ------------------------------------------------------------------
  Total Reads Evaluated           89                      89
  Total Cache Hits                44                      37
  Total Cache Misses              45                      52
  Aggregate Hit Rate              44/89 (49.44%)           37/89 (41.57%)
  Total Measured Latency Cycles   223                     230
  Average Response Latency        2.506 cycles/req         2.584 cycles/req
  Modeled AMAT (penalty=20 cyc)   12.112 cycles             13.685 cycles
==================================================================
Comparative Verification Complete: 376 Passed, 0 Failed
TEST RESULT: ALL 376 CHECKS PASSED SUCCESSFULLY
```

---

## 6. Self-Checking Testbench & Error Injection Proof

Both `tb_cache_compare.sv` and `tb_cache_direct.sv` enforce non-zero exit and termination via standard SystemVerilog `$fatal(1, ...)` upon:
1. Watchdog timeout expiration.
2. Request acceptance or response timeout (> 100 cycles without ready/valid handshake).
3. Trace file open failure.
4. Any check assertion failure.

### Proof of Deliberate Mismatch Failure:
To prove that mismatch detection fails reliably:
1. An intentional expectation discrepancy was injected into a temporary copy of `tb_cache_compare.sv` (asserting `tw_hits === 999` instead of 2).
2. The simulation terminated immediately at runtime with status code 1:
   ```
   FATAL: tb/tb_temp_mismatch.sv:730: TEST RESULT: 1 CHECKS FAILED
          Time: 4686000  Scope: tb_cache_compare
   ```
3. An intentional mismatch in `tb_cache_direct.sv` (asserting post-reset `0x40` as Hit instead of Miss) similarly terminated with status code 1:
   ```
   FATAL: tb/tb_temp_direct_mismatch.sv:376: TEST RESULT: 1 CHECKS FAILED
          Time: 856000  Scope: tb_cache_direct
   ```

---

## 7. How to Reproduce All Results

Run the verification suites directly from the repository root:

```bash
# 1. Run comparative benchmarks (376 assertions across all 5 traces)
./scripts/run_cache_compare.sh

# 2. Run direct-mapped integration suite (30 assertions)
./scripts/run_cache_direct_test.sh

# 3. Run entire project regression workflow (all 5 suites)
./scripts/run_all.sh
```
