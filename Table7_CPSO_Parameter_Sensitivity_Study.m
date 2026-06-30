clc;
clear;
close all;

% Table 7 sensitivity study for CPSO parameter settings
% MATLAB 2018a compatible
% Outputs:
%   1) Table7_raw_runs.csv
%   2) Table7_summary_table.csv
%   3) Table7_results.mat
%
% Notes:
% - This script is self-contained and does not overwrite your original files.
% - It patches the missing time_data fields required by the uploaded
%   Stackelberg_Game_Solver logic.
% - It adds a stopping rule:
%       stop if relative improvement of best upper-level objective
%       is below 1e-4 for 10 consecutive iterations,
%       or if the iteration cap is reached.
% - The chaos local search is only accepted when it improves the current
%   global best, which fixes the gbest overwrite bug in the uploaded code.

fprintf('=============================================\n');
fprintf('  Table 7 CPSO parameter sensitivity study\n');
fprintf('=============================================\n\n');

settings = [
    30 100;
    50 100;
    80 100;
    50 60;
    50 150
];

nRuns = 20;
stallTol = 1e-4;
stallWindow = 10;

params = local_init_params();
time_data = local_generate_time_data(params);

totalRows = size(settings, 1) * nRuns;
SettingID = cell(totalRows, 1);
NpCol = zeros(totalRows, 1);
ImaxCol = zeros(totalRows, 1);
SeedCol = zeros(totalRows, 1);
BestEEMOCol = zeros(totalRows, 1);
RuntimeCol = zeros(totalRows, 1);
StopIterCol = zeros(totalRows, 1);

rowIdx = 0;

for s = 1:size(settings, 1)
    Np = settings(s, 1);
    Imax = settings(s, 2);

    cpso_params = struct();
    cpso_params.n = Np;
    cpso_params.max_iter = Imax;
    cpso_params.w_max = 0.9;
    cpso_params.w_min = 0.4;
    cpso_params.c1 = 2.0;
    cpso_params.c2 = 2.0;
    cpso_params.chaos_factor = 3.99;

    solver_opts = struct();
    solver_opts.tol = stallTol;
    solver_opts.stall_window = stallWindow;
    solver_opts.verbose = false;

    fprintf('Running setting %d/%d: Np=%d, Imax=%d\n', s, size(settings, 1), Np, Imax);

    for runID = 1:nRuns
        rowIdx = rowIdx + 1;

        rng(runID, 'twister');
        [results, runinfo] = Stackelberg_Game_Solver_Table7(params, time_data, cpso_params, solver_opts);

        SettingID{rowIdx} = sprintf('Np=%d,Imax=%d', Np, Imax);
        NpCol(rowIdx) = Np;
        ImaxCol(rowIdx) = Imax;
        SeedCol(rowIdx) = runID;
        BestEEMOCol(rowIdx) = results.EMO.profit;
        RuntimeCol(rowIdx) = runinfo.runtime_s;
        StopIterCol(rowIdx) = runinfo.stop_iter;
    end
end

rawTable = table(SettingID, NpCol, ImaxCol, SeedCol, BestEEMOCol, RuntimeCol, StopIterCol, ...
    'VariableNames', {'SettingID', 'Np', 'Imax', 'Seed', 'Best_E_EMO_CNY', 'Runtime_s', 'StopIter'});

summaryNp = zeros(size(settings, 1), 1);
summaryImax = zeros(size(settings, 1), 1);
summaryRuns = zeros(size(settings, 1), 1);
summaryBest = zeros(size(settings, 1), 1);
summaryMean = zeros(size(settings, 1), 1);
summaryStd = zeros(size(settings, 1), 1);
summaryCPU = zeros(size(settings, 1), 1);
summaryStop = zeros(size(settings, 1), 1);

for s = 1:size(settings, 1)
    Np = settings(s, 1);
    Imax = settings(s, 2);
    idx = (NpCol == Np) & (ImaxCol == Imax);

    summaryNp(s) = Np;
    summaryImax(s) = Imax;
    summaryRuns(s) = sum(idx);
    summaryBest(s) = max(BestEEMOCol(idx));
    summaryMean(s) = mean(BestEEMOCol(idx));
    summaryStd(s) = std(BestEEMOCol(idx));
    summaryCPU(s) = mean(RuntimeCol(idx));
    summaryStop(s) = mean(StopIterCol(idx));
