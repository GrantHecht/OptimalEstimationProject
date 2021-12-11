using OptimalEstimationProject
using LinearAlgebra
using AstroTime
using MATLAB

# Spacecraft simulator
t0      = TAIEpoch("2021-08-08T12:00:00")
scsim   = SpacecraftSim(t0.second)

# Initial state error variance
σr      = 0.1   # [km]
σv      = 0.01  # [km / s]
σm      = 1e-6  # [kg]
sqrtP0  = Diagonal([σr, σr, σr, σv, σv, σv, σm])
P0      = sqrtP0.^2

# Initial state estimate
(y0true, us) = OptimalEstimationProject.GetStateAndControl(scsim, t0.second)
xhat0   = y0true[1:7] + sqrtP0*randn(7) 

# Measurement time stamps
Δt      = 30        # [sec]
gpsΔt   = 15*60     # [sec]
ts      = range(t0.second + Δt; step = Δt, stop = t0.second + scsim.ts[2]*86400)

# Measurement statistics
σρ      = 1.0e-3 # [km]     Pseudorange noise standard deviation
σr      = 5.0e-3 # [km]     GPS broadcast ephemeris standard deviation
σa      = 1.0e-5 # [km/s^2] Accelerometer noise standard deviation 

# Process noise covariance
R       = Diagonal((σρ^2 + 3*σr^2)*ones(32)) 
Q       = Diagonal([0.0, 0.0, 0.0, 1e-10, 1e-10, 1e-10, 5e-4])

# GPS Simulation Span
startWeek   = 2170
startDay    = 0
endWeek     = 2174
endDay      = 6

# Create GPS simulation object
gpssim = GPSSim(startWeek, startDay, endWeek, endDay; σρ = σρ, σr = σr)

# Create IMU simulation object
imusim = IMUSim(σa)

# Create EKF
ukf = UKF(xhat0, P0, Q, (σρ^2 + 3*σr^2), σa^2, ts, gpsΔt, gpssim, imusim, scsim; steps2save = 2, lunaPerts = true);

OptimalEstimationProject.propagate!(ukf)

# Run filter
#runFilter!(ekf)

# Get true trajectory for plotting
#xtrue = zeros(length(ekf.txp), 3)
#for i in 1:length(ekf.txp)
#    (y0l, us) = OptimalEstimationProject.GetStateAndControl(scsim, ekf.txp[i])
#    xtrue[i, :] .= y0l[1:3]
#end

# Plotting
#plotEKF(ekf, xtrue, length(ekf.txp))