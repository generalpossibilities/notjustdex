# HUS Security Model

## 1. Threat Model

HUS operates under the following trust assumptions:

- **User device is trusted by the user.** The SDK runs on the user's device and the user controls their own biometric data.
- **The Acki Nacki blockchain is trust-but-verify.** Consensus is assumed honest-majority. Smart contract execution is verifiable.
- **The network is untrusted.** All communication occurs over TLS. Validator nodes may be Byzantine.
- **Third-party apps are untrusted.** Apps should not be able to extract information about users beyond the uniqueness result.

---

## 2. Adversary Capabilities

| Adversary | Capabilities | Cannot Do |
|-----------|-------------|-----------|
| Network observer | Read encrypted traffic metadata | Decrypt TLS payloads |
| Malicious validator | Reorder/withhold transactions | Forge ZK proofs |
| Compromised app | Submit any data to HUS contract | Extract raw biometrics from HUS |
| External attacker | MITM, replay requests | Generate valid proof without biometric |
| Sybil attacker | Create many accounts | Bypass biometric uniqueness check |

---

## 3. Privacy Guarantees

### 3.1 Raw Biometric Never Leaves Device

The full biometric vector $V \in \mathbb{R}^{512}$ exists only in the device's memory during capture and projection. After matrix multiplication, the original $V$ cannot be recovered from the projected $V_{obf}$ because the projection is dimension-reducing ($512 \rightarrow 128$) and information-destroying.

### 3.2 Cross-App Unlinkability

Two apps A and B with different seeds $S_A$ and $S_B$ produce different matrices $M_A$ and $M_B$. For the same biometric vector $V$:

$$V_A = V \times M_A \neq V \times M_B = V_B$$

Unless the seeds are related (which they are not — they are independently random), the projected vectors are computationally indistinguishable from random.

### 3.3 Anonymity via ZK Proofs

The ZK proof system (mock in prototype, Halo2/Arkworks in production) proves the statement:

> "I know a vector $V_{obf}$ such that SHA-256$(V_{obf}) = C$ and $\nexists C' \in \text{Registry}$ with $D(V_{obf}, V_{obf}') < T_{match} \land D(V_{obf}, V_{obf}') \geq 0$"

without revealing $V_{obf}$ or $V_{obf}'$. This ensures:
- The prover's biometric data is hidden
- The matched registry entry (if any) is hidden
- The prover's previous submissions are hidden

---

## 4. Cryptographic Guarantees

### 4.1 Commitment Binding

SHA-256 is computationally binding. Given a commitment $C$, it is infeasible to find $V_{obf} \neq V_{obf}'$ such that SHA-256$(V_{obf}) =$ SHA-256$(V_{obf}') = C$.

### 4.2 Commitment Hiding

SHA-256 is preimage-resistant. Given $C$, it is infeasible to recover $V_{obf}$.

### 4.3 Proof Soundness (Production)

With a Groth16 or PLONK proving system, a malicious prover cannot forge a valid proof for a false statement assuming the hardness of the discrete log problem and the security of the trusted setup (or the updable SRS).

---

## 5. Attack Vectors and Mitigations

### 5.1 Replay Attack

**Threat:** An attacker captures a valid submission (commitment + proof) and resubmits it.  
**Mitigation:** The smart contract checks `registry.biometric_hashes.contains(&commitment)` before accepting. Duplicate commitments are rejected.

### 5.2 Biometric Spoofing

**Threat:** An attacker presents a fake biometric (photo, silicone finger, deepfake video).  
**Mitigation:** 
- Hardware-validated sensors (liveness detection)
- Cryptographic signatures from trusted peripherals
- Future: ML-based liveness detection at the capture layer

### 5.3 Statistical Linkage

**Threat:** An attacker with access to multiple app registries attempts to link identities across apps.  
**Mitigation:** Different seeds → different matrices → different projected vectors. Without the projection seed, the commitment reveals nothing about the underlying biometric. The ZK proof reveals even less.

### 5.4 Front-Running

**Threat:** A validator observes a pending uniqueness proof and submits a conflicting proof.  
**Mitigation:** Acki Nacki's parallel execution model includes transaction ordering guarantees. The `user_account` field in the submission prevents account-level replay.

### 5.5 Sybil Attack

**Threat:** An attacker creates many accounts for the same human to gain disproportionate influence.  
**Mitigation:** The uniqueness score threshold (≥ 80) rejects re-registrations of the same biometric. The ZK proof ensures the rejecter cannot determine which account triggered the match.

---

## 6. Production Hardening Checklist

| Item | Priority | Status |
|------|----------|--------|
| Replace mock prover with Halo2/Arkworks | Critical | ⏳ |
| Replace SHA-256 with Poseidon (ZK-friendly) | High | ⏳ |
| Add liveness detection to capture pipeline | High | 📅 |
| Third-party security audit | Critical | 📅 |
| Bug bounty program | Medium | 📅 |
| Formal verification of scoring logic | Medium | 📅 |
| Hardware security module (HSM) for seeds | Low | 📅 |

---

## 7. Responsible Disclosure

If you discover a security vulnerability in HUS, please report it privately to `security@hus-protocol.io`. Please do not disclose vulnerabilities publicly until they have been addressed.

---

## 8. Known Limitations

- **Mock ZK proofs provide no cryptographic security.** Testnet only.
- **SHA-256 is not ZK-friendly.** Production will migrate to Poseidon.
- **No liveness detection is implemented.** Assumes trusted hardware.
- **No formal verification.** Smart contract logic has been manually reviewed.
