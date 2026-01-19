# Preemptive Round-Robin Scheduler (ARM Cortex-M0+) — MSPM0G3507 (Assembly)

A tiny **preemptive scheduler** written in **ARM assembly** for a **Cortex-M0+** MCU (TI MSPM0G3507).  
It runs **3 independent tasks** in a **round-robin** order using the **SysTick interrupt** for periodic preemption.

✅ Each task toggles a different GPIO pin: **PB22, PB26, PB27**  
✅ Context switch saves/restores registers **R4–R11** manually  
✅ Hardware automatically stacks **R0–R3, R12, LR, PC, xPSR** (Cortex-M feature)

---

## Architecture

![System Architecture](./media/architecture.png)

---

## Demo

- 🎥 Working demo video: `./media/demo.mp4` (or add your YouTube link here)
- 🎬 Demo GIF: `./media/demo.gif`
- 📈 Logic analyzer output: `./media/logic_analyzer.png`

> You should see three different square waves on PB22/PB26/PB27 (different delays inside each task).

---

## What is inside?

### Why a scheduler?
Normally one `while(1)` loop runs forever.  
A scheduler makes multiple “tasks” *appear* to run at the same time by quickly switching between them.

### What “preemptive” means
Even if Task1 is inside a long delay loop, SysTick can interrupt it and switch to Task2/Task3.

---

## How the task linked-list works (Round Robin)

Each task has a **TCB (Task Control Block)**:

- `TCB.sp`  → saved stack pointer (PSP) for that task  
- `TCB.next` → pointer to the next task’s TCB

So we create a ring:

```mermaid
flowchart LR
  T1[TCB1\nsp = Stack1\nnext = TCB2] --> T2[TCB2\nsp = Stack2\nnext = TCB3]
  T2 --> T3[TCB3\nsp = Stack3\nnext = TCB1]
  T3 --> T1
  C[CurrentTCB] --> T1
