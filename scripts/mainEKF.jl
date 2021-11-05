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
#Δt      = 1*60 # [sec]
#ts      = range(t0.second + Δt; step = Δt, stop = t0.second + 0.1*86400)
ekf = EKF(xhat0, P0, Q, (σρ^2 + 3*σr^2), σa^2, ts, gpsΔt, gpssim, imusim, scsim; steps2save = 2, lunaPerts = true);

# Run filter
runFilter!(ekf)

# Get true trajectory for plotting
xtrue = zeros(length(ekf.txp), 3)
for i in 1:length(ekf.txp)
    (y0l, us) = OptimalEstimationProject.GetStateAndControl(scsim, ekf.txp[i])
    xtrue[i, :] .= y0l[1:3]
end

# Plotting
function plotEKF(ekf, xtrue, n)
    ts   = ekf.txp[1:n]
    xhat = ekf.xhats[1:n, :]
    xt   = xtrue[1:n, :]
    es   = ekf.es[1:n, :]
    σ311 = 3*sqrt.(ekf.Ps[1:n,1])
    σ322 = 3*sqrt.(ekf.Ps[1:n,2])
    σ333 = 3*sqrt.(ekf.Ps[1:n,3])
    σ344 = 3*sqrt.(ekf.Ps[1:n,4])
    σ355 = 3*sqrt.(ekf.Ps[1:n,5])
    σ366 = 3*sqrt.(ekf.Ps[1:n,6])
    σ377 = 3*sqrt.(ekf.Ps[1:n,7])

    mat"""
    ts      = $ts;
    ts      = (ts - $(ekf.scSim.t0))/86400;
    xhat    = $xhat;
    xt      = $xt;
    es      = $es;
    s311    = $σ311;
    s322    = $σ322;
    s333    = $σ333;
    s344    = $σ344;
    s355    = $σ355;
    s366    = $σ366;
    s377    = $σ377;

    figure()
    subplot(3,1,1)
    plot(ts, es(:,1), 'k')
    hold on
    plot(ts, s311, 'r')
    plot(ts, -s311, 'r')
    legend('Estimation Error', 'EKF \$3\\sigma\$', 'Interpreter', 'latex')
    grid on

    subplot(3,1,2)
    plot(ts, es(:,1), 'k')
    hold on
    plot(ts, s322, 'r')
    plot(ts, -s322, 'r')
    grid on

    subplot(3,1,3)
    plot(ts, es(:,3), 'k')
    hold on
    plot(ts, s333, 'r')
    plot(ts, -s333, 'r')
    xlabel("Time, days")
    grid on

    figure()
    subplot(3,1,1)
    plot(ts, es(:,4), 'k')
    hold on
    plot(ts, s344, 'r')
    plot(ts, -s344, 'r')

    subplot(3,1,2)
    plot(ts, es(:,5), 'k')
    hold on
    plot(ts, s355, 'r')
    plot(ts, -s355, 'r')

    subplot(3,1,3)
    plot(ts, es(:,6), 'k')
    hold on
    plot(ts, s366, 'r')
    plot(ts, -s366, 'r')

    figure()
    plot(ts, es(:,7), 'k')
    hold on
    plot(ts, s377, 'r')
    plot(ts, -s377, 'r')

    figure()
    plot3(xhat(:,1),xhat(:,2), xhat(:,3), 'r')
    hold on
    plot3(xt(:,1),xt(:,2),xt(:,3), 'b')
    grid on
    axis equal
    """
end

plotEKF(ekf, xtrue, length(ekf.txp))