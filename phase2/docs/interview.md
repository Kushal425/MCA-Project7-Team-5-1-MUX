# Phase II Interview Handout

MCA Project 7, Team 5: 1-MUX. **Direct-Mapped vs. Two-Way Set-Associative Cache with LRU.**

Plan for about 19 minutes of speaking and demonstration, plus handoffs. Use the instructor’s timing for the actual interview.

| Order | Speaker | Slides | Rehearsal time | Topic |
| --- | --- | --- | --- | --- |
| 1 | Vani Rudra | 1–3 | 3:40 | Overview, architecture motivation, report and AMAT |
| 2 | Krishna Pramod Dubale | 4–5 | 3:35 | Two-way storage array and one-bit LRU |
| 3 | Apoorva Choudhary | 6–7 | 3:40 | Four-state controller FSM and verification |
| 4 | Prachee Dhar | 8–10 | 3:50 | Direct-mapped baseline and comparative benchmarks |
| 5 | Kushal Sarkar | 11–13 | 4:00 | System integration, live demo, waveform and FPGA status |

## What to have open

- [Presentation](../presentation/MCA-Project7-Presentation.pptx)
- [Compiled IEEE report](../report/phase2-report.pdf)
- [Benchmark results](cache-benchmarks.md)
- [Waveform guide](../../phase1/evidence/demo-waveform.md) and [VCD](../../phase1/evidence/cache-2way-demo.vcd)
- [Recorded FPGA results](fpga-results.md)

Use the current checkout for the talk. The controller and comparison suites pass 276 and 376 checks, respectively. The six-suite runner reports 20,193 checks. The waveform generator runs separately.

## 1. Vani Rudra

Overview, architecture motivation, report and AMAT. Slides 1–3. Rehearsal target 3:40.

### Slide 1 (0:50)

**On screen**

Show the title and introduce all five members.

**What to say**

We are Team 5. Our project is 1-MUX, a comparison of two Verilog cache controllers. A cache keeps copies of memory blocks close to the processor. A hit means the requested block is already present. A miss means the controller must refill the block from lower memory. Our question was whether allowing two possible positions in a set improves the hit rate when several addresses compete for space.

### Slide 2 (1:35)

**On screen**

Show the address decomposition table. Point to bit 6, then the common request and response signals.

**What to say**

Both designs hold 128 bytes of data. That is eight blocks of 16 bytes, with four 32-bit words per block. The direct-mapped cache has eight sets and one way in each set. It uses bits [6:4] as its set index and [31:7] as its 25-bit tag. The two-way cache has four sets with two ways each, so its index is [5:4] and its 26-bit tag is [31:6]. Both select the word with bits [3:2]. We hold capacity, block size and workload fixed. The request interface is req_valid and req_ready. The response uses resp_valid, resp_hit and resp_data. That lets us compare the designs under the same transaction rules. Our model serves aligned, read-only requests. It allows one outstanding request and supplies refill data combinationally in simulation.

### Slide 3 (1:15)

**On screen**

Show the AMAT formula and Trace C numbers. Open Table IV or the title page in phase2/report/phase2-report.pdf, then return to the slides.

**What to say**

Average Memory Access Time, or AMAT, is hit time plus miss rate times the additional miss penalty. We use two cycles for a hit and assume 20 extra cycles for a miss in this example. For Trace C, two-way gets 14 hits from 16 reads while direct mapping gets none. The modeled AMAT is 4.5 versus 22.0 cycles, a ratio of about 4.9 for this trace and penalty. It is a model, separate from observed controller latency and routed FPGA clock timing. Our compiled IEEE report brings together the architecture, verification, benchmark results and FPGA measurements. Krishna will now show how the storage array gets those conflict hits.

### Viva questions

