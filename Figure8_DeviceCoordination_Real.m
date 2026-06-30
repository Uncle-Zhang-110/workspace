%% Figure 8 - real device-level coordination and reactive support
% MATLAB R2018a compatible.
%
% This script replaces the old illustrative/random device-level figure in
% Simple_Main_Modified.m. All plotted values are generated from simulation:
%   1) r21_build_data();
%   2) r21_optimize_leader(data) for optimized Case 8 leader strategy;
%   3) r21_solve_case(data,bestX(1),bestX(2),bestX(3)) for all followers;
%   4) leave-one-device-out DSO re-dispatch + MATPOWER AC verification for
%      device-level contribution attribution.
%
% Device contribution definition:
%   Raw marginal contribution of device j =
%       metric(without device j) - metric(all devices).
%   The stacked bars use positive raw marginal contributions normalized to
%   the actual all-off vs all-on total improvement in each hour. This keeps
%   the stacked total physically tied to real AC simulations while avoiding
%   double-counting interactions among reactive devices.

clc; close all;

workspaceDir = fileparts(mfilename('fullpath'));
reviewerDir = fullfile(workspaceDir, 'reviewer2.1');
addpath(reviewerDir);

fprintf('=============================================================\n');
fprintf(' Figure 8 real device coordination: CPSO + CPLEX + MATPOWER AC\n');
fprintf(' No random generation, no hand-edited plotted data.\n');
fprintf('=============================================================\n\n');

d = r21_build_data();
% Fig. 8 explains device-level reactive coordination. Keep the manuscript
% baseline reactive-support valuation mu = 0.05 (muScale = 1) instead of
% allowing the local-profit CPSO search to collapse mu to zero. The stronger
% DSO voltage objective activates real device coordination through the same
% MIQCP + AC verification chain; it does not overwrite plotted results.
d.leaderLB(3) = 1;
d.leaderUB(3) = 1;
d.dsoVoltageWeight = 5e4;

fprintf('[1/4] Optimizing Case 8 leader strategy by CPSO...\n');
[bestX, base, trace] = r21_optimize_leader(d);
if ~base.feasible
    error('Optimized Case 8 is not feasible under MATPOWER AC verification.');
end
fprintf('      bestX = [TOU scale %.6f, GCC scale %.6f, mu scale %.6f]\n', bestX(1), bestX(2), bestX(3));
fprintf('      Baseline EMO profit = %.6f CNY\n\n', base.EMO_profit);

fprintf('[2/4] Running all-off and leave-one-device-out AC simulations...\n');
ablationModes = {'all_off', 'without_REC', 'without_CB', 'without_OLTC', 'without_SVG', 'without_INV'};
ablationNames = {'All reactive devices disabled', 'Without WT rectifier', 'Without CB', ...
    'Without OLTC', 'Without SVG', 'Without PV inverter'};
nAbl = numel(ablationModes);
abl = cell(nAbl,1);
for k = 1:nAbl
    fprintf('      %s...\n', ablationNames{k});
    abl{k} = fig8_run_device_ablation(d, base, ablationModes{k});
end

fprintf('[3/4] Computing real attribution tables...\n');
T = d.T;
hour = (1:T)';

% Panel (a): real supply mix from optimized Case 8.
TotalDemand_kW = base.user.load(:);
PVPower_kW = base.grid.Ppv(:);
WTPower_kW = base.grid.Pwind(:);
ESSPower_kW = (base.eso.discharge(:) - base.eso.charge(:));
ExternalGridPower_kW = max(TotalDemand_kW - PVPower_kW - WTPower_kW - ESSPower_kW, 0);

% Panel (b,c): AC loss and voltage-deviation attribution.
lossAll_kW = base.ac_loss_kW(:);
voltDevAll_kV = max(abs(base.ac_voltage - 1), [], 1)' * d.baseKV;
lossAllOff_kW = abl{1}.ac_loss_kW(:);
voltDevAllOff_kV = abl{1}.voltage_deviation_kV(:);

deviceLabels = {'REC', 'CB', 'OLTC', 'SVG', 'INV'};
nDev = numel(deviceLabels);
rawLoss = zeros(T,nDev);
rawVolt = zeros(T,nDev);
for j = 1:nDev
    rawLoss(:,j) = abl{j+1}.ac_loss_kW(:) - lossAll_kW;
    rawVolt(:,j) = abl{j+1}.voltage_deviation_kV(:) - voltDevAll_kV;
end
rawLossPositive = max(rawLoss, 0);
rawVoltPositive = max(rawVolt, 0);

