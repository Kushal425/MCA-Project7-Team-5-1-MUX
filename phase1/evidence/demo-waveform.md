# Five-Request Demo Waveform Evidence & Eviction Analysis

**Project**: Modern Computer Architecture (Project 7: 2-Way Set-Associative Cache with LRU)
**Author**: Kushal
**Artifact**: `phase1/evidence/cache-2way-demo.vcd` (Generated via `./scripts/generate_demo_waveform.sh`)
**Associated Testbench**: `tb/tb_demo_waveform.sv`

---

## 1. Waveform Signal Hierarchy & Real Paths

To inspect the generated waveform in GTKWave (`gtkwave phase1/evidence/cache-2way-demo.vcd`), add the following internal signal paths:

| Functional Group | Signal Path | Bit Width | Description |
| :--- | :--- | :---: | :--- |
| **Clock & Reset** | `tb_demo_waveform.clk` | 1 | 100 MHz reference clock (10 ns period) |
| | `tb_demo_waveform.rst` | 1 | Synchronous active-high reset |
| **Processor Handshake** | `tb_demo_waveform.dut.req_valid` | 1 | Master request strobe |
| | `tb_demo_waveform.dut.req_ready` | 1 | Cache ready indicator |
| | `tb_demo_waveform.dut.req_addr` | 32 | Requested byte address |
| | `tb_demo_waveform.dut.saved_addr` | 32 | Latched transaction address |
| | `tb_demo_waveform.dut.state` | 2 | FSM State (00: IDLE, 01: LOOKUP, 10: REFILL, 11: RESP) |
| **Cache Response** | `tb_demo_waveform.dut.resp_valid` | 1 | Exact 1-cycle response pulse |
| | `tb_demo_waveform.dut.resp_hit` | 1 | 1 = Hit, 0 = Miss |
| | `tb_demo_waveform.dut.resp_data` | 32 | Delivered 32-bit word |
| **Memory Refill Bus** | `tb_demo_waveform.dut.mem_block_addr` | 32 | 16-byte aligned refill base address |
| | `tb_demo_waveform.dut.mem_block_data`| 127:0| 128-bit block data from memory model |
| **Tag & Hit Datapath** | `tb_demo_waveform.dut.u_store.way0_match` | 1 | Way 0 tag match indicator |
| | `tb_demo_waveform.dut.u_store.way1_match` | 1 | Way 1 tag match indicator |
| | `tb_demo_waveform.dut.u_store.hit` | 1 | Combinational hit detection |
| | `tb_demo_waveform.dut.u_store.hit_way` | 1 | Way that hit (0 = Way 0, 1 = Way 1) |
| **Replacement & Recency**| `tb_demo_waveform.dut.u_store.touch_en` | 1 | Strobe asserting hit recency update |
| | `tb_demo_waveform.dut.u_store.fill_en` | 1 | Strobe asserting refill write and LRU update |
| | `tb_demo_waveform.dut.u_store.victim_way` | 1 | Selected way for allocation / eviction |
| | `tb_demo_waveform.dut.u_store.lru_bit[0]`| 1 | **Set 0 LRU Victim Pointer (0: Way 0, 1: Way 1)** |
| **Set 0 Array State** | `tb_demo_waveform.dut.u_store.valid_way0[0]` | 1 | Way 0 valid bit |
| | `tb_demo_waveform.dut.u_store.tag_way0[0]` | 26 | Way 0 tag register |
| | `tb_demo_waveform.dut.u_store.valid_way1[0]` | 1 | Way 1 valid bit |
| | `tb_demo_waveform.dut.u_store.tag_way1[0]` | 26 | Way 1 tag register |

---

## 2. Chronological Cycle-by-Cycle Execution Timeline

The benchmark trace exercises Set 0 with addresses `0x00000000`, `0x00000080`, `0x00000000`, `0x00000100`, `0x00000000`.