end

summaryTable = table(summaryNp, summaryImax, summaryRuns, summaryBest, summaryMean, summaryStd, summaryCPU, summaryStop, ...
    'VariableNames', {'Np', 'Imax', 'Runs', 'Best_E_EMO_CNY', 'Mean_E_EMO_CNY', 'Std_Dev', 'Avg_CPU_Time_s', 'Avg_Stop_Iter'});

writetable(rawTable, 'Table7_raw_runs.csv');
writetable(summaryTable, 'Table7_summary_table.csv');
save('Table7_results.mat', 'rawTable', 'summaryTable');

fprintf('\n=============================================\n');
fprintf('Table 7 summary\n');
fprintf('=============================================\n');
disp(summaryTable);

fprintf('\nSaved files:\n');
fprintf('  Table7_raw_runs.csv\n');
fprintf('  Table7_summary_table.csv\n');
fprintf('  Table7_results.mat\n');

%% ========================= Local functions =========================

function params = local_init_params()
    params = struct();
    params.T = 24;

    params.EMO = struct();
    params.EMO.om_coeff = 0.05;
    params.EMO.reo_reward_lambda = 0.35;
    params.EMO.reo_reward_c_base = 0.6;
    params.EMO.reo_reward_c_volt = 80;

    params.REO = struct();
    params.REO.green_base_price = 0.43;
    params.REO.pv_om = 0.02;
    params.REO.wind_om = 0.015;
    params.REO.pv_reactive_capability = 0.426;
    params.REO.wind_reactive_ratio = 0.3;
    params.REO.wind_reactive_limit = 150;

    params.Grid = struct();
    params.Grid.rated_voltage = 10.0;
    params.Grid.line_R = 0.5;
    params.Grid.cap_step = 200;
    params.Grid.cap_max_groups = 5;
    params.Grid.cap_om_cost = 0.01;
    params.Grid.cap_loss_coeff = 0.0013;
    params.Grid.cap_voltage_coeff = 0.000197;
    params.Grid.tap_positions = [1, 2, 3, 4, 5];
    params.Grid.tap_ratios = [0.95, 0.975, 1.0, 1.025, 1.05];
    params.Grid.tap_base = 3;
    params.Grid.tap_loss_coeff = 0.65;
    params.Grid.tap_voltage_coeff = 0.0003165;
    params.Grid.tap_deviation_cost = 5;
    params.Grid.svg_capacity = 500;
    params.Grid.svg_om_cost = 0.02;
    params.Grid.svg_loss_coeff = 0.004;
    params.Grid.svg_voltage_coeff = 0.000471;
    params.Grid.pv_inv_loss_coeff = 0.0011;
    params.Grid.pv_inv_voltage_fluct_coeff = 0.000197;
    params.Grid.pv_inv_max_adjust_rate = 0.2;
    params.Grid.wind_rec_loss_coeff = 0.0014;
    params.Grid.wind_rec_voltage_fluct_coeff = 0.000681;
    params.Grid.wind_rec_max_adjust_rate = 0.3;
    params.Grid.loss_price = 0.6;
    params.Grid.loss_band = 5;
    params.Grid.loss_penalty = 2.0;
    params.Grid.loss_reward = 1.5;
    params.Grid.voltage_price = 100;
    params.Grid.voltage_base = 0.05;

    params.ESO = struct();
    params.ESO.peak_sell_price = 0.585;
    params.ESO.valley_buy_price = 0.385;
    params.ESO.rated_capacity = 2000;
    params.ESO.rated_power_scenario1 = 2000;
    params.ESO.rated_power_scenario2 = 2200;
    params.ESO.rated_power_scenario3 = 2400;
    params.ESO.charge_eff = 0.95;
    params.ESO.discharge_eff = 0.95;
    params.ESO.soc_min = 0.2;
    params.ESO.soc_max = 0.9;
    params.ESO.soc_init = 0.5;
    params.ESO.chem_loss = 0.01;
    params.ESO.mech_loss = 0.005;

    params.User = struct();
    params.User.v_k = 1.8;
    params.User.v_p = 1.5;
    params.User.v_d = 1.2;
    params.User.v_I = 0.9;
    params.User.v_A = 0.6;
    params.User.u_k = 0.002;
    params.User.u_p = 0.0015;
    params.User.u_d = 0.0012;
    params.User.u_I = 0.0008;
    params.User.u_A = 0.0005;