- **Why is this a fair comparison?** Both designs receive identical traces and use the same data capacity, block size and handshake. Changing associativity also changes the number of indexed sets, which is part of the comparison.
- **What is AMAT and what do its variables mean?** AMAT = t_hit + (1 − h) × M_p. Here t_hit is 2 cycles, h is hit rate, and M_p is an assumed 20-cycle additional miss penalty.
- **How do you get 4.5 and 22.0?** For Trace C, use 2 + (2/16) × 20 = 4.5 for two-way and 2 + (16/16) × 20 = 22.0 for direct. The 22.0/4.5 ratio is specific to the model and this trace.
- **Why does the tag width change?** With 32 address bits and 4 offset bits, direct uses 3 index bits and 25 tag bits. Two-way uses 2 index bits and 26 tag bits.
- **How do you recognize a valid response?** Sample resp_hit and resp_data when resp_valid is asserted. A miss response still carries the requested word after refill.
- **Where are the results documented?** The compiled report is phase2/report/phase2-report.pdf. It includes separately reported simulation, modeled AMAT and post-route timing results.
- **What is the project objective?** Compare two cache organizations at the same 128-byte data capacity using RTL tests, shared traces and routed FPGA evidence.
- **Why use a tag if you already know the set?** Many memory blocks map to one set. The tag tells which of those blocks currently occupies a selected way.
- **In a full set, how is FIFO different from LRU here?** FIFO follows insertion order. LRU refreshes order on a hit, as shown by read 3 protecting 0x00 in the demo.

## 2. Krishna Pramod Dubale

Two-way storage array and one-bit LRU. Slides 4–5. Rehearsal target 3:35.

### Slide 4 (1:45)

**On screen**

Show the storage diagram. Open rtl/cache_2way_store.v at valid_way0/1, tag_way0/1, data_way0/1 and the parallel match assignments.

**What to say**

Each indexed set has two physical slots. For each way we store a valid bit, a tag and one 128-bit data block. The valid bit says the entry can be used. The tag says which memory block the entry holds. A lookup uses the selected set to read the two ways. Both valid tags are compared with the requested tag in parallel. The overall hit is way0_match OR way1_match. When a way hits, the word multiplexer uses the address word bits to select one 32-bit lane from that way. This organization lets two blocks with the same set index coexist. The store also provides victim_way, so the controller knows where to put a new block.

### Slide 5 (1:50)

**On screen**

Show the five-read table. Point to lru_bit, victim_way, touch_en and fill_en. Open tb/tb_cache_2way_store.sv to show the directed checks.

**What to say**

We keep one LRU bit for each set. A zero names Way 0 as the next victim, while a one names Way 1. The victim logic prefers invalid Way 0, then invalid Way 1, and uses the bit only when both ways are valid. touch_en makes a hitting way most recently used, so the bit points to the other way. fill_en writes the incoming block, records its tag, makes the chosen way valid and points the bit away from that filled way. Follow Set 0: 0x00 fills Way 0 and 0x80 fills Way 1. Reading 0x00 again makes 0x80 the least recently used block. The next read, 0x100, replaces 0x80 in Way 1. The final read of 0x00 hits again, giving two hits out of five. The storage unit test passed 51 checks covering cold start, hit recency updates and eviction cases. The separate reference-model stress suite adds 19,116 checks. Apoorva will now connect the storage operations to the controller states.

### Viva questions

- **Why does one bit implement exact LRU here?** Two valid ways have just two possible recency orders. A bit per set identifies which way is older.
- **What is the priority for victim_way?** Use invalid Way 0, else invalid Way 1, else the way selected by lru_bit.
- **What is the difference between touch_en and fill_en?** touch_en updates recency after a hit. fill_en writes a whole block and its tag and valid bit, then updates recency.
- **Why is saying 'always flip the bit' imprecise?** The assignment points away from the accessed or filled way. The old bit can already point in that direction.
- **Can the ways contain stale tags after reset?** Yes. Clearing valid bits prevents stale tags from registering as hits.
- **What would FIFO do differently on read 3?** FIFO leaves insertion order unchanged on a hit, so it would still treat the originally filled 0x00 as oldest.
- **How is a hit detected?** The index selects a set. A way hits if its valid bit is set and its stored tag equals the request tag. Either matching way produces a two-way hit.
- **Is the LRU bit a count of accesses?** It only encodes recency order. It does not age continuously or count how often a block is accessed.
- **How does direct mapping differ from fully associative placement?** Direct mapping has one candidate slot. Fully associative placement can use any line. Set associativity gives several candidate slots in one indexed set.

