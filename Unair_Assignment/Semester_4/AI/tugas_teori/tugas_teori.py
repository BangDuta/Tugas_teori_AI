import numpy as np
import matplotlib.pyplot as plt

# Parameter PSO
n_particles = 10
max_iter = 50
w = 0.5
c1 = 1.5
c2 = 1.5
bounds = [-10, 10]

# Fungsi objektif
def f(x):
    return x**2

# Inisialisasi partikel
np.random.seed(42)  # Untuk reproducibilitas
positions = np.random.uniform(bounds[0], bounds[1], n_particles)
velocities = np.random.uniform(-1, 1, n_particles)
pBest = positions.copy()
pBest_values = np.array([f(x) for x in pBest])
gBest_idx = np.argmin(pBest_values)
gBest = pBest[gBest_idx]
gBest_value = pBest_values[gBest_idx]

# Untuk menyimpan nilai gBest per iterasi
gBest_history = []

# Iterasi PSO
for t in range(max_iter):
    for i in range(n_particles):
        # Update kecepatan
        r1, r2 = np.random.rand(), np.random.rand()
        velocities[i] = w * velocities[i] + c1 * r1 * (pBest[i] - positions[i]) + c2 * r2 * (gBest - positions[i])
        
        # Update posisi
        positions[i] += velocities[i]
        
        # Batasi posisi
        positions[i] = np.clip(positions[i], bounds[0], bounds[1])
        
        # Evaluasi fungsi
        value = f(positions[i])
        
        # Update pBest
        if value < pBest_values[i]:
            pBest[i] = positions[i]
            pBest_values[i] = value
    
    # Update gBest
    gBest_idx = np.argmin(pBest_values)
    gBest = pBest[gBest_idx]
    gBest_value = pBest_values[gBest_idx]
    gBest_history.append(gBest_value)

# 3. Cetak hasil
print(f"Nilai minimum: {gBest_value}")
print(f"Posisi x terbaik: {gBest}")

# 4. Buat grafik
plt.plot(gBest_history)
plt.xlabel('Iterasi')
plt.ylabel('Nilai f(x) Terbaik')
plt.title('Nilai Terbaik per Iterasi')
plt.grid(True)
plt.show()