end

function time_data = local_generate_time_data(params)
    T = params.T;
    time_data = struct();

    load_profile = [
        0.45, 0.42, 0.40, 0.38, 0.40, 0.45, ...
        0.55, 0.70, 0.85, 0.90, 0.95, 0.98, ...
        0.95, 0.92, 0.88, 0.85, 0.80, 0.75, ...
        0.85, 0.95, 1.00, 0.95, 0.75, 0.60
    ];

    base_load = 3000;
    time_data.sys_load = base_load * load_profile;
    time_data.sys_load = time_data.sys_load(:)';

    pv_profile = [
        0, 0, 0, 0, 0, 0, ...
        0.1, 0.3, 0.5, 0.7, 0.85, 0.95, ...
        1.0, 0.95, 0.8, 0.6, 0.3, 0.1, ...
        0, 0, 0, 0, 0, 0
    ];
    time_data.pv_output = 800 * pv_profile;
    time_data.pv_output = time_data.pv_output(:)';

    wind_profile = [
        0.6, 0.65, 0.7, 0.75, 0.7, 0.6, ...
        0.5, 0.4, 0.3, 0.25, 0.2, 0.15, ...
        0.2, 0.25, 0.3, 0.35, 0.45, 0.55, ...
        0.6, 0.65, 0.7, 0.65, 0.6, 0.55
    ];
    time_data.wind_output = 600 * wind_profile;
    time_data.wind_output = time_data.wind_output(:)';

    time_data.peak_flag = zeros(1, T);
    time_data.valley_flag = zeros(1, T);
    time_data.peak_flag(10:15) = 1;
    time_data.peak_flag(18:22) = 1;
    time_data.valley_flag(1:6) = 1;
    time_data.valley_flag(23:24) = 1;

    time_data.re_peak_flag = time_data.peak_flag;
    time_data.actual_voltage = 10.0 * ones(1, T);

    power_factor = 0.85;
    time_data.base_reactive = time_data.sys_load * tan(acos(power_factor));
    time_data.base_loss = time_data.sys_load * 0.048;

    % Patch the missing fields used by the uploaded Stackelberg solver
    time_data.demand = time_data.sys_load;
    time_data.pv = time_data.pv_output;
    time_data.wind = time_data.wind_output;
    time_data.bargain_coeff = zeros(1, T);

    time_data.ess_charge = zeros(1, T);
    time_data.ess_discharge = zeros(1, T);
    time_data.ess_charge(1:6) = [80, 80, 80, 75, 75, 70];
    time_data.ess_charge(23:24) = [70, 70];
    time_data.ess_discharge(18:22) = [900, 1100, 800, 500, 200];
end

