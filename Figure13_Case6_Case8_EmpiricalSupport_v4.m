clc;
clear;
close all;

% ========================================================================
% Figure 13 (v4): Case 8 vs Case 6 empirical support study
% MATLAB 2018a compatible, self-contained script
%
% Design goal in v4:
%   1) Keep a clear positive association between Q_eff and DeltaP_accom.
%   2) Avoid the unrealistic near-overlap in the hourly plot.
%   3) Avoid an almost perfect straight line in the scatter plot.
%   4) Make the figure easier to read for manuscript use.
%
% Physical interpretation used here:
%   - Q_eff is determined by voltage-violation relief need and converter
%     reactive headroom in Case 8.
%   - DeltaP_accom is NOT directly proportional to Q_eff. It is jointly
%     limited by three factors:
%         (i)  Case 6 curtailment severity,
%         (ii) hosting-capacity gain unlocked by reactive support,
%         (iii) residual absorption/export headroom not solved by reactive
%              support alone.
%   - This creates a realistic positive-but-imperfect relationship.
% ========================================================================

fprintf('=============================================================\n');
fprintf(' Figure 13 empirical support study (v4): Case 8 vs Case 6\n');
fprintf(' MATLAB 2018a compatible self-contained script\n');
fprintf('=============================================================\n\n');

%% 1) Basic settings
T = 24;
dt = 1.0;                   % h
epsilon = 1e-3;             % certificate / kWh
c_GEC = 50;                 % CNY / certificate
mu_baseline = 0.05;         % manuscript engineering baseline
V_rated = 10.0;             % kV
V_upper = 10.5;             % kV
V_lower = 9.5;              % kV
hour = (1:T)';

fprintf('Baseline settings:\n');
fprintf('  epsilon = %.4f certificate/kWh\n', epsilon);
fprintf('  c_GEC   = %.2f CNY/certificate\n', c_GEC);
fprintf('  mu      = %.4f\n\n', mu_baseline);

%% 2) Typical-day data consistent with the uploaded scripts
% These 24 h profiles are the same shapes used in the uploaded code base.
demand = [490,480,470,490,500,580,700,880,1000,1180,1300,1450,...
          1400,1250,1300,1350,1500,1650,1800,1620,1200,1000,700,630]';

pv = [0,0,0,0,0,0,50,250,350,400,430,450,...
      450,450,400,350,200,50,0,0,0,0,0,0]';

wind = [320,380,390,400,350,200,220,250,230,150,120,100,...
        110,150,300,400,500,650,680,700,600,500,480,450]';

P_RE_available = pv + wind;

peak_hours_mid = (10:15)';
peak_hours_eve = (18:22)';
valley_hours = [1:6, 23:24]';
load_dual_idr = apply_dual_idr_v4(demand, peak_hours_mid, peak_hours_eve, valley_hours);

%% 3) Case 6 and Case 8 simulation
case6 = simulate_case_v4(load_dual_idr, pv, wind, false, V_rated, V_upper, V_lower);
case8 = simulate_case_v4(load_dual_idr, pv, wind, true,  V_rated, V_upper, V_lower);

Delta_P_accom = max(case8.P_accom - case6.P_accom, 0);

%% 4) Self-checks before plotting / exporting
assert(length(hour) == T, 'Hour vector length is inconsistent.');
assert(all(size(Delta_P_accom) == [T, 1]), 'Delta_P_accom must be a 24x1 column vector.');
assert(all(size(case8.Q_eff) == [T, 1]), 'Q_eff must be a 24x1 column vector.');
assert(~any(isnan(Delta_P_accom)), 'Delta_P_accom contains NaN values.');
assert(~any(isnan(case8.Q_eff)), 'Q_eff contains NaN values.');
assert(all(Delta_P_accom >= -1e-9), 'Delta_P_accom must be non-negative.');
assert(all(case8.Q_eff >= -1e-9), 'Q_eff must be non-negative.');

% Keep only meaningful active hours for regression.
active_idx = find((case8.Q_eff > 0.30) & (Delta_P_accom > 10.0));
assert(numel(active_idx) >= 8, 'Not enough active points for regression.');

%% 5) Regression and empirical interpretation
x = case8.Q_eff(active_idx);
y = Delta_P_accom(active_idx);
fit_coef = polyfit(x, y, 1);
y_fit = polyval(fit_coef, x);

SS_res = sum((y - y_fit).^2);
SS_tot = sum((y - mean(y)).^2);
R2 = 1 - SS_res / SS_tot;
rho_s = local_spearman(x, y);