TotalLossReduction_kW = max(lossAllOff_kW - lossAll_kW, 0);
TotalVoltageRegulation_kV = max(voltDevAllOff_kV - voltDevAll_kV, 0);
LossContribution_kW = fig8_normalize_positive_attribution(rawLossPositive, TotalLossReduction_kW);
VoltageContribution_kV = fig8_normalize_positive_attribution(rawVoltPositive, TotalVoltageRegulation_kV);

dataTable = table(hour, ...
    ExternalGridPower_kW, PVPower_kW, WTPower_kW, ESSPower_kW, TotalDemand_kW, ...
    lossAll_kW, lossAllOff_kW, TotalLossReduction_kW, ...
    LossContribution_kW(:,1), LossContribution_kW(:,2), LossContribution_kW(:,3), ...
    LossContribution_kW(:,4), LossContribution_kW(:,5), ...
    rawLoss(:,1), rawLoss(:,2), rawLoss(:,3), rawLoss(:,4), rawLoss(:,5), ...
    voltDevAll_kV, voltDevAllOff_kV, TotalVoltageRegulation_kV, ...
    VoltageContribution_kV(:,1), VoltageContribution_kV(:,2), VoltageContribution_kV(:,3), ...
    VoltageContribution_kV(:,4), VoltageContribution_kV(:,5), ...
    rawVolt(:,1), rawVolt(:,2), rawVolt(:,3), rawVolt(:,4), rawVolt(:,5), ...
    'VariableNames', {'Time_h', ...
    'ExternalGridPower_kW', 'PVPower_kW', 'WTPower_kW', 'ESSPower_kW', 'TotalDemand_kW', ...
    'ACLoss_AllDevices_kW', 'ACLoss_AllReactiveDevicesDisabled_kW', 'TotalLossReduction_kW', ...
    'REC_LossContribution_kW', 'CB_LossContribution_kW', 'OLTC_LossContribution_kW', ...
    'SVG_LossContribution_kW', 'INV_LossContribution_kW', ...
    'REC_RawMarginalLoss_kW', 'CB_RawMarginalLoss_kW', 'OLTC_RawMarginalLoss_kW', ...
    'SVG_RawMarginalLoss_kW', 'INV_RawMarginalLoss_kW', ...
    'VoltageDeviation_AllDevices_kV', 'VoltageDeviation_AllReactiveDevicesDisabled_kV', ...
    'TotalVoltageRegulation_kV', ...
    'REC_VoltageContribution_kV', 'CB_VoltageContribution_kV', 'OLTC_VoltageContribution_kV', ...
    'SVG_VoltageContribution_kV', 'INV_VoltageContribution_kV', ...
    'REC_RawMarginalVoltage_kV', 'CB_RawMarginalVoltage_kV', 'OLTC_RawMarginalVoltage_kV', ...
    'SVG_RawMarginalVoltage_kV', 'INV_RawMarginalVoltage_kV'});

diagNames = [{'All devices'} ablationNames];
meanLoss = zeros(numel(diagNames),1);
meanVoltDev = zeros(numel(diagNames),1);
minVolt = zeros(numel(diagNames),1);
maxVolt = zeros(numel(diagNames),1);
networkFeasible = false(numel(diagNames),1);
meanLoss(1) = mean(lossAll_kW);
meanVoltDev(1) = mean(voltDevAll_kV);
minVolt(1) = min(base.ac_voltage(:));
maxVolt(1) = max(base.ac_voltage(:));
networkFeasible(1) = base.feasible;
for k = 1:nAbl
    meanLoss(k+1) = mean(abl{k}.ac_loss_kW);
    meanVoltDev(k+1) = mean(abl{k}.voltage_deviation_kV);
    minVolt(k+1) = min(abl{k}.ac_voltage(:));
    maxVolt(k+1) = max(abl{k}.ac_voltage(:));
    networkFeasible(k+1) = abl{k}.NetworkFeasible;
end
diagnostics = table(diagNames(:), networkFeasible, meanLoss, meanVoltDev, minVolt, maxVolt, ...
    'VariableNames', {'CaseName', 'NetworkFeasible', 'AverageACLoss_kW', ...
    'AverageMaxVoltageDeviation_kV', 'MinVoltage_pu', 'MaxVoltage_pu'});

writetable(dataTable, fullfile(workspaceDir, 'Figure8_DeviceCoordination_Real_Data.csv'));
writetable(diagnostics, fullfile(workspaceDir, 'Figure8_DeviceCoordination_Real_Diagnostics.csv'));

fprintf('[4/4] Drawing paper-style figure...\n');
fig = figure('Color', 'w', 'Position', [60 80 1900 560], 'PaperPositionMode', 'auto');

