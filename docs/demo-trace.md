# Worked Example & Benchmark Trace Analysis

> [!WARNING]
> **STATUS: PREDICTED RESULTS ONLY**
> The state transitions, hit/miss outcomes, and cycle counts documented below are analytical predictions derived from the architectural specification. They must be validated against automated simulation runs in `tb/` before being cited as empirical measurements in reports or presentations.

---

## 1. Trace Overview & Objective

To evaluate the conflict miss reduction enabled by set associativity, we analyze a 5-access memory sequence starting from cold (completely invalid) caches:

$$\text{Trace} = [\, 0\text{x}00000000,\, 0\text{x}00000080,\, 0\text{x}00000000,\, 0\text{x}00000100,\, 0\text{x}00000000 \,]$$

All accesses are aligned 32-bit word reads (`addr[1:0] == 2'b00`).

---

## 2. Address Bit Decomposition

### 2.1 2-Way Set-Associative Cache (`cache_2way`)
- 4 sets $\rightarrow$ 2 set index bits (`addr[5:4]`).
- 16 bytes per block $\rightarrow$ 4 offset bits (`addr[3:0]`). Word select is `addr[3:2]`.
- Tag: remaining 26 bits (`addr[31:6]`).

| Address | Binary (Bits [31:0]) | Tag `[31:6]` | Set `[5:4]` | Word `[3:2]` | Byte Off `[1:0]` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`0x00000000`** | `0000_0000_0000_0000_0000_0000_0000_0000` | `26'd0` (`26'h0000000`) | `2'b00` (Set 0) | `2'b00` (W0) | `2'b00` |
| **`0x00000080`** | `0000_0000_0000_0000_0000_0000_1000_0000` | `26'd2` (`26'h0000002`) | `2'b00` (Set 0) | `2'b00` (W0) | `2'b00` |
| **`0x00000100`** | `0000_0000_0000_0000_0000_0001_0000_0000` | `26'd4` (`26'h0000004`) | `2'b00` (Set 0) | `2'b00` (W0) | `2'b00` |

### 2.2 Direct-Mapped Cache Baseline (`cache_direct`)
- 8 sets $\rightarrow$ 3 set index bits (`addr[6:4]`).
- 16 bytes per block $\rightarrow$ 4 offset bits (`addr[3:0]`). Word select is `addr[3:2]`.
- Tag: remaining 25 bits (`addr[31:7]`).

| Address | Binary (Bits [31:0]) | Tag `[31:7]` | Set `[6:4]` | Word `[3:2]` | Byte Off `[1:0]` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`0x00000000`** | `0000_0000_0000_0000_0000_0000_0000_0000` | `25'd0` (`25'h0000000`) | `3'b000` (Set 0) | `2'b00` (W0) | `2'b00` |
| **`0x00000080`** | `0000_0000_0000_0000_0000_0000_1000_0000` | `25'd1` (`25'h0000001`) | `3'b000` (Set 0) | `2'b00` (W0) | `2'b00` |
| **`0x00000100`** | `0000_0000_0000_0000_0000_0001_0000_0000` | `25'd2` (`25'h0000002`) | `3'b000` (Set 0) | `2'b00` (W0) | `2'b00` |

> **Key Observation**: In both designs, all three addresses map to **Set 0**. This intentionally creates maximal conflict pressure on Set 0.

---

## 3. Predicted Trace Execution: 2-Way Set-Associative Cache

### Initial State (after reset):
- Set 0: Way 0 = `{V:0, Tag:-, Data:-}`, Way 1 = `{V:0, Tag:-, Data:-}`, `lru_bit = 0` (Way 0 is victim).

---

### Step 1: Read `0x00000000`
- **Lookup**: Set 0 checked. Neither way is valid $\rightarrow$ **MISS** (Compulsory).
- **Victim Selection**: Way 0 is invalid $\rightarrow$ `victim_way = 0`.
- **Refill**: Refill block `0x00000000` (`[0x0C, 0x08, 0x04, 0x00]`) into Way 0. Tag `26'd0` written, `V[0] <= 1`.
- **LRU Update**: Way 0 touched $\rightarrow$ `lru_bit <= 1` (Way 1 is next victim).
- **Output**: `resp_hit = 0`, `resp_data = 32'h00000000`.
- **Set 0 State**:
  - Way 0: `{V:1, Tag:0, Block:0x00}` (MRU)
  - Way 1: `{V:0, Tag:-, Block:-}` (LRU victim)

