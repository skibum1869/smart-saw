# Technical Specification: Industrial Communication Protocol (Modbus TCP)

**Document Status:** Formal Algorithmic Discovery  
**Subject:** Formalization of the communication-layer interface between the Intelligence Controller and the Programmable Logic Controller (PLC).

---

## I. Protocol Overview

The system utilizes **Modbus TCP/IP** as its primary industrial communication protocol. This provides a high-availability, request-response mechanism for real-time sensor ingestion and movement command transmission.

### 1. Logical Topology
The controller acts as the **Modbus Client**, initiating polling cycles against a remote **Modbus Server (PLC)** at a deterministic interval ($f_s = 10\text{ Hz}$).

## II. Data Ingestion: Sensor Telemetry Pipeline

Sensor data is retrieved via batch-reads to minimize network overhead and ensure temporal consistency across the feature vector.

### 1. Batch Read Specification
To maintain synchronization, the system performs a single wide-scan operation of $44$ contiguous holding registers starting from memory address `1000`. This atomicity prevents "skew" where one sensor is updated while another isn't during the read cycle.

**Scan Parameters:**
* **Start Address:** `1000`
* **Register Count:** `44`
* **Polling Frequency:** $10\text{ Hz}$ ($\Delta t = 100\text{ ms}$)

### 2. Semantic Mapping and Normalization (Scaling Laws)

The raw integer values provided by the PLC arrive in various scales requiring specific normalization functions to transform them into engineering units ($U$). The mapping is defined as follows:

| Sensor Type | Register Index | Scaling Law $\mathcal{S}(x)$ | Resulting Unit |
| :--- | :--- | :--- | :--- |
| **Machine/Band ID** | `1000-1001` | $U = x$ | integer ID |
| **Dimensions (a, b, c, d)** | `1009-1012` | $U = x / 10.0$ | $\text{mm}$ |
| **Head Height** | `1013` | $U = x / 10.0$ | $\text{mm}$ |
| **Motor Current (Band)** | `1015` | $U = x / 10.0$ | $\text{A}$ |
| **Motor Torque** | `1016` | $U = x / 10.0$ | $\%$ |
| **Descent Speed** | `1034` | See *Special Handling* | $\text{mm/min}$ |
| **Band Deviation** | `1024` | $\mathcal{S}(x) = \begin{cases} x/100 & \text{if } x \le 1.5 \\ (x - 65535)/100 & \text{otherwise} \end{cases}$ | $\text{mm}$ |
| **Temperature** | `1025-1028` | $U = x / 10.0$ | $^\circ\text{C}$ |

### 3. Algorithm: Special Handling for Non-Linear Registers

Certain registers utilize a signed-integer representation within an unsigned 16-bit window.

**A. Descent Speed (Signed Magnitude):**
$\text{The value is interpreted as a signed movement vector.}$
$$\mathcal{S}(x) = \begin{cases} x & \text{if } x \le 500 \\ x - 65536 & \text{otherwise} \end{cases}$$

**B. Band Deviation (Signed Offset):**
$\text{To handle positive/negative lateral drift within a single unsigned register:}$
$$\mathcal{S}(x) = \begin{cases} x / 100 & \text{if } x \le 1.5 \\ (x - 65535) / 100 & \text{otherwise} \end{cases}$$

## III. Command Transmission: Actuator Control Loop

The control loop does not act on raw values, but rather writes to specific **Target Registers** which the PLC uses as setpoints for its servo drives.

### 1. Actuator Setpoint Mapping
| Parameter | Target Address | Scaling Law $\mathcal{S}(x)$ | Unit |
| :--- | :--- | :--- | :--- |
| Cutting Speed Target | `2066` | $U = x$ | $\text{m/min}$ |
| Descent Speed Target | `2041` | $U = x / 100.0$ | $\text{mm/min}$ |

### 2. Control Loop Latency and Determinism
The transmission of setpoints is subject to the **Accumulation Threshold** $\epsilon$. This mechanism prevents high-frequency oscillations in velocity by ensuring a significant change must occur before the command is issued:
$$\Delta v_{accum} = \sum \delta v_i \implies \text{If } |\Delta v_{accum}| > \epsilon \text{ then } \text{Write}(v_{target})$$
This provides a software-level damping of the control signal, effectively acting as a digital low-pass filter on the actuator commands.