## 3. Apoorva Choudhary

Four-state controller FSM and verification. Slides 6–7. Rehearsal target 3:40.

### Slide 6 (1:55)

**On screen**

Show the FSM and identify the hit bypass. Open rtl/cache_2way.v at STATE_IDLE, STATE_LOOKUP, STATE_REFILL, STATE_RESP, saved_addr and req_ready.

**What to say**

The controller accepts one read at a time. In IDLE, req_ready is high when reset is inactive. When req_valid is also high at a rising edge, the controller copies req_addr into saved_addr. The master can then change the live address without changing this transaction. In LOOKUP, the store compares tags using the saved address. A hit skips REFILL and updates recency. A miss enters REFILL, writes the complete 128-bit memory block into the selected way, and updates the corresponding tag and valid and LRU metadata. The response returns the 32-bit word selected by bits [3:2]. On a refill response, resp_hit remains zero because the original lookup missed. The control logic reacts combinationally to inputs such as the tag match, while response outputs come from registers. The controller drives a one-cycle valid response in RESP and then returns to IDLE.

### Slide 7 (1:45)

**On screen**

Show the E0–E3 timing table. Open tb/tb_cache_2way.sv and show the busy-ready check and the four word-lane scenarios.

**What to say**

Use E0 for the acceptance edge. On a hit the response is visible after E1, and the synchronous receiver samples it on E2. On a miss, E1 enters REFILL, the response is visible after E2, and the receiver samples it on E3. That is two or three cycles from acceptance to sampling. This timing relies on the combinational refill model. The testbench checks the four states and their branches, ready staying low while busy, correct hit and miss flags, and words W0 through W3. It also checks that changing req_addr after acceptance cannot change the saved request and that reset clears an in-flight response. The current controller suite passes 276 checks. Prachee will now show the single-way baseline and how both designs behave on the same address traces.

### Viva questions

- **Why latch req_addr into saved_addr?** The input bus belongs to the requester. After acceptance the controller uses the saved address so later input changes cannot alter the current read.
- **When is req_ready high?** In IDLE while reset is inactive. A new request is accepted only when req_valid and req_ready are both high at a rising edge.
- **Why do we count two cycles for a hit and three for a miss?** The hit response is visible after E1 and sampled on E2. The miss takes an extra REFILL cycle, so it is visible after E2 and sampled on E3.
- **What makes the memory model combinational?** mem_block_data is generated from mem_block_addr without a memory clock edge or separate memory-ready cycle.
- **What word does addr[3:2] = 10 select?** Word 2, the third 32-bit lane of the block.
- **Why is resp_hit zero on a successful refill?** The request missed in LOOKUP. Supplying its data from the refill does not turn that original lookup into a hit.
- **What happens if reset arrives while a read is in flight?** On the reset edge the FSM and response registers clear. Valid bits and LRU state reset, and the previous read is abandoned.
- **What is difference between RTL and a testbench?** RTL describes the hardware behavior synthesized into a design. A testbench drives and checks it in simulation.
- **Can the response be backpressured?** There is no response-ready signal. The requester must sample the one-cycle resp_valid pulse.

## 4. Prachee Dhar

Direct-mapped baseline and comparative benchmarks. Slides 8–10. Rehearsal target 3:50.

### Slide 8 (1:00)

**On screen**