---

### Step 2: Read `0x00000080`
- **Lookup**: Set 0 checked. Way 0 has Tag 0 (does not match Tag 2); Way 1 is invalid $\rightarrow$ **MISS** (Compulsory).
- **Victim Selection**: Way 1 is invalid $\rightarrow$ `victim_way = 1`.
- **Refill**: Refill block `0x00000080` (`[0x8C, 0x88, 0x84, 0x80]`) into Way 1. Tag `26'd2` written, `V[1] <= 1`.
- **LRU Update**: Way 1 touched $\rightarrow$ `lru_bit <= 0` (Way 0 is next victim).
- **Output**: `resp_hit = 0`, `resp_data = 32'h00000080`.
- **Set 0 State**:
  - Way 0: `{V:1, Tag:0, Block:0x00}` (LRU victim)
  - Way 1: `{V:1, Tag:2, Block:0x80}` (MRU)

---

### Step 3: Read `0x00000000`
- **Lookup**: Set 0 checked. Way 0 valid and matches Tag 0 $\rightarrow$ **HIT**!
- **Data Selection**: Word 0 selected from Way 0.
- **LRU Update**: Way 0 touched (`touch_en = 1`) $\rightarrow$ `lru_bit <= 1` (Way 1 becomes next victim).
- **Output**: `resp_hit = 1`, `resp_data = 32'h00000000`.
- **Set 0 State**:
  - Way 0: `{V:1, Tag:0, Block:0x00}` (MRU)
  - Way 1: `{V:1, Tag:2, Block:0x80}` (LRU victim)

> [!IMPORTANT]
> ### Why Request 3 Changes the Eviction on Request 4:
> - **State after Request 2**: Request 2 filled Way 1 (`0x80`), which marked Way 1 as MRU and set `lru_bit = 0`, making **Way 0 (`0x00`) the candidate victim for the next eviction**.
> - **Intervention of Request 3**: When Request 3 accesses `0x00`, it hits in Way 0. Asserting `touch_en` updates the recency state, flipping `lru_bit` from `0` to `1` (marking Way 0 as MRU and **Way 1 as the LRU victim**).
> - **Impact on Request 4**: Without Request 3, the miss on `0x100` at Request 4 would have evicted `0x00` from Way 0. Because of Request 3's recency refresh, Request 4 evicts `0x80` from Way 1 instead.
> - **Consequence for Request 5**: Preserving `0x00` in Way 0 directly enables the second cache hit on Request 5. This vividly demonstrates the performance advantage of LRU set associativity over direct-mapped cache thrashing.

---

### Step 4: Read `0x00000100`
- **Lookup**: Set 0 checked. Way 0 has Tag 0, Way 1 has Tag 2; neither matches Tag 4 $\rightarrow$ **MISS** (Capacity/Conflict).
- **Victim Selection**: Both ways valid $\rightarrow$ victim determined by `lru_bit` (Way 1).
- **Refill**: Way 1 evicted. Refill block `0x00000100` (`[0x10C, 0x108, 0x104, 0x100]`) into Way 1. Tag `26'd4` written.
- **LRU Update**: Way 1 touched $\rightarrow$ `lru_bit <= 0` (Way 0 is next victim).
- **Output**: `resp_hit = 0`, `resp_data = 32'h00000100`.
- **Set 0 State**:
  - Way 0: `{V:1, Tag:0, Block:0x00}` (LRU victim)
  - Way 1: `{V:1, Tag:4, Block:0x100}` (MRU)

---

### Step 5: Read `0x00000000`
- **Lookup**: Set 0 checked. Way 0 valid and matches Tag 0 $\rightarrow$ **HIT**!
- **Data Selection**: Word 0 selected from Way 0.
- **LRU Update**: Way 0 touched (`touch_en = 1`) $\rightarrow$ `lru_bit <= 1` (Way 1 becomes next victim).
- **Output**: `resp_hit = 1`, `resp_data = 32'h00000000`.
- **Set 0 State**:
  - Way 0: `{V:1, Tag:0, Block:0x00}` (MRU)
  - Way 1: `{V:1, Tag:4, Block:0x100}` (LRU victim)