function [results, runinfo] = Stackelberg_Game_Solver_Table7(params, time_data, cpso_params, solver_opts)
    if nargin < 4
        solver_opts = struct();
    end
    if ~isfield(solver_opts, 'tol')
        solver_opts.tol = 1e-4;
    end
    if ~isfield(solver_opts, 'stall_window')
        solver_opts.stall_window = 10;
    end
    if ~isfield(solver_opts, 'verbose')
        solver_opts.verbose = false;
    end

    T = params.T;
    n_particles = cpso_params.n;
    max_iter = cpso_params.max_iter;

    dim = T * 10;
    lb = zeros(1, dim);
    ub = 10 * ones(1, dim);

    positions = repmat(lb, n_particles, 1) + rand(n_particles, dim) .* repmat((ub - lb), n_particles, 1);
    velocities = randn(n_particles, dim) * 0.1;

    pbest_pos = positions;
    pbest_cost = inf(n_particles, 1);

    gbest_pos = positions(1, :);
    gbest_cost = inf;

    history = nan(max_iter, 1);
    stall_count = 0;
    prev_best = NaN;

    tStart = tic;

    for iter = 1:max_iter
        w = cpso_params.w_max - (cpso_params.w_max - cpso_params.w_min) * iter / max_iter;

        for i = 1:n_particles
            emo_vars = decode_emo_variables_local(positions(i, :), T);
            followers_results = solve_followers_local(emo_vars, params, time_data);
            emo_obj = calculate_emo_objective_local(emo_vars, followers_results, params, time_data);
            current_cost = -emo_obj;

            if current_cost < pbest_cost(i)
                pbest_cost(i) = current_cost;
                pbest_pos(i, :) = positions(i, :);
            end

            if current_cost < gbest_cost
                gbest_cost = current_cost;
                gbest_pos = positions(i, :);
            end
        end

        history(iter) = -gbest_cost;

        if iter > 1
            rel_improve = abs(history(iter) - prev_best) / max(1, abs(prev_best));
            if rel_improve < solver_opts.tol
                stall_count = stall_count + 1;
            else
                stall_count = 0;
            end
        end
        prev_best = history(iter);

        if stall_count >= solver_opts.stall_window
            stop_iter = iter;
            break;
        end

        r1 = rand(n_particles, dim);
        r2 = rand(n_particles, dim);
        velocities = w .* velocities ...
            + cpso_params.c1 .* r1 .* (pbest_pos - positions) ...
            + cpso_params.c2 .* r2 .* (repmat(gbest_pos, n_particles, 1) - positions);

        positions = positions + velocities;
        positions = min(max(positions, repmat(lb, n_particles, 1)), repmat(ub, n_particles, 1));

        if mod(iter, 10) == 0
            chaos_candidate = chaos_local_search_local(gbest_pos, lb, ub, cpso_params.chaos_factor);
            chaos_emo_vars = decode_emo_variables_local(chaos_candidate, T);
            chaos_followers = solve_followers_local(chaos_emo_vars, params, time_data);
            chaos_obj = calculate_emo_objective_local(chaos_emo_vars, chaos_followers, params, time_data);
            chaos_cost = -chaos_obj;

            if chaos_cost < gbest_cost
                gbest_cost = chaos_cost;
                gbest_pos = chaos_candidate;
            end
        end

        if solver_opts.verbose && mod(iter, 10) == 0
            fprintf('Iter %d/%d: best objective = %.4f\n', iter, max_iter, -gbest_cost);
        end
    end

    if iter == max_iter
        stop_iter = max_iter;
    end

    emo_vars = decode_emo_variables_local(gbest_pos, T);
    followers_results = solve_followers_local(emo_vars, params, time_data);

    results = struct();
    results.EMO = calculate_emo_results_local(emo_vars, followers_results, params, time_data);
    results.REO = followers_results.REO;
    results.Grid = followers_results.Grid;
    results.ESO = followers_results.ESO;
    results.User = followers_results.User;

    runinfo = struct();
    runinfo.stop_iter = stop_iter;
    runinfo.history = history(1:stop_iter);
    runinfo.runtime_s = toc(tStart);
end

function emo_vars = decode_emo_variables_local(x, T)
    emo_vars = struct();
    idx = 1;

    emo_vars.sell_price = x(idx:idx+T-1) * 2;
    idx = idx + T;

    emo_vars.buy_price = x(idx:idx+T-1) * 1.5;
    idx = idx + T;

    emo_vars.ess_sell_price = x(idx:idx+T-1) * 0.8 + 0.3;
    idx = idx + T;

    emo_vars.ess_buy_price = x(idx:idx+T-1) * 0.6 + 0.2;
    idx = idx + T;

    emo_vars.grid_buy_limit = x(idx:idx+T-1) * 3000;
end

function followers = solve_followers_local(emo_vars, params, time_data)
    followers = struct();
    followers.REO = solve_reo_local(emo_vars, params, time_data);
    followers.Grid = solve_grid_local(emo_vars, params, time_data, followers.REO);
    followers.ESO = solve_eso_local(emo_vars, params, time_data);
    followers.User = solve_user_local(emo_vars, params, time_data, followers.Grid);
end