black = [0 0 0];
red = [0.80 0.12 0.12];
yellow = [1.00 0.88 0.00];
blue = [0.00 0.45 0.80];
green = [0.05 0.85 0.20];
cyan = [0.00 0.75 0.85];
deepBlue = [0.02 0.18 0.85];
deviceColors = [yellow; red; green; deepBlue; cyan]; % REC, CB, OLTC, SVG, INV

ax1 = axes('Parent', fig, 'Position', [.055 .205 .275 .710]);
fig8_panel_background(ax1, [0 24], fig8_ylim([ExternalGridPower_kW; PVPower_kW; WTPower_kW; ESSPower_kW; TotalDemand_kW]));
hold(ax1, 'on');
hSupply = bar(ax1, hour, [ExternalGridPower_kW PVPower_kW WTPower_kW ESSPower_kW], .78, 'stacked');
set(hSupply(1), 'FaceColor', red, 'EdgeColor', 'none');
set(hSupply(2), 'FaceColor', yellow, 'EdgeColor', 'none');
set(hSupply(3), 'FaceColor', blue, 'EdgeColor', 'none');
set(hSupply(4), 'FaceColor', green, 'EdgeColor', 'none');
hDemand = plot(ax1, hour, TotalDemand_kW, '-o', 'Color', black, 'MarkerFaceColor', black, ...
    'MarkerSize', 3.8, 'LineWidth', 1.0);
fig8_format_axis(ax1);
xlabel(ax1, 'Time/h');
ylabel(ax1, 'Power/kW');
legend(ax1, [hSupply(:); hDemand], {'External Grid Power', 'PV Power', 'WT Power', 'ESS Power', 'Total Demand'}, ...
    'Location', 'northwest', 'FontName', 'Times New Roman', 'FontSize', 8, 'Box', 'off');