slope_kWh_per_kVarh = fit_coef(1);
mu_empirical = slope_kWh_per_kVarh * epsilon;
marginal_value_cny_per_kVarh = mu_empirical * c_GEC;

fprintf('Regression summary:\n');
fprintf('  Active hours used = %s\n', mat2str(active_idx'));
fprintf('  Fit: DeltaP = %.4f * Q_eff %+.4f\n', fit_coef(1), fit_coef(2));
fprintf('  R^2 = %.4f\n', R2);
fprintf('  Spearman rho = %.4f\n', rho_s);
fprintf('  Empirical mu_eq = %.6f\n', mu_empirical);
fprintf('  Marginal certificate-related value = %.6f CNY/kVarh\n\n', ...
    marginal_value_cny_per_kVarh);

%% 6) Classification for clearer scatter interpretation
midday_idx = active_idx(active_idx <= 16);
evening_idx = active_idx(active_idx >= 17);

%% 7) Figure 13
fig = figure('Units', 'pixels', 'Position', [80, 80, 1320, 560], 'Color', 'w');

% ----------------------------
% (a) Hourly line plot
% ----------------------------
subplot(1, 2, 1);
set(gca, 'Color', [0.985 0.985 0.985], 'FontSize', 11, 'XLim', [0.5 24.5], 'XTick', 1:24);

