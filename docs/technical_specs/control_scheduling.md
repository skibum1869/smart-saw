# Technical Specification: Real-Time Control Scheduling & Task Orchestration

**Document Status:** Formal Algorithmic Discovery  
**Subject:** Mathematical formalization of task priority, concurrency models, and temporal execution constraints within the Intelligence Controller.

---

## I. Execution Architecture

The system implements a **multi-tiered asynchronous orchestration model**. While the high-level application lifecycle is managed via an `asyncio` event loop, mission-critical control tasks are offloaded to dedicated worker threads to prevent blocking of the primary I/O cycles and guarantee temporal determinism for safety functions.

### 1. Concurrency Hierarchy
The task scheduler manages three distinct execution contexts:

*   **Context A (Async Event Loop):** Handles high-level lifecycle management, GUI responsiveness, and non-blocking network communication.
*   **Context B (Dedicated Control Thread):** Runs the `MLController`. This thread manages the heavy mathematical computation of speed optimization and monitors sensor telemetry.
*   **Context C (Safety/Daemon Threads):** Dedicated workers for vision processing (`VisionService`), feature extraction (`LDCWorker`, `DetectionWorker`), and system-level health monitoring.

## II. Priority Scheduler Logic

The controller operates on a **Preemptive Hierarchy**. When the control cycle is triggered, tasks are evaluated against a strict priority ranking to ensure that safety interventions override optimizations.

### 1. Task Priority Ranking (Descending Order)
$$\text{Priority}(\mathcal{P}) = \begin{cases} \text{High} & \mathcal{P} \in \{\text{Torque Guard Intervention}\} \\ \text{Medium} & \mathcal{P} \in \{\text{ML Prediction/Optimization}\} \\ \text{Low} & \mathcal{P} \in \{\text{Standard Data Accumulation}\} \end{cases}$$

### 2. The Safety-First Execution Rule
The `Torque Guard` is evaluated at the start of every control iteration, *before* any machine learning inference occurs. This ensures that if a mechanical stall or obstacle is detected, the system enters its safety state without first waiting for the ML model to process potentially stale data.

**Formal Logic Flow:**
1.  **Intercept:** Sample current torque and height $\to (\tau_c, h_c)$.
2.  **Analyze:** Compare $(\tau_c, h_c)$ against historical trajectory history.
3.  **Branching:**
    *   If Collision-Condition is met: $\text{Execute } \mathcal{P}_{\text{High}}$ (Instant Deceleration) AND **Abort** $\mathcal{P}_{\text{Medium}}$.
    *   Else: Proceed to $\mathcal{P}_{\text{Medium}}$ (ML Inference).

## III. Temporal Constraints & Rate Limiting

The scheduler employs two forms of temporal regulation to ensure system stability and prevent actuator/network saturation.

### 1. Frequency-Domain Regulation (Rate Limiting)
To minimize the frequency of write operations across the Modbus interface, a **Temporal Gating** mechanism is implemented. A command $\mathcal{C}$ is only dispatched if the time elapsed since the last dispatch $T_{last}$ exceeds the minimal update interval $\Delta t_{min}$:
$$\text{Dispatch}(\mathcal{C}) \iff (t_{\text{current}} - T_{\text{last}}) \ge \Delta t_{\text{min}}$$

### 2. Accumulation-based Smoothing (Spatial-Temporal Filtering)
The system utilizes an **Accumulator-Threshold Mechanism** to convert continuous probabilistic outputs into discrete industrial commands. This acts as a temporal low-pass filter:

$$\mathcal{V}_{target} = \sum_{i=1}^{n} \delta v_i$$
$$\text{If } |\mathcal{V}_{target}| > \epsilon \implies \text{Commit}(\mathcal{V}_{target}) \text{ and } \mathcal{V}_{target} \leftarrow 0$$

Where $\epsilon$ is the predefined movement threshold. This ensures that infinitesimal adjustments predicted by the ML ensemble do not induce mechanical wear or oscillation through high-frequency oscillations of the servo motors.
