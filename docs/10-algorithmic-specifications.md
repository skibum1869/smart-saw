# Technical Specification: Intelligent Machine Motion & Integrity Monitoring System

**Document Status:** Formal Algorithmic Discovery  
**Date:** 2026-05-29  
**Subject:** Mathematical formalization of the vision-based structural integrity monitoring and high-frequency stochastic motion control subsystems.

---

## I. Subsystem A: Visual-Spatial Structural Integrity Analyzer (VSSIA)

The VSSIA subsystem utilizes a custom-engineered deep learning topology to perform real-time edge localization on moving saw blades, subsequently mapping pixel-level geometry to physical material degradation metrics.

### 1. The Lightweight Dense CNN (LDC) Architecture
The core of the visual detection is a highly optimized convolutional neural network designed for high-speed inference on heterogeneous hardware. It employs a multi-scale approach characterized by a "DXtrem" architecture.

**A. Multi-Scale Feature Extraction:**  
The network utilizes **Dense Blocks**, inheriting the principles of DenseNet, where each layer's feature map is concatenated into subsequent layers via skip connections. This preserves high-resolution spatial information that is typically lost in traditional downsampling architectures.

**B. Attention-Based Multiscale Fusion (`CoFusion`):**  
Rather than simple concatenation of decoders, the architecture implements a specialized **Channel-wise Co-Fusion module**. The fusion process is defined by an attention mechanism:
$$\mathcal{F}_{fused} = \sum_{i=1}^{n} (\text{Sigmoid}(\mathcal{F}_i) \cdot \mathcal{X}_i)$$
where $\mathcal{F}_i$ represents the feature map of scale $i$, and the scaling factor is derived through a learned attention-weighting process. This ensures that the most prominent edge features are prioritized during the reconstruction of the final probability map.

**C. Probability Refinement & Adaptive Thresholding:**  
The network output (a soft sigmoid map) undergoes an adaptive binarization procedure to extract sharp boundaries:
$$\mathcal{B}(x, T) = \begin{cases} 255 & \text{if } x > T \\ 0 & \text{otherwise} \end{cases}$$
where $T$ is a locally computed threshold based on the mean intensity of the Region of Interest (ROI).

### 2. Geometric Wear-to-Metric Mapping
The transition from digital image space to physical health percentage $\mathcal{H}$ follows a deterministic geometric model.

**A. Edge Boundary Localization:**  
Within the designated ROI, let $S$ be the set of all detected edge coordinates $(x_j, y_j)$. The vertical boundary position $Y_{edge}$ is calculated as the mean of the upper decile of sorted Y-coordinates:
$$Y_{edge} = \text{mean}\left(\text{sort}(\{y \in S\}_{10\%})\right)$$

**B. Wear Percentage Formula:**  
The wear percentage $\mathcal{W}$ is derived from the displacement between the detected edge $Y_{edge}$ and the fixed reference datum $Y_{ref}$:
$$\mathcal{W} = \left[ \frac{Y_{edge} - Y_{ref}}{H_{total}} \right] \times 100$$

---

## II. Subsystem B: Stochastic Motion Control & Safety Guardrail (SMC-SG)

The SMC-SG subsystem provides real-time optimization of the saw's movement parameters through a predictive ensemble, overseen by a reactive safety thresholding mechanism.

### 1. Non-Linear Feature Engineering
The SMC-SG subsystem processes raw sensor telemetry into a high-dimensional feature vector $X$ via non-linear mapping and temporal smoothing.

**A. Torque-to-Current Transformation:**  
Because motor torque percentage ($\tau_\%$) lacks direct correlation to electrical load in linear models, we employ a second-order polynomial regression model to estimate current ($i$):
$$i = \alpha(\tau_\%)^2 + \beta(\tau_\%) + \gamma$$
where coefficients $(\alpha, \beta, \gamma)$ are calibrated specifically to the machine's motor characteristics.

**B. Temporal Smoothing (Low-Pass Filtering):**  
To mitigate high-frequency signal noise in the input vector $X$, all features $\xi$ are processed through a sliding window average:
$$\bar{\xi}_t = \frac{1}{N} \sum_{i=0}^{N-1} \xi_{t-i}$$

### 2. Bagging Ensemble Optimization
The motion optimization is modeled as a series of predictions from an ensemble of weak learners (Decision Trees) designed to minimize movement variance through **Bootstrap Aggregating**.

**A. Predictive Coefficient Calculation:**  
The ensemble predicts a scaling coefficient $C$ based on the feature vector $X$:
$$C = \text{Bagging}(\{T_k(X)\}_{k=1}^K)$$
where $T_k$ is an individual tree within the ensemble.

**B. Proportional Speed Adjustment:**  
The output coefficient $C_{final}$ is applied to both vertical ($v_{\downarrow}$) and horizontal ($v_{\rightarrow}$) velocity components using a proportional relationship:
$$\Delta v_{\downarrow} = C_{final}$$
$$\Delta v_{\rightarrow} = \text{Scale}\left(\frac{\Delta v_{\downarrow}}{V_{\text{range}}}\right) \cdot V_{\text{range, max}}$$

To ensure control stability and mitigate actuator jitter, these changes are only broadcast to the hardware (PLC) when the cumulative change exceeds a learned threshold $\epsilon$:
$$|\sum \Delta v| > \epsilon \implies \text{Commit Change}$$

### 3. Reactive Safety Law: The Torque Guard
The system implements an impulse-response safety mechanism that monitors both time-delay and height-wise resistance changes to detect mechanical interference.

**A. History Interpolation:**  
By maintaining a $(H, \tau)$ history buffer, the system identifies the expected torque $\tau_{hist}$ at a target depth $H_{target}$ using linear interpolation:
$$\tau(h) = \tau_1 + (h - h_1)\frac{\tau_2 - \tau_1}{h_2 - h_1}$$

**B. The Trigger Condition:**  
The safety intervention is triggered if the instantaneous torque increase exceeds a critical percentage $\Phi$:
$$\frac{\tau_{current} - \tau_{hist}}{\tau_{hist}} > \Phi$$

Upon trigger, an immediate **Emergency Reduction Factor** $R$ (typically $0.75$) is applied to all current velocity vectors, bypassing the probabilistic ML optimization path to ensure deterministic safety.