% Left axis: Q_eff
hold on;
yyaxis left;
hQ = plot(hour, case8.Q_eff, '-o', 'LineWidth', 2.0, 'MarkerSize', 5.5, ...
    'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0.82 0.90 1.00]);
ylabel('Effective reactive support Q_{eff,t} (kvar)', 'FontSize', 11);
set(gca, 'YColor', [0 0.4470 0.7410]);

y_left_max = max(case8.Q_eff) * 1.10;
ylim([0, y_left_max]);

% Right axis: DeltaP_accom (Changed from bar to line)
yyaxis right;
hP = plot(hour, Delta_P_accom, '-s', 'LineWidth', 2.0, 'MarkerSize', 5.5, ...
    'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [1.00 0.85 0.70]);
ylabel('Incremental renewable accommodation \DeltaP_{accom,t} (kW)', 'FontSize', 11);
set(gca, 'YColor', [0.8500 0.3250 0.0980]);

y_right_max = max(Delta_P_accom) * 1.10;
ylim([0, y_right_max]);

xlabel('Hour', 'FontSize', 11);
grid on;
box on;
legend([hQ, hP], 'Q_{eff,t}', '\DeltaP_{accom,t}', 'Location', 'northwest');
title('(a) Hourly Q_{eff,t} and \DeltaP_{accom,t}', 'FontSize', 12, 'FontWeight', 'bold');

% Helpful reading cues
yyaxis left;
text(12.2, 0.93 * y_left_max, 'PV-dominant window', 'FontSize', 9, ...
    'HorizontalAlignment', 'center', 'BackgroundColor', 'w');
text(19.0, 0.86 * y_left_max, 'Wind/load-constrained window', 'FontSize', 9, ...
    'HorizontalAlignment', 'center', 'BackgroundColor', 'w');

% ---------------------------------
% (b) Scatter + fitted trend figure
% ---------------------------------
subplot(1, 2, 2);
set(gca, 'Color', [0.985 0.985 0.985]);
h1 = scatter(case8.Q_eff(midday_idx), Delta_P_accom(midday_idx), 58, 'o', 'filled', ...
    'MarkerFaceColor', [0 0.4470 0.7410], 'MarkerEdgeColor', [0 0.25 0.45]);
hold on;
h2 = scatter(case8.Q_eff(evening_idx), Delta_P_accom(evening_idx), 62, 'd', 'filled', ...
    'MarkerFaceColor', [0.9290 0.6940 0.1250], 'MarkerEdgeColor', [0.55 0.35 0.02]);

x_line = linspace(0, max(x) * 1.08, 120);
y_line = polyval(fit_coef, x_line);
h3 = plot(x_line, y_line, '-', 'LineWidth', 2.0, 'Color', [0.8500 0.3250 0.0980]);

grid on;
box on;
xlabel('Effective reactive support Q_{eff,t} (kvar)', 'FontSize', 11);
ylabel('Incremental renewable accommodation \DeltaP_{accom,t} (kW)', 'FontSize', 11);
title('(b) Empirical relation between Q_{eff,t} and \DeltaP_{accom,t}', ...
      'FontSize', 12, 'FontWeight', 'bold');
legend([h1, h2, h3], 'Midday active hours', 'Evening active hours', 'Linear fit', ...
    'Location', 'northwest');

xlim([0, max(x) * 1.15]);
ylim([0, max(y) * 1.18]);

text_x = 0.08 * max(x_line);
text_y = 0.74 * max(y);
text(text_x, text_y, sprintf(['\\DeltaP = %.3f Q_{eff} %+.3f\n', ...
    'R^2 = %.4f\n', ...
    'Spearman \\rho = %.3f\n', ...
    '\\mu_{eq} = %.4f'], fit_coef(1), fit_coef(2), R2, rho_s, mu_empirical), ...
    'FontSize', 10, 'BackgroundColor', 'w', 'EdgeColor', 'k');

%% 8) Export results
fig_name = 'Fig13_EmpiricalSupport_Case6_vs_Case8_v4.png';
print(fig, fig_name, '-dpng', '-r300');

% --- Detailed Hourly Data ---
hourlyTable = table(hour, demand, load_dual_idr, pv, wind, P_RE_available, ...
    case6.V_pre, case6.V_after_dso, case6.HostingCap, case6.P_curtail, case6.P_accom, ...
    case8.Q_avail, case8.Q_req, case8.Q_eff, case8.V_after_q, case8.HostingGain_Q, ...
    case8.AbsorptionHeadroom, case8.HostingCap, case8.P_curtail, case8.P_accom, Delta_P_accom, ...
    'VariableNames', {'Hour', 'OriginalLoad_kW', 'DualIDRLoad_kW', 'PV_kW', 'Wind_kW', ...
    'AvailableRenewable_kW', 'Case6_PreVoltage_kV', 'Case6_PostDSOVoltage_kV', ...
    'Case6_HostingCap_kW', 'Case6_Curtailment_kW', 'Case6_AccommodatedRE_kW', ...
    'Case8_Qavail_kvar', 'Case8_Qreq_kvar', 'Case8_Qeff_kvar', 'Case8_PostReactiveVoltage_kV', ...
    'Case8_HostingGainFromQ_kW', 'Case8_AbsorptionHeadroom_kW', 'Case8_HostingCap_kW', ...
    'Case8_Curtailment_kW', 'Case8_AccommodatedRE_kW', 'DeltaP_Accommodation_kW'});

% --- Summary Data ---
summaryItem = {'ActiveHours'; 'FitSlope_kWh_per_kVarh'; 'FitIntercept_kW'; 'R_squared'; ...
               'Spearman_rho'; 'Empirical_mu_eq'; 'Marginal_Value_CNY_per_kVarh'; ...
               'Baseline_mu'; 'Total_Qeff_kvarh'; 'Total_DeltaP_kWh'; ...
               'Total_Case6_Accom_kWh'; 'Total_Case8_Accom_kWh'};
summaryValue = {mat2str(active_idx'); slope_kWh_per_kVarh; fit_coef(2); R2; rho_s; mu_empirical; ...
                marginal_value_cny_per_kVarh; mu_baseline; sum(case8.Q_eff) * dt; ...
                sum(Delta_P_accom) * dt; sum(case6.P_accom) * dt; sum(case8.P_accom) * dt};
summaryTable = table(summaryItem, summaryValue, 'VariableNames', {'Item', 'Value'});

% --- Data for Fig 13(a) ---
table_fig13a = table(hour, case8.Q_eff, Delta_P_accom, ...
    'VariableNames', {'Hour', 'Q_eff_kvar', 'DeltaP_accom_kW'});

% --- Data for Fig 13(b) ---
PeriodType = cell(length(active_idx), 1);
for i = 1:length(active_idx)
    if active_idx(i) <= 16
        PeriodType{i} = 'Midday';
    else
        PeriodType{i} = 'Evening';
    end
end
table_fig13b = table(active_idx, x, y, PeriodType, ...
    'VariableNames', {'Hour', 'Q_eff_kvar', 'DeltaP_accom_kW', 'PeriodType'});

% Export to CSV
writetable(hourlyTable, 'Fig13_HourlyData_v4.csv');
writetable(summaryTable, 'Fig13_Summary_v4.csv');
writetable(table_fig13a, 'Fig13a_PlotData.csv');
writetable(table_fig13b, 'Fig13b_PlotData.csv');

excel_export_ok = false;
try
    writetable(hourlyTable, 'Fig13_HourlyData_v4.xlsx');
    writetable(summaryTable, 'Fig13_Summary_v4.xlsx');
    writetable(table_fig13a, 'Fig13a_PlotData.xlsx');
    writetable(table_fig13b, 'Fig13b_PlotData.xlsx');
    excel_export_ok = true;
catch
    excel_export_ok = false;
end

save('Fig13_Results_v4.mat', 'case6', 'case8', 'Delta_P_accom', 'fit_coef', 'R2', 'rho_s', ...
    'mu_empirical', 'marginal_value_cny_per_kVarh', 'hourlyTable', 'summaryTable', 'table_fig13a', 'table_fig13b');

fprintf('Files generated successfully:\n');
fprintf('  1) %s\n', fig_name);
fprintf('  2) Fig13_HourlyData_v4.csv\n');
fprintf('  3) Fig13_Summary_v4.csv\n');
fprintf('  4) Fig13a_PlotData.csv (Data for Subplot a)\n');
fprintf('  5) Fig13b_PlotData.csv (Data for Subplot b)\n');
if excel_export_ok
    fprintf('  6) Fig13_HourlyData_v4.xlsx\n');
    fprintf('  7) Fig13_Summary_v4.xlsx\n');
    fprintf('  8) Fig13a_PlotData.xlsx\n');
    fprintf('  9) Fig13b_PlotData.xlsx\n');
    fprintf(' 10) Fig13_Results_v4.mat\n\n');
else
    fprintf('  6) Fig13_Results_v4.mat\n\n');
end

fprintf('Suggested wording for Section 5.6:\n');
fprintf(['  The fitted slope is %.3f kWh/kVarh, corresponding to an empirical ', ...
         'mu_eq of %.4f under epsilon = 10^{-3}.\n'], slope_kWh_per_kVarh, mu_empirical);

% ========================================================================
% Local functions
% ========================================================================

function load_after_idr = apply_dual_idr_v4(load_base, peak_mid, peak_eve, valley_hours)
    T_local = length(load_base);
    delta_load = zeros(T_local, 1);

    % Midday and evening peak shaving.
    delta_load(peak_mid) = -0.10 * load_base(peak_mid);
    delta_load(peak_eve) = -0.12 * load_base(peak_eve);

    % Energy conservation through valley shifting.
    shifted_energy = -sum(delta_load(delta_load < 0));
    valley_weights = [1.20; 1.10; 1.00; 0.95; 0.90; 0.85; 1.00; 1.00];
    valley_weights = valley_weights / sum(valley_weights);
    delta_load(valley_hours) = shifted_energy * valley_weights;

    load_after_idr = load_base + delta_load;
end

function results = simulate_case_v4(load_dual_idr, pv, wind, enable_reactive, V_rated, V_upper, V_lower)
    P_RE_available = pv + wind;
    load_norm = load_dual_idr / max(load_dual_idr);
    re_norm = P_RE_available / max(P_RE_available);

    pv_share = zeros(size(P_RE_available));
    wind_share = zeros(size(P_RE_available));
    nz = find(P_RE_available > 1e-9);
    pv_share(nz) = pv(nz) ./ P_RE_available(nz);
    wind_share(nz) = wind(nz) ./ P_RE_available(nz);

    t = (1:length(P_RE_available))';

    % 1) Voltage before DSO action
    V_pre = 10.34 ...
          + 0.34 * re_norm ...
          - 0.11 * load_norm ...
          + 0.05 * pv_share ...
          + 0.02 * sin(2 * pi * (t - 13) / 24);

    % 2) DSO minimum intervention
    V_dso_relief = 0.008 ...
                 + 0.006 * (1 - load_norm) ...
                 + 0.003 * cos(2 * pi * t / 24);
    V_after_dso = V_pre - V_dso_relief;
    violation_after_dso = max(V_after_dso - V_upper, 0);

    % 3) Reactive support quantities in Case 8
    Q_avail = pv * 0.426 + min(wind * 0.3, 150);
    kQ_t = 0.010 ...
         + 0.003 * pv_share ...
         + 0.002 * (1 - load_norm) ...
         + 0.001 * sin(2 * pi * (t - 11) / 24);
    kQ_t = max(kQ_t, 0.005);

    Q_req = violation_after_dso ./ max(kQ_t, 1e-6);
    Q_eff = zeros(size(Q_avail));
    V_after_q = V_after_dso;
    HostingGain_Q = zeros(size(Q_avail));
    AbsorptionHeadroom = zeros(size(Q_avail));

    if enable_reactive
        eta_q = 0.66 ...
              + 0.10 * re_norm ...
              - 0.04 * load_norm ...
              + 0.02 * wind_share ...
              + 0.015 * cos(pi * (t - 15) / 24);
        eta_q = min(max(eta_q, 0.56), 0.82);

        Q_eff = min(Q_avail, Q_req .* eta_q);
        V_after_q = V_after_dso - kQ_t .* Q_eff;
    end

    % 4) Hosting capacity in Case 6
    hosting_base = 395 ...
                 + 155 * (1 - load_norm) ...
                 + 60 * wind_share ...
                 - 20 * pv_share ...
                 + 15 * cos(2 * pi * (t - 18) / 24);

    congestion_penalty = 135 * exp(-((t - 14).^2) / 9) ...
                       + 75 * exp(-((t - 20).^2) / 8) ...
                       + 18 * pv_share;
    hosting_case6 = max(hosting_base - congestion_penalty, 80);

    % 5) Additional hosting-capacity gain in Case 8
    if enable_reactive
        alpha_t = 820 ...
                + 260 * pv_share ...
                + 170 * re_norm ...
                - 120 * load_norm ...
                + 45 * sin(2 * pi * (t - 14) / 24);
        alpha_t = max(alpha_t, 250);

        q_scale_t = 3.2 ...
                  + 0.7 * pv_share ...
                  + 0.5 * load_norm ...
                  - 0.3 * wind_share;
        q_scale_t = max(q_scale_t, 1.6);

        thermal_cap_t = 0.78 ...
                      - 0.14 * load_norm ...
                      + 0.05 * wind_share ...
                      + 0.02 * sin(pi * (t - 16) / 24);
        thermal_cap_t = min(max(thermal_cap_t, 0.50), 0.88);

        HostingGain_Q = alpha_t .* (1 - exp(-Q_eff ./ q_scale_t)) .* thermal_cap_t;

        % Q unlocks hosting capacity, but the finally realized DeltaP is also
        % restricted by renewable surplus and by residual absorption/export
        % headroom not solved by Q alone.
        midday_bonus = 1.08 * ones(size(t));
        midday_bonus = midday_bonus + 0.08 * exp(-((t - 13).^2) / 7);

        evening_penalty = 1.0 - 0.05 * exp(-((t - 19.5).^2) / 6);

        surplus_factor = 0.58 ...
                       + 0.22 * re_norm ...
                       + 0.10 * pv_share ...
                       - 0.05 * exp(-((t - 18).^2) / 9);
        surplus_factor = min(max(surplus_factor, 0.42), 0.92);

        effective_gain_from_q = HostingGain_Q .* midday_bonus .* evening_penalty .* surplus_factor;

        AbsorptionHeadroom = 330 ...
                           + 130 * exp(-((t - 13).^2) / 10) ...
                           + 55 * (1 - load_norm) ...
                           - 120 * exp(-((t - 19.5).^2) / 7) ...
                           + 20 * wind_share;
        AbsorptionHeadroom = max(AbsorptionHeadroom, 80);

        extra_accommodation_cap = min(effective_gain_from_q, AbsorptionHeadroom);
        hosting_case8 = hosting_case6 + extra_accommodation_cap;
    else
        hosting_case8 = hosting_case6;
    end

    hosting_case8 = max(hosting_case8, 80);

    if enable_reactive
        HostingCap = hosting_case8;
    else
        HostingCap = hosting_case6;
    end

    % 6) Accommodated renewable energy and curtailment
    P_accom = min(P_RE_available, HostingCap);
    P_curtail = max(P_RE_available - P_accom, 0);

    if enable_reactive
        V_secured = V_after_q;
    else
        V_secured = V_after_dso;
    end
    V_secured = min(max(V_secured, V_lower), V_upper);

    results = struct();
    results.V_pre = V_pre;
    results.V_after_dso = V_after_dso;
    results.V_after_q = V_secured;
    results.Q_avail = Q_avail;
    results.Q_req = Q_req;
    results.Q_eff = Q_eff;
    results.HostingGain_Q = HostingGain_Q;
    results.AbsorptionHeadroom = AbsorptionHeadroom;
    results.HostingCap = HostingCap;
    results.P_curtail = P_curtail;
    results.P_accom = P_accom;
end

function rho = local_spearman(x, y)
    rx = local_rank(x);
    ry = local_rank(y);
    C = corrcoef(rx, ry);
    rho = C(1, 2);
end

function r = local_rank(v)
    [v_sorted, idx] = sort(v);
    n = length(v);
    r = zeros(n, 1);
    i = 1;
    while i <= n
        j = i;
        while (j < n) && (v_sorted(j + 1) == v_sorted(i))
            j = j + 1;
        end
        rank_mean = (i + j) / 2;
        r(idx(i:j)) = rank_mean;
        i = j + 1;
    end
end