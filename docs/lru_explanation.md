# Worked LRU Replacement Explanation & Unit Test Analysis

This document provides a worked walkthrough of the Least-Recently-Used (LRU) state tracking and replacement mechanics implemented in `rtl/cache_2way_store.v`, directly tied to the automated unit verification scenarios in `tb/tb_cache_2way_store.sv` and the benchmark trace in `docs/demo-trace.md`.

---

## 1. Storage Architecture & Invariants

Each of the 4 cache sets in `cache_2way_store` possesses:
- **Way 0 & Way 1 Valid Bits** (`valid_way0[set]`, `valid_way1[set]`): Indicate whether the corresponding tag and data block contain active, valid memory contents.
- **Way 0 & Way 1 Tag Registers** (`tag_way0[set]`, `tag_way1[set]`): Store 26-bit address tags (`addr[31:6]`).
- **Way 0 & Way 1 Data Arrays** (`data_way0[set]`, `data_way1[set]`): Store 128-bit cache blocks (four 32-bit words).
- **Per-Set 1-Bit LRU Pointer** (`lru_bit[set]`):
  - `lru_bit == 1'b0`: Way 0 is Least-Recently Used $\rightarrow$ **Way 0 is candidate victim**.
  - `lru_bit == 1'b1`: Way 1 is Least-Recently Used $\rightarrow$ **Way 1 is candidate victim**.

### Deterministic Victim Selection Rule
When allocating a new block or evicting an old one, `victim_way` is evaluated combinationaly:
$$\text{victim\_way} = \begin{cases} 
0 & \text{if } \neg\text{valid\_way0}[\text{set}] \quad (\text{Empty Way 0 has absolute priority}) \\
1 & \text{else if } \neg\text{valid\_way1}[\text{set}] \quad (\text{Empty Way 1 has second priority}) \\
\text{lru\_bit}[\text{set}] & \text{if both ways are valid} \quad (\text{LRU policy governs eviction})
\end{cases}$$

---

## 2. Worked Walkthrough (Tied to `tb_cache_2way_store.sv`)

### Step 1: Cold Initial State (Test 1)
- **Action**: Reset pulse (`rst = 1`).
- **State**: `valid_way0 = 0`, `valid_way1 = 0`, `lru_bit = 0`.
- **Lookup**: Any address produces `hit = 0`, `hit_way = 0`, `read_word = 32'h00000000`.
- **Victim Selection**: Because Way 0 is invalid, `victim_way = 0`.

---

### Step 2: Empty-Way Priority & First Refill (Test 3)
- **Action**: Present Block A (`tag = 26'h0A`, Set 0) and assert `fill_en = 1`.
- **Refill Destination**: Driven by `victim_way == 0` $\rightarrow$ written into Way 0.
- **Sequential Update**:
  - `valid_way0[0] <= 1'b1`
  - `tag_way0[0]   <= 26'h0A`
  - `lru_bit[0]    <= 1'b1` (Way 0 became Most-Recently Used; Way 1 becomes LRU pointer).
- **Subsequent Lookup**: Block A hits on Way 0 (`hit = 1, hit_way = 0`).
- **Victim Selection for Next Miss**: Because Way 1 is still empty (`!valid_way1[0] == 1`), `victim_way` evaluates combinationaly to **1**. Empty slots are always prioritized before LRU eviction can occur.

---

### Step 3: Second Refill into Empty Way 1 (Test 3)
- **Action**: Present Block B (`tag = 26'h0B`, Set 0) and assert `fill_en = 1`.
- **Refill Destination**: Driven by `victim_way == 1` $\rightarrow$ written into Way 1.
- **Sequential Update**:
  - `valid_way1[0] <= 1'b1`
  - `tag_way1[0]   <= 26'h0B`
  - `lru_bit[0]    <= 1'b0` (Way 1 became Most-Recently Used; Way 0 becomes LRU candidate).
- **State Summary**: Both ways in Set 0 are now valid.
  - Way 0: Block A (LRU victim candidate).
  - Way 1: Block B (MRU).
  - If a miss occurs right now, `victim_way` is **0** (`lru_bit[0] == 0`).

---

### Step 4: The Critical Recency Refresh via `touch_en` (Test 5)
This step directly mirrors the pivotal Step 3 in `docs/demo-trace.md` where re-referencing Block A protects it from being evicted.
- **Pre-Touch State**: `lru_bit[0] == 0` (Way 0 is slated to be evicted on the next miss).
- **Action**: Address Block A (`tag = 26'h0A`, Set 0).
  - Combinational lookup detects `hit = 1, hit_way = 0` (`way0_match = 1`).
  - Cache controller asserts `touch_en = 1` for 1 clock cycle.
- **Sequential Recency Update**:
  - On the rising clock edge with `touch_en && way0_match`, the module sets:
    $$\text{lru\_bit}[0] \le 1'b1$$
  - This marks Way 0 as MRU and flips the candidate victim to **Way 1**!
- **Post-Touch State**:
  - Way 0: Block A (MRU).
  - Way 1: Block B (LRU victim candidate).
  - For any subsequent miss address, `victim_way` now outputs **1**.

---

### Step 5: LRU Eviction of Victim Way (Test 6)
- **Action**: Present new Block C (`tag = 26'h0C`, Set 0) with `fill_en = 1`.
- **Lookup**: Neither Way 0 (`tag 0A`) nor Way 1 (`tag 0B`) matches $\rightarrow$ `hit = 0`.
- **Victim Selection**: Both ways are valid, so `victim_way = lru_bit[0] == 1` (Way 1).
- **Refill Execution**:
  - Block C overwrites Way 1. Tag is updated to `26'h0C`.
  - Recency updates: `lru_bit[0] <= 1'b0` (Way 1 is now MRU; Way 0 is next victim).
- **Post-Eviction Verification**:
  1. **Block A (Way 0)**: Still valid and hits (`hit = 1, hit_way = 0`). **Survived eviction!**
  2. **Block B (Way 1)**: Lookup misses (`hit = 0`). **Evicted cleanly!**
  3. **Block C (Way 1)**: Now valid and hits (`hit = 1, hit_way = 1`).

---

## 3. Set Independence Guarantee (Test 7)
Because each set maintains its own dedicated slice of valid bits (`valid_way0[s]`, `valid_way1[s]`) and LRU pointer (`lru_bit[s]`), operations occurring in Set 0 (fills, hits, evictions) have zero impact on Sets 1, 2, and 3. In Test 7, Set 2 is populated and manipulated without perturbing the contents or recency pointers of Set 0.