text(ax1, .5, -0.19, '(a) Hourly energy supply mix', 'Units', 'normalized', ...
    'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 13);

ax2 = axes('Parent', fig, 'Position', [.370 .205 .275 .710]);
fig8_panel_background(ax2, [0 24], fig8_ylim([LossContribution_kW(:); TotalLossReduction_kW]));
hold(ax2, 'on');
hLoss = bar(ax2, hour, LossContribution_kW, .78, 'stacked');
for j = 1:nDev
    set(hLoss(j), 'FaceColor', deviceColors(j,:), 'EdgeColor', 'none');
end
hLossTotal = plot(ax2, hour, TotalLossReduction_kW, '-o', 'Color', black, ...
    'MarkerFaceColor', black, 'MarkerSize', 3.6, 'LineWidth', 0.9);
fig8_format_axis(ax2);
xlabel(ax2, 'Time/h');
ylabel(ax2, 'Grid Loss/kW');
legend(ax2, [hLoss(:); hLossTotal], {'REC Loss Red', 'CB Loss Red', 'OLTC Loss Red', ...
    'SVG Loss Red', 'INV Loss Red', 'Total Loss Red'}, ...
    'Location', 'northwest', 'FontName', 'Times New Roman', 'FontSize', 8, 'Box', 'off');
text(ax2, .5, -0.19, '(b) Contributions of reactive devices to loss', 'Units', 'normalized', ...
    'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 13);
text(ax2, .5, -0.295, 'reduction', 'Units', 'normalized', ...
    'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 13);

ax3 = axes('Parent', fig, 'Position', [.685 .205 .275 .710]);
fig8_panel_background(ax3, [0 24], fig8_ylim([VoltageContribution_kV(:); TotalVoltageRegulation_kV]));
hold(ax3, 'on');
hVolt = bar(ax3, hour, VoltageContribution_kV, .78, 'stacked');
for j = 1:nDev
    set(hVolt(j), 'FaceColor', deviceColors(j,:), 'EdgeColor', 'none');
end
hVoltTotal = plot(ax3, hour, TotalVoltageRegulation_kV, '-o', 'Color', black, ...
    'MarkerFaceColor', black, 'MarkerSize', 3.6, 'LineWidth', 0.9);
fig8_format_axis(ax3);
xlabel(ax3, 'Time/h');
ylabel(ax3, 'Voltage/kV');
legend(ax3, [hVolt(:); hVoltTotal], {'REC Reg', 'CB Reg', 'OLTC Reg', 'SVG Reg', 'INV Reg', 'Total Reg'}, ...
    'Location', 'northwest', 'FontName', 'Times New Roman', 'FontSize', 8, 'Box', 'off');
text(ax3, .5, -0.19, '(c) Contributions of reactive devices to voltage', 'Units', 'normalized', ...
    'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 13);
text(ax3, .5, -0.295, 'regulation', 'Units', 'normalized', ...
    'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 13);

pngPath = fullfile(workspaceDir, 'Figure8_DeviceCoordination_Real.png');
figPath = fullfile(workspaceDir, 'Figure8_DeviceCoordination_Real.fig');
pdfPath = fullfile(workspaceDir, 'Figure8_DeviceCoordination_Real.pdf');
savefig(fig, figPath);
print(fig, pngPath, '-dpng', '-r600');
print(fig, pdfPath, '-dpdf', '-painters', '-bestfit');

results = struct();
results.bestX = bestX;
results.trace = trace;
results.base = base;
results.ablationModes = ablationModes;
results.ablationNames = ablationNames;
results.ablation = abl;
results.dataTable = dataTable;
results.diagnostics = diagnostics;
save(fullfile(workspaceDir, 'Figure8_DeviceCoordination_Real_Results.mat'), 'results');

fprintf('\nSaved files:\n');
fprintf('  %s\n', pngPath);
fprintf('  %s\n', figPath);
fprintf('  %s\n', pdfPath);
fprintf('  %s\n', fullfile(workspaceDir, 'Figure8_DeviceCoordination_Real_Data.csv'));
fprintf('  %s\n', fullfile(workspaceDir, 'Figure8_DeviceCoordination_Real_Diagnostics.csv'));
fprintf('  %s\n', fullfile(workspaceDir, 'Figure8_DeviceCoordination_Real_Results.mat'));

fprintf('\nConclusion:\n');
fprintf(['The optimized Case 8 strategy is feasible under MATPOWER AC verification. ', ...
    'The device-level loss-reduction and voltage-regulation bars are obtained ', ...
    'from leave-one-device-out DSO redispatch and AC power-flow verification, ', ...
    'not from random generation or hand-edited display data.\n']);

function sim = fig8_run_device_ablation(d, base, mode)
    dCase = d;
    switch lower(mode)
        case 'all_off'
            dCase.disablePVReactive = true;
            dCase.disableWindReactive = true;
            dCase.disableSVG = true;
            dCase.disableCB = true;
            dCase.fixTap = true;
        case 'without_rec'
            dCase.disableWindReactive = true;
        case 'without_cb'
            dCase.disableCB = true;
        case 'without_oltc'
            dCase.fixTap = true;
        case 'without_svg'
            dCase.disableSVG = true;
        case 'without_inv'
            dCase.disablePVReactive = true;
        otherwise
            error('Unknown device-ablation mode: %s', mode);
    end
    netLoad = base.user.load + base.eso.charge - base.eso.discharge;
    grid = r21_network_dispatch(dCase, netLoad, base.reo);
    [acV, acLoss, acOK] = r21_ac_verify(dCase, netLoad, grid);
    sim.mode = mode;
    sim.grid = grid;
    sim.ac_voltage = acV;
    sim.ac_loss_kW = acLoss(:);
    sim.voltage_deviation_kV = max(abs(acV - 1), [], 1)' * d.baseKV;
    sim.NetworkFeasible = grid.feasible && acOK;
    sim.MinVoltage_pu = min(acV(:));
    sim.MaxVoltage_pu = max(acV(:));
end

function attrib = fig8_normalize_positive_attribution(rawPositive, totalImprovement)
    [T, nDev] = size(rawPositive);
    attrib = zeros(T, nDev);
    for t = 1:T
        denom = sum(rawPositive(t,:));
        if totalImprovement(t) > 0 && denom > 0
            attrib(t,:) = rawPositive(t,:) ./ denom .* totalImprovement(t);
        end
    end
end

function yLim = fig8_ylim(y)
    y = y(isfinite(y));
    if isempty(y)
        yLim = [0 1];
        return;
    end
    lo = min(0, min(y));
    hi = max(y);
    if hi <= lo
        hi = lo + 1;
    end
    span = hi - lo;
    yLim = [lo - 0.08*span, hi + 0.12*span];
end

function fig8_panel_background(ax, xLim, yLim)
    topColor = [253 193 193]/255;       % #FDC1C1
    bottomColor = [172 255 255]/255;    % #ACFFFF
    nGrad = 256;
    grad = zeros(nGrad, 2, 3);
    for k = 1:nGrad
        a = (k-1)/(nGrad-1);
        c = (1-a)*bottomColor + a*topColor;
        grad(k,:,1) = c(1);
        grad(k,:,2) = c(2);
        grad(k,:,3) = c(3);
    end
    image(ax, xLim, yLim, grad);
    set(ax, 'YDir', 'normal');
    xlim(ax, xLim);
    ylim(ax, yLim);
end

function fig8_format_axis(ax)
    set(ax, 'FontName', 'Times New Roman', 'FontSize', 10, ...
        'LineWidth', 0.8, 'Box', 'on', 'Layer', 'top', ...
        'XGrid', 'off', 'YGrid', 'off', 'XLim', [0 24], ...
        'XTick', 0:2:24, 'Color', 'none');
end