function reo_result = solve_reo_local(~, params, time_data)
    T = params.T;
    reo_result = struct();

    reo_result.pv_output = zeros(1, T);
    reo_result.wind_output = zeros(1, T);
    reo_result.total_output = zeros(1, T);
    reo_result.sell_price = zeros(1, T);
    reo_result.inverter_output = zeros(1, T);
    reo_result.rectifier_output = zeros(1, T);

    total_revenue = 0;
    total_om_cost = 0;

    for t = 1:T
        reo_result.pv_output(t) = time_data.pv(t);
        reo_result.wind_output(t) = time_data.wind(t);
        reo_result.total_output(t) = reo_result.pv_output(t) + reo_result.wind_output(t);

        reo_result.sell_price(t) = params.REO.green_base_price * (1 + time_data.bargain_coeff(t));
        total_revenue = total_revenue + reo_result.sell_price(t) * reo_result.total_output(t);

        total_om_cost = total_om_cost ...
            + params.REO.pv_om * reo_result.pv_output(t) ...
            + params.REO.wind_om * reo_result.wind_output(t);

        if reo_result.pv_output(t) > 0
            reo_result.inverter_output(t) = reo_result.pv_output(t) * 0.426;
        end
        if reo_result.wind_output(t) > 0
            reo_result.rectifier_output(t) = min(reo_result.wind_output(t) * 0.3, 150);
        end
    end

    c_inv_om = 0.015;
    c_rect_om = 0.02;
    Q_inv_base = 0.1;

    inv_om_cost = 0;
    rect_om_cost = 0;
    for t = 1:T
        Q_inv_deviation = abs(reo_result.inverter_output(t) - Q_inv_base * reo_result.pv_output(t));
        inv_om_cost = inv_om_cost + c_inv_om * Q_inv_deviation;
        rect_om_cost = rect_om_cost + c_rect_om * reo_result.rectifier_output(t);
    end

    total_om_cost = total_om_cost + inv_om_cost + rect_om_cost;

    reo_result.loss_reduction_inv = 0.0011 * abs(reo_result.inverter_output);
    reo_result.loss_reduction_rect = 0.0014 * reo_result.rectifier_output;

    reo_result.voltage_adjust_inv = zeros(1, T);
    reo_result.voltage_adjust_rect = zeros(1, T);

    for t = 1:T
        if t == 1
            Q_inv_change = abs(reo_result.inverter_output(t));
            Q_rec_change = reo_result.rectifier_output(t);
        else
            Q_inv_change = abs(reo_result.inverter_output(t) - reo_result.inverter_output(t-1));
            Q_rec_change = abs(reo_result.rectifier_output(t) - reo_result.rectifier_output(t-1));
        end

        Delta_Q_inv_max = 0.2 * reo_result.pv_output(t);
        Delta_Q_rec_max = 0.3 * reo_result.wind_output(t);

        reo_result.voltage_adjust_inv(t) = 0.000197 * min(Q_inv_change, Delta_Q_inv_max);
        reo_result.voltage_adjust_rect(t) = 0.000681 * min(Q_rec_change, Delta_Q_rec_max);
    end

    reo_result.revenue = total_revenue;
    reo_result.om_cost = total_om_cost;
    reo_result.profit = total_revenue - total_om_cost;
end

function grid_result = solve_grid_local(~, params, time_data, reo_result)
    T = params.T;
    grid_result = struct();

    grid_result.cap_groups = zeros(1, T);
    grid_result.cap_capacity = zeros(1, T);
    grid_result.tap_position = 3 * ones(1, T);
    grid_result.tap_ratio = ones(1, T);
    grid_result.svg_output = zeros(1, T);

    for t = 1:T
        load_ratio = time_data.sys_load(t) / max(time_data.sys_load);

        if load_ratio > 0.8
            grid_result.cap_groups(t) = 5;
        elseif load_ratio > 0.6
            grid_result.cap_groups(t) = 3;
        elseif load_ratio > 0.4
            grid_result.cap_groups(t) = 2;
        else
            grid_result.cap_groups(t) = 1;
        end
        grid_result.cap_capacity(t) = grid_result.cap_groups(t) * params.Grid.cap_step;
    end

    grid_result.tap_position(1:6) = 2;
    grid_result.tap_position(8) = 4;
    grid_result.tap_position(9:12) = 4;
    grid_result.tap_position(13:17) = 3;
    grid_result.tap_position(18:22) = 4;
    grid_result.tap_position(23:24) = 2;

    tap_ratios_map = [0.95, 0.975, 1.0, 1.025, 1.05];
    grid_result.tap_ratio = tap_ratios_map(grid_result.tap_position);

    for t = 1:T
        voltage_dev = 10 - time_data.actual_voltage(t);
        if voltage_dev > 0.5
            grid_result.svg_output(t) = min(500, voltage_dev * 100);
        elseif voltage_dev < -0.5
            grid_result.svg_output(t) = max(-500, voltage_dev * 100);
        else
            grid_result.svg_output(t) = 0;
        end
    end

    [grid_result.actual_loss, grid_result.actual_voltage, ...
        grid_result.loss_reduction_cap, grid_result.loss_reduction_tap, ...
        grid_result.loss_reduction_svg, grid_result.voltage_adjust_cap, ...
        grid_result.voltage_adjust_tap, grid_result.voltage_adjust_svg, ...
        grid_result.base_voltage] = calc_grid_performance_local(grid_result, params, time_data, reo_result);

    grid_result.base_loss = time_data.base_loss;
    grid_result.cost = calc_grid_cost_local(grid_result, params, time_data);