---

### 2-Way Summary:
$$\text{Outcomes} = [\, \text{MISS},\, \text{MISS},\, \mathbf{HIT},\, \text{MISS},\, \mathbf{HIT} \,] \implies \mathbf{2 / 5 \text{ Hits (40\% Hit Rate)}}$$

---

## 4. Predicted Trace Execution: Direct-Mapped Cache Baseline

### Initial State (after reset):
- Set 0: `{V:0, Tag:-, Block:-}`.

---

### Step 1: Read `0x00000000`
- **Lookup**: Set 0 invalid $\rightarrow$ **MISS** (Compulsory).
- **Refill**: Refill block `0x00000000` into Set 0. Tag `25'd0` written, `V <= 1`.
- **Output**: `resp_hit = 0`, `resp_data = 32'h00000000`.
- **Set 0 State**: `{V:1, Tag:0, Block:0x00}`.

---

### Step 2: Read `0x00000080`
- **Lookup**: Set 0 has Tag 0; requested is Tag 1 $\rightarrow$ **MISS** (Conflict).
- **Refill**: Evicts block `0x00` from Set 0! Refill block `0x80`. Tag `25'd1` written.
- **Output**: `resp_hit = 0`, `resp_data = 32'h00000080`.
- **Set 0 State**: `{V:1, Tag:1, Block:0x80}`.

---

### Step 3: Read `0x00000000`
- **Lookup**: Set 0 has Tag 1; requested is Tag 0 $\rightarrow$ **MISS** (Conflict / Thrash).
- **Refill**: Evicts block `0x80` from Set 0! Refill block `0x00`. Tag `25'd0` written.
- **Output**: `resp_hit = 0`, `resp_data = 32'h00000000`.
- **Set 0 State**: `{V:1, Tag:0, Block:0x00}`.

---

### Step 4: Read `0x00000100`
- **Lookup**: Set 0 has Tag 0; requested is Tag 2 $\rightarrow$ **MISS** (Conflict).
- **Refill**: Evicts block `0x00` from Set 0! Refill block `0x100`. Tag `25'd2` written.
- **Output**: `resp_hit = 0`, `resp_data = 32'h00000100`.
- **Set 0 State**: `{V:1, Tag:2, Block:0x100}`.

---

### Step 5: Read `0x00000000`
- **Lookup**: Set 0 has Tag 2; requested is Tag 0 $\rightarrow$ **MISS** (Conflict / Thrash).
- **Refill**: Evicts block `0x100` from Set 0! Refill block `0x00`. Tag `25'd0` written.
- **Output**: `resp_hit = 0`, `resp_data = 32'h00000000`.
- **Set 0 State**: `{V:1, Tag:0, Block:0x00}`.

---

### Direct-Mapped Summary:
$$\text{Outcomes} = [\, \text{MISS},\, \text{MISS},\, \text{MISS},\, \text{MISS},\, \text{MISS} \,] \implies \mathbf{0 / 5 \text{ Hits (0\% Hit Rate)}}$$

---

## 5. Comparative Overview

| Access # | Address | 2-Way Predicted | Direct-Mapped Predicted | Architectural Reason |
| :---: | :---: | :---: | :---: | :--- |
| 1 | `0x00000000` | **MISS** | **MISS** | Compulsory cold miss |
| 2 | `0x00000080` | **MISS** | **MISS** | Compulsory cold miss; 2-way uses Way 1, direct-mapped overwrites Set 0 |
| 3 | `0x00000000` | **HIT** | **MISS** | 2-way preserved `0x00` in Way 0; direct-mapped suffered conflict eviction |
| 4 | `0x00000100` | **MISS** | **MISS** | 2-way LRU evicts `0x80` from Way 1; direct-mapped evicts `0x00` |
| 5 | `0x00000000` | **HIT** | **MISS** | 2-way preserved `0x00` in Way 0; direct-mapped suffered repeated conflict |
| **Total** | | **2 / 5 (40%)** | **0 / 5 (0%)** | **LRU associativity successfully mitigates ping-pong thrashing** |

> [!NOTE]
> When the test suite in `tb/` is developed by Kushal and executed with `iverilog`, the automated checker will compare the simulated waveform outputs against this table.