Open rtl/cache_direct.v and highlight set_idx = saved_addr[6:4]. Show the 0x00, 0x40 and 0x80 mapping table.

**What to say**

The direct-mapped design uses the same four controller states, request and response rules, 16-byte blocks and 128-byte capacity. Each index names one fixed line. On a miss, the new block overwrites the existing line at that index if it is valid. There is no choice between ways, so a replacement bit is unnecessary. Notice that the index includes bit 6. That bit is part of the tag in two-way. This small difference lets 0x40 land in direct-mapped Set 4 while 0x00 and 0x80 stay in Set 0.

### Slide 9 (1:50)

**On screen**

Show the five-trace hit-rate and AMAT table. Open phase2/docs/cache-benchmarks.md at the comparison table.

**What to say**

Both designs begin empty for each trace and replay five checked-in hexadecimal address files. Trace A is the five-read conflict example. Two-way gets 40 percent and direct gets zero. Their modeled AMAT is 14 versus 22 cycles. Trace B contains six spatial reads, and both get four hits because they refill equal-sized blocks. Trace C alternates two blocks 16 times. Two-way keeps them both after two cold misses and reaches 87.5 percent, while direct misses on every read. Its modeled AMAT is 4.5 versus 22 cycles. Trace D accesses 32 sequential words. Both reach 75 percent because each block gives one miss and three hits. Trace E rotates 0x00, 0x40 and 0x80 for 30 reads. All three compete for two positions in two-way Set 0, yielding no hits. Direct mapping preserves 0x40 in Set 4, so it gets nine hits after the first cold access to that address.

### Slide 10 (1:00)

**On screen**

Show the 89-read aggregate latency. If time permits, run ./scripts/run_cache_compare.sh and point to the final lines.

**What to say**

Across 89 reads per design, we observed 44 hits for two-way and 37 for direct. The average response latency was 2.506 cycles for two-way and 2.584 for direct in the combinational memory simulation. The comparison bench, tb/tb_cache_compare.sv, checks returned words and expected hit or miss outcomes as well as the resulting metrics. It passes 376 checks. The direct baseline's own suite passes another 30. The two-way design wins these two conflict traces, but Trace E tells us that it does not win every address pattern. Kushal will now run the full test suite, show the eviction in the waveform, and explain the FPGA results.

### Viva questions

- **Why does bit 6 matter?** Direct-mapped includes it in addr[6:4], so 0x40 selects Set 4. Two-way uses addr[5:4], so all three addresses in Trace E select Set 0.
- **Why is Trace E a direct-mapped win?** Every two-way request finds the other two blocks occupying the set. Direct mapping separates 0x40 into Set 4, so its last nine appearances hit.
- **What causes the ties in B and D?** The same 16-byte block covers the same adjacent words for both designs. Both designs retain the relevant line until those words are accessed.
- **How many reads make up the experiment?** 5 + 6 + 16 + 32 + 30 = 89 reads per design. Trace E alone contains 30 reads.
- **How are the mean simulated latencies calculated?** (44×2 + 45×3)/89 = 2.506 cycles for two-way. (37×2 + 52×3)/89 = 2.584 for direct, rounded to three decimals.
- **Which files and commands support the comparison?** tb/traces/ stores the five traces, tb/tb_cache_compare.sv applies them, and ./scripts/run_cache_compare.sh runs the comparison.
- **Why compare equal data capacities?** Equal capacity and equal block size keep placement and associativity at the center of the comparison. Metadata and FPGA logic costs can differ.
- **Does a higher hit rate guarantee a faster implementation?** A hit rate change affects miss frequency. Overall time also depends on hit latency, miss penalty, clock period and workload. Compare metrics with their assumptions.
- **Why choose a deterministic memory pattern?** The checker can independently derive the expected word from the aligned address. A wrong lane or address is easier to catch.

## 5. Kushal Sarkar

System integration, live demo, waveform and FPGA status. Slides 11–13. Rehearsal target 4:00.