end

function [actual_loss, actual_voltage, loss_red_cap, loss_red_tap, ...
    loss_red_svg, volt_adj_cap, volt_adj_tap, volt_adj_svg, base_voltage] = ...
    calc_grid_performance_local(grid_result, params, time_data, reo_result)

    T = params.T;
    actual_loss = zeros(1, T);
    actual_voltage = zeros(1, T);
    base_voltage = zeros(1, T);

    loss_red_cap = zeros(1, T);
    loss_red_tap = zeros(1, T);
    loss_red_svg = zeros(1, T);
    volt_adj_cap = zeros(1, T);
    volt_adj_tap = zeros(1, T);
    volt_adj_svg = zeros(1, T);

    for t = 1:T
        Q_cap = grid_result.cap_capacity(t);
        Q_svg = grid_result.svg_output(t);
        Q_load = time_data.base_reactive(t);

        Q_total = Q_load - Q_cap - Q_svg;
        P_load = time_data.sys_load(t);

        S_after = sqrt(P_load^2 + Q_total^2);
        I_after = S_after / (sqrt(3) * params.Grid.rated_voltage);
        loss_line_base = 3 * I_after^2 * params.Grid.line_R;

        loss_red_cap(t) = 0.0013 * Q_cap;

        tap_dev = abs(grid_result.tap_position(t) - 3);
        if t >= 8 && t <= 12
            loss_red_tap(t) = 0.65 * tap_dev * 1.5;
        else
            loss_red_tap(t) = 0.65 * tap_dev;
        end

        loss_red_svg(t) = 0.004 * abs(Q_svg);

        total_loss_red = loss_red_cap(t) + loss_red_tap(t) + loss_red_svg(t) ...
            + reo_result.loss_reduction_inv(t) + reo_result.loss_reduction_rect(t);

        max_allowed_red = loss_line_base * 0.10;
        actual_reduction = min(total_loss_red, max_allowed_red);

        actual_loss(t) = max(loss_line_base - actual_reduction, P_load * 0.02);

        load_normalized = P_load / max(time_data.sys_load);
        base_voltage(t) = 10.0 - (load_normalized - 0.5) * 1.0;

        volt_adj_cap(t) = 0.000197 * Q_cap;

        tap_dev_from_base = abs(grid_result.tap_position(t) - 3);
        volt_adj_tap(t) = 0.0003165 * tap_dev_from_base * 1000;
        if t >= 8 && t <= 12
            volt_adj_tap(t) = volt_adj_tap(t) + 0.05;
        end

        volt_adj_svg(t) = 0.000471 * abs(Q_svg);

        actual_voltage(t) = base_voltage(t) + volt_adj_cap(t) + volt_adj_tap(t) ...
            + volt_adj_svg(t) + reo_result.voltage_adjust_inv(t) + reo_result.voltage_adjust_rect(t);

        actual_voltage(t) = min(max(actual_voltage(t), 9.5), 10.5);
    end
end

