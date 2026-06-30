# Real reviewer 2.1 experiment

Run `run_reviewer2_1_real.m` in MATLAB R2018a.

The code uses YALMIP/CPLEX for follower and LinDistFlow optimization and
MATPOWER AC power flow for all 24 hourly verification points. Values are not
post-processed, scaled, or aligned to manuscript targets.

Important: this is a reconstructed implementation of the mathematical model
because the copied `Stackelberg_Game_Solver.m` contains no CPLEX call. All
assumptions are explicit in `r21_build_data.m` and can be audited.