### Slide 11 (1:10)

**On screen**

Run ./scripts/run_all.sh from the repo root. Point to the six-suite pass summary and the check totals on the slide.

**What to say**

The end-to-end runner invokes the storage unit, storage stress, two-way controller, direct baseline, trace comparison and system regression suites. We expect all six to pass. Their documented counts sum to 20,193. My system regression adds 344 checks, including reset and back-to-back transactions. The waveform generator is separate. Its VCD records the signal changes for the demonstrator, so we can inspect the exact read and eviction instead of relying on the final hit totals alone.

### Slide 12 (1:30)

**On screen**

Open phase1/evidence/cache-2way-demo.vcd in VS Code WaveTrace or GTKWave. Zoom to 115–196 ns and select clk, state, saved_addr, resp_valid, resp_hit, touch_en, fill_en, victim_way and lru_bit.

**What to say**

Watch the third, fourth and fifth requests. At 115 nanoseconds the controller accepts the third request for 0x00. At 125 nanoseconds the hit touches Way 0 and makes Way 1 the next victim. The demo logs that hit at 126 nanoseconds. The fourth request for 0x100 follows IDLE, LOOKUP, REFILL and RESP, with state encodings 00, 01, 10 and 11 before returning to 00. At 156 nanoseconds the refill enable and Way 1 are visible. The write at 165 replaces 0x80 in Way 1. At 166 the demo logs the 0x100 miss. At 196 the fifth request logs a hit on 0x00. That final hit shows that refreshing Way 0 protected the original block.

### Slide 13 (1:20)

**On screen**

Show the FPGA table and scope. Open phase2/docs/fpga-results.md if asked for the raw run.

**What to say**

The repository includes a Vivado Artix-7 flow, and our completed measurements use Yosys and nextpnr on an ECP5 FPGA target. Both meet the 100 megahertz target after routing. Two-way uses 1,817 logic cells and its estimated maximum clock is 102.64 megahertz. Direct uses 548 logic cells and reaches an estimated 137.55 megahertz. This is out-of-context timing for the cores. We did not measure a full board with external memory. The design is read-only, has one outstanding request, and uses combinational refill data in simulation. The result is a trade-off: two ways stop the two-block conflict in Trace C, while the direct implementation uses less logic and reaches a higher estimated clock. Both achieved the same hit rate on the spatial traces. We are ready for questions.

### Viva questions

- **Why does run_all report 20,193?** The six suite counts are 51 + 19,116 + 276 + 30 + 376 + 344. The waveform generator is invoked separately.
- **What exactly happens at 115 ns and 196 ns?** 115 ns is acceptance of read 3 for 0x00. At 196 ns the demo logs the read 5 hit on 0x00. The read 4 miss on 0x100 is logged at 166 ns.
- **Which line is evicted and what evidence proves it?** Way 1's 0x80 is replaced by 0x100 at the 165 ns rising edge. Show fill_en, victim_way, and the surviving 0x00 hit.
- **What is the measured FPGA status?** Completed out-of-context ECP5 place-and-route. At a 100 MHz target, the tools estimated 102.64 MHz and 137.55 MHz. Vivado is a separate optional flow.
- **Why does a higher estimated clock not settle the comparison?** Clock rate is one factor. Workload hit rate, controller latency and external refill delay also affect time per access.
- **What would a write-capable or slower memory design need?** Write policy, data and byte enables, possibly dirty metadata, and a variable-latency memory handshake with wait states and additional verification.
- **What is a critical path?** A limiting timing path in the placed and routed implementation. It contributes to the estimated shortest allowable clock period.
- **Did you measure 137.55 MHz on a board?** It is a nextpnr estimate after routing for the direct-mapped core. The run excluded board I/O and external memory timing.
- **Why was a temporary intentional bug tested?** It demonstrated that the reference model flags an incorrect victim and that the runner exits with failure instead of silently passing.