function cost = calc_grid_cost_local(grid_result, params, time_data)
    T = params.T;
    cost = 0;

    for t = 1:T
        loss_dev = grid_result.actual_loss(t) - time_data.base_loss(t);
        if loss_dev > params.Grid.loss_band
            loss_cost = params.Grid.loss_penalty * params.Grid.loss_price * (loss_dev - params.Grid.loss_band);
        elseif loss_dev < -params.Grid.loss_band
            loss_cost = -params.Grid.loss_reward * params.Grid.loss_price * abs(loss_dev + params.Grid.loss_band);
        else
            loss_cost = 0;
        end

        U_ref = params.Grid.rated_voltage;
        V_dev_before = abs(grid_result.base_voltage(t) - U_ref);
        V_dev_after = abs(grid_result.actual_voltage(t) - U_ref);
        Delta_V_opt = V_dev_after - V_dev_before;

        if Delta_V_opt > 0
            voltage_cost = params.Grid.voltage_price * Delta_V_opt;
        elseif Delta_V_opt < -params.Grid.voltage_base
            voltage_cost = params.Grid.voltage_price * Delta_V_opt * 0.5;
        else
            voltage_cost = 0;
        end

        cap_cost = grid_result.cap_capacity(t) * params.Grid.cap_om_cost;
        svg_cost = abs(grid_result.svg_output(t)) * params.Grid.svg_om_cost;
        tap_cost = abs(grid_result.tap_position(t) - params.Grid.tap_base) * params.Grid.tap_deviation_cost;

        cost = cost + loss_cost + voltage_cost + cap_cost + svg_cost + tap_cost;
    end
end

function eso_result = solve_eso_local(~, params, time_data)
    T = params.T;
    eso_result = struct();

    eso_result.charge = time_data.ess_charge;
    eso_result.discharge = time_data.ess_discharge;
    eso_result.soc = zeros(1, T+1);
    eso_result.soc(1) = params.ESO.soc_init;

    total_revenue = 0;
    total_cost = 0;

    for t = 1:T
        charge_energy = eso_result.charge(t) * params.ESO.charge_eff;
        discharge_energy = eso_result.discharge(t) / params.ESO.discharge_eff;
        eso_result.soc(t+1) = eso_result.soc(t) + (charge_energy - discharge_energy) / params.ESO.rated_capacity;

        if eso_result.discharge(t) > 0 && time_data.peak_flag(t) == 1
            total_revenue = total_revenue + 0.585 * eso_result.discharge(t) * params.ESO.discharge_eff;
        end

        if eso_result.charge(t) > 0 && time_data.valley_flag(t) == 1
            total_cost = total_cost + 0.385 * eso_result.charge(t) / params.ESO.charge_eff;
        end

        om_cost = params.ESO.chem_loss * 0.385 * eso_result.charge(t) ...
            + params.ESO.mech_loss * (eso_result.charge(t) + eso_result.discharge(t));
        total_cost = total_cost + om_cost;
    end

    eso_result.revenue = total_revenue;
    eso_result.cost = total_cost;
    eso_result.profit = total_revenue - total_cost;
end

function user_result = solve_user_local(emo_vars, params, time_data, ~)
    T = params.T;
    user_result = struct();

    L_k = zeros(1, T);
    L_p = zeros(1, T);
    L_d = zeros(1, T);
    L_I = zeros(1, T);
    L_A = zeros(1, T);

    for t = 1:T
        if t >= 1 && t <= 6
            L_k(t) = 800;
            L_p(t) = 1200;
            L_d(t) = 600;
            L_I(t) = 400;
            L_A(t) = 600;
        elseif (t >= 10 && t <= 15) || (t >= 18 && t <= 22)
            L_k(t) = 800;
            L_p(t) = 100;
            L_d(t) = 200;
            L_I(t) = 0;
            L_A(t) = 0;
        else
            L_k(t) = 800;
            L_p(t) = 600;
            L_d(t) = 400;
            L_I(t) = 200;
            L_A(t) = 100;
        end
    end

    user_result.load_k = L_k;
    user_result.load_p = L_p;
    user_result.load_d = L_d;
    user_result.load_I = L_I;
    user_result.load_A = L_A;

    total_satisfaction = 0;
    for t = 1:T
        U_k = params.User.v_k * L_k(t) - (params.User.u_k / 2) * L_k(t)^2;
        U_p = params.User.v_p * L_p(t) - (params.User.u_p / 2) * L_p(t)^2;
        U_d = params.User.v_d * L_d(t) - (params.User.u_d / 2) * L_d(t)^2;
        U_I = params.User.v_I * L_I(t) - (params.User.u_I / 2) * L_I(t)^2;
        U_A = params.User.v_A * L_A(t) - (params.User.u_A / 2) * L_A(t)^2;
        total_satisfaction = total_satisfaction + (U_k + U_p + U_d + U_I + U_A);
    end
    user_result.satisfaction = total_satisfaction;

    total_purchase_cost = 0;
    for t = 1:T
        total_load = L_k(t) + L_p(t) + L_d(t) + L_I(t) + L_A(t);
        total_purchase_cost = total_purchase_cost + emo_vars.sell_price(t) * total_load;
    end
    user_result.purchase_cost = total_purchase_cost;

    total_compensation = 0;
    for t = 1:T
        if time_data.re_peak_flag(t) == 1 && L_A(t) > 0
            total_compensation = total_compensation + L_A(t) * 0.05;
        end
    end
    user_result.green_compensation = total_compensation;
    user_result.grid_incentive = 50;
    user_result.profit = total_satisfaction + total_compensation + user_result.grid_incentive - total_purchase_cost;
