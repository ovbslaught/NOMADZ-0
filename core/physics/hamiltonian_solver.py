#!/usr/bin/env python3
import math
from typing import Callable, Tuple, List

CR2 = 2.0 ** (1.0 / 3.0)
W1 = 1.0 / (2.0 - CR2)
W0 = -CR2 / (2.0 - CR2)

C1 = C4 = W1 / 2.0
C2 = C3 = (W0 + W1) / 2.0
D1 = D3 = W1
D2 = W0

class HamiltonianSolver:
    @staticmethod
    def yoshida4_step(
        q: Tuple[float, float, float],
        v: Tuple[float, float, float],
        dt: float,
        accel_fn: Callable[[Tuple[float, float, float]], Tuple[float, float, float]]
    ) -> Tuple[Tuple[float, float, float], Tuple[float, float, float]]:
        qx, qy, qz = q
        vx, vy, vz = v

        # Stage 1
        qx += vx * (C1 * dt); qy += vy * (C1 * dt); qz += vz * (C1 * dt)
        ax, ay, az = accel_fn((qx, qy, qz))
        vx += ax * (D1 * dt); vy += ay * (D1 * dt); vz += az * (D1 * dt)

        # Stage 2
        qx += vx * (C2 * dt); qy += vy * (C2 * dt); qz += vz * (C2 * dt)
        ax, ay, az = accel_fn((qx, qy, qz))
        vx += ax * (D2 * dt); vy += ay * (D2 * dt); vz += az * (D2 * dt)

        # Stage 3
        qx += vx * (C3 * dt); qy += vy * (C3 * dt); qz += vz * (C3 * dt)
        ax, ay, az = accel_fn((qx, qy, qz))
        vx += ax * (D3 * dt); vy += ay * (D3 * dt); vz += az * (D3 * dt)

        # Stage 4
        qx += vx * (C4 * dt); qy += vy * (C4 * dt); qz += vz * (C4 * dt)

        return (qx, qy, qz), (vx, vy, vz)
