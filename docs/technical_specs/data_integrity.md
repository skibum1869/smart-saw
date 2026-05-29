# Technical Specification: Data Integrity & Persistence Architecture

**Document Status:** Formal Algorithmic Discovery  
**Subject:** Mathematical formalization of the data-persistence layer, ensuring ACID-compliant storage for high-frequency industrial telemetry.

---

## I. Storage Topology

The system utilizes a **Multi-Schema Relational Model** implemented through an asynchronous SQLite engine. Rather than a single monolithic database, the architecture partitions information into specialized domains to prevent contention and ensure scale-out readiness.

### 1. Database Partitioning Strategy
Data is segregated based on its temporal volatility and functional purpose:

| Domain | Subsystem | Volatility | Purpose |
| :--- | :--- | :--- | :--- |
| **`camera.db`** | Computer Vision | High | Stores real-time visual telemetry, wear metrics, and traceability links. |
| **`current_process.db`** | Real-time Control | Very High | Transient state of the current cutting session for rapid retrieval. |
| **`ml_audit.db`** | ML Optimization | Medium | Audit trail of all predictions, input features, and coefficients for model retraining/analysis. |

## II. The Persistence Pipeline

The system implements a **Buffer-to-Disk (B2D)** pattern to decouple high-frequency sensor polling from the latency-prone I/O operations of disk writes.

### 1. Asynchronous Write Operation
To prevent "blocking" of the real-time control loop, all database interactions are performed via an asychronous task queue. The `MLController` does not wait for a write to complete; instead, it dispatches data to an asynchronous worker:

$$\text{Commit}(\text{Data}) \xrightarrow{\text{async}} \text{Disk-Queue} \to \mathcal{D}_{\text{persistence}}$$

### 2. Data Integrity & Atomicity Strategies

**A. ACID Compliance:**
While SQLite supports full **ACID (Atomicity, Consistency, Isolation, Durability)** properties, the system optimizes for high-concurrency through:
*   **Write-Ahead Logging (WAL) Mode:** This allows simultaneous readers and one writer without locking the entire database, essential when the machine is simultaneously generating real-time metrics while logging history.

**B. Traceability Linkage (The Relational Key):**
Every piece of data captured by the subsystems is enriched with a **Traceability Vector** $\mathbf{T}$, ensuring that telemetry can be correlated to specific manufacturing sessions:
$$\mathbf{T} = \{ \text{Kesim\_ID}, \text{Makine\_ID}, \text{Serit\_ID}, \text{Malzeme\_Cinsi} \}$$

Every row in the `wear_history` or `ml_predictions` table is indexed against this vector to allow for precise longitudinal analysis of blade life and model accuracy.

## III. Data Lifecycle Management (DLM)

To prevent storage exhaustion on edge hardware, the system implements a **Periodic Archival/Purge Cycle**.

### 1. Tiered Storage Rotation
The lifecycle follows a three-stage decay:

1.  **Hot Phase:** Live buffers; all data is available for immediate GUI visualization and high-frequency control response.
2.  **Warm Phase:** Data moved from memory to `current_process.db` or local SQLite files; used for end-of-session reporting.
3.  **Cold Phase:** Archival of session history; critical telemetry (like ML audit paths) is permanent, while high-frequency sensor raw data is subject to a retention policy ($\text{Retention} = 30 \text{ days}$).

### 2. Checksum & Validation
To ensure the integrity of historical data during archival, each batch undergoes a checksum verification process before being marked as "Permanent" in the long-term history tables.