end

function obj = calculate_emo_objective_local(emo_vars, followers, params, time_data)
    revenue_user = sum(emo_vars.sell_price .* time_data.demand);
    revenue_ess_valley = sum(0.385 .* time_data.ess_charge .* time_data.valley_flag);

    cost_reo = sum(followers.REO.sell_price .* followers.REO.total_output);
    cost_ess_peak = sum(0.585 .* time_data.ess_discharge .* time_data.peak_flag);
    cost_grid_trans = followers.Grid.cost;

    lambda_reward = params.EMO.reo_reward_lambda;
    c_base = params.EMO.reo_reward_c_base;
    c_volt = params.EMO.reo_reward_c_volt;
    reo_reward_cost = sum(lambda_reward .* ...
        (c_base .* (followers.REO.loss_reduction_inv + followers.REO.loss_reduction_rect) ...
        + c_volt .* (followers.REO.voltage_adjust_inv + followers.REO.voltage_adjust_rect)));

    om_cost = params.EMO.om_coeff * (cost_reo + cost_ess_peak);

    obj = revenue_user + revenue_ess_valley - cost_reo - cost_ess_peak - cost_grid_trans - om_cost - reo_reward_cost;
end

function emo_result = calculate_emo_results_local(emo_vars, followers, params, time_data)
    revenue_user = sum(emo_vars.sell_price .* time_data.demand);
    revenue_ess = sum(0.385 .* time_data.ess_charge .* time_data.valley_flag);
    total_revenue = revenue_user + revenue_ess;

    cost_reo = sum(followers.REO.sell_price .* followers.REO.total_output);
    cost_ess = sum(0.585 .* time_data.ess_discharge .* time_data.peak_flag);
    cost_grid = followers.Grid.cost;
    total_cost = cost_reo + cost_ess + cost_grid;

    lambda_reward = params.EMO.reo_reward_lambda;
    c_base = params.EMO.reo_reward_c_base;
    c_volt = params.EMO.reo_reward_c_volt;
    reo_reward = sum(lambda_reward .* ...
        (c_base .* (followers.REO.loss_reduction_inv + followers.REO.loss_reduction_rect) ...
        + c_volt .* (followers.REO.voltage_adjust_inv + followers.REO.voltage_adjust_rect)));

    om_cost = params.EMO.om_coeff * total_cost;

    emo_result = struct();
    emo_result.revenue = total_revenue;
    emo_result.cost = total_cost;
    emo_result.om_cost = om_cost;
    emo_result.reo_reward = reo_reward;
    emo_result.profit = total_revenue - total_cost - om_cost - reo_reward;
    emo_result.sell_price = emo_vars.sell_price;
    emo_result.buy_price = emo_vars.buy_price;
end

function x_new = chaos_local_search_local(x, lb, ub, chaos_factor)
    z = (x - lb) ./ (ub - lb);
    z_new = chaos_factor .* z .* (1 - z);
    x_new = lb + z_new .* (ub - lb);
    x_new = max(x_new, lb);
    x_new = min(x_new, ub);
end