| Req # | Target Address | Acceptance Time | State Sequence | Refill / Touch Time | Victim Way | Response Time | Outcome | Returned Data | Post-Req LRU Bit (`lru_bit[0]`) |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Reset**| N/A | $t = 0 - 25\text{ ns}$ | `IDLE` | Deasserted | 0 | N/A | Reset | N/A | `0` (Cleared) |
| **1** | `0x00000000` | $t = 35\text{ ns}$ (Cycle 3) | `LOOKUP` $\rightarrow$ `REFILL` $\rightarrow$ `RESP` | Refill @ $46\text{ ns}$ (`fill_en=1`) | **Way 0** | $t = 56\text{ ns}$ (Cycle 5) | **MISS** (`0`) | `0x00000000` | `1` (Points to Way 1) |
| **2** | `0x00000080` | $t = 75\text{ ns}$ (Cycle 7) | `LOOKUP` $\rightarrow$ `REFILL` $\rightarrow$ `RESP` | Refill @ $86\text{ ns}$ (`fill_en=1`) | **Way 1** | $t = 96\text{ ns}$ (Cycle 9) | **MISS** (`0`) | `0x00000080` | `0` (Points to Way 0) |
| **3** | `0x00000000` | $t = 115\text{ ns}$ (Cycle 11) | `LOOKUP` $\rightarrow$ `RESP` | Touch @ $125\text{ ns}$ (`touch_en=1`) | N/A | $t = 126\text{ ns}$ (Cycle 12) | **HIT** (`1`) | `0x00000000` | **`1` (Flipped to Way 1!)** |
| **4** | `0x00000100` | $t = 145\text{ ns}$ (Cycle 14) | `LOOKUP` $\rightarrow$ `REFILL` $\rightarrow$ `RESP` | Refill enable observed at 156 ns; write at 165 ns | **Way 1** | $t = 166\text{ ns}$ (Cycle 16) | **MISS** (`0`) | `0x00000100` | `0` (Points to Way 0) |
| **5** | `0x00000000` | $t = 185\text{ ns}$ (Cycle 18) | `LOOKUP` $\rightarrow$ `RESP` | Touch @ $195\text{ ns}$ (`touch_en=1`) | N/A | $t = 196\text{ ns}$ (Cycle 19) | **HIT** (`1`) | `0x00000000` | `1` (Points to Way 1) |

---

## 3. The Decisive Eviction Analysis

### Critical Architectural Transition
The pivotal event of the 2-way set-associative cache occurs across **Request 3 and Request 4**:

1. **Pre-Eviction State (End of Request 2, $t = 96\text{ ns}$)**:
   - Way 0 holds `0x00000000` (Tag `0x0000000`, Valid `1`).
   - Way 1 holds `0x00000080` (Tag `0x0000002`, Valid `1`).
   - Because Way 1 was filled last, Set 0's LRU register pointed to **Way 0 as the next candidate for eviction (`lru_bit[0] = 0`)**.
   - *If no hit intervened, a subsequent miss would evict Way 0.*

2. **The Recency Refresh (Request 3, $t = 115\text{ ns} - 126\text{ ns}$)**:
   - Request 3 accesses `0x00000000`. In `STATE_LOOKUP`, Way 0 matches (`way0_match = 1`, `hit = 1`).
   - Concurrently, the controller asserts `touch_en = 1`.
   - On the rising clock edge at $t = 125\text{ ns}$, the LRU logic registers that Way 0 was accessed and updates `lru_bit[0] <= 1'b1`.
   - **Result**: Way 1 (`0x80`) becomes the LRU victim, protecting Way 0 (`0x00`).

3. **The Decisive Eviction (Request 4, $t = 145\text{ ns} - 166\text{ ns}$)**:
   - Request 4 targets `0x00000100` (Tag `0x0000004`, Set 0).
   - In `STATE_LOOKUP`, both ways miss.
   - Transition to `STATE_REFILL`: The storage datapath samples `lru_bit[0] == 1`, driving `victim_way = 1'b1`.
   - **Refill observation**: At $t = 156\text{ ns}$, `fill_en = 1` is observed high. The write occurs at the next rising edge, 165 ns.
   - At the rising clock edge $t = 165\text{ ns}$, `mem_block_data` (`0x10C_0108_0104_0100`) is written into **Way 1**, overwriting the older block `0x80`.
   - **Way 0 (`0x00`) remains completely undisturbed in cache!**

4. **The Payoff (Request 5, $t = 185\text{ ns} - 196\text{ ns}$)**:
   - Request 5 re-reads `0x00000000`.
   - Because Way 0 was shielded from eviction in Step 4, `way0_match` asserts immediately at $t = 185\text{ ns}$.
   - The cache delivers a **HIT (`resp_hit = 1`)** at $t = 196\text{ ns}$ with uncorrupted data `0x00000000`.
   - By contrast, a direct-mapped cache experiences 5 consecutive misses (0% hit rate) due to thrashing Set 0.

---

## 4. Waveform Regeneration Instructions

To regenerate this exact VCD trace from source:
```bash
# From repository root:
./scripts/generate_demo_waveform.sh

# Open in GTKWave:
gtkwave phase1/evidence/cache-2way-demo.vcd
```
