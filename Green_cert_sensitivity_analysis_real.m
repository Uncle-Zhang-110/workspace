%% Real GEC-price / reactive-valuation sensitivity analysis for Fig. 10(a,b)
% MATLAB R2018a compatible.
%
% This script replaces the old FAST_MODE estimation in
% Green_cert_sensitivity_analysis.m.  Every grid point is evaluated by the
% actual optimization chain:
%   r21_solve_case -> User/ESO/REO followers -> DSO MIQCP -> MATPOWER AC.
%
% No random generation and no hand-edited response surface values are used.

clc; close all;

workspaceDir = fileparts(mfilename('fullpath'));
reviewerDir = fullfile(workspaceDir, 'reviewer2.1');
addpath(reviewerDir);

fprintf('=============================================================\n');
fprintf(' Real Fig.10 sensitivity: GEC price x reactive valuation mu\n');
fprintf(' CPLEX followers + DSO MIQCP + MATPOWER AC at every grid point\n');
fprintf(' No random generation, no manually fitted surface values.\n');
fprintf('=============================================================\n\n');

% A compact 5x5 grid is used to keep the real AC-verified run practical in
% MATLAB R2018a.  Values cover the manuscript ranges:
%   GEC price: 0.05--0.30 CNY/kWh (50--300 CNY/MWh)
%   mu:        0--0.10
gecPrice_kWh = [0.05 0.08 0.12 0.18 0.30];
muValues = [0.00 0.02 0.04 0.07 0.10];
nP = numel(gecPrice_kWh);
nM = numel(muValues);

% Model-level tuning for a smooth physical response:
% - reactiveQCost/reactiveQQuadCost represent inverter/rectifier reactive
%   service wear cost, so the REO response increases gradually with the
%   economic signal and saturates at converter limits.
% - dsoVoltageWeight asks the DSO to use available reactive support for
%   voltage control while still retaining the LinDistFlow loss term.
d0 = r21_build_data();
d0.reactiveQCost = 0.50;
d0.reactiveQQuadCost = 0.055;
d0.dsoVoltageWeight = 5e4;

% First obtain the Case-8 leader strategy around the manuscript baseline
% mu=0.05 and GEC price=0.05 CNY/kWh.  For the sensitivity surface itself,
% TOU and GCC scales are kept fixed while GEC price and mu are varied.
dLeader = d0;
dLeader.gecPrice = 0.05 * 1000;
dLeader.mu = 0.05;
dLeader.leaderLB(3) = 1;
dLeader.leaderUB(3) = 1;
fprintf('[1/3] Optimizing fixed-baseline Case 8 leader scales...\n');
[bestX, base, trace] = r21_optimize_leader(dLeader);
if ~base.feasible
    error('Baseline Case 8 is not feasible under MATPOWER AC verification.');
end
priceScale = bestX(1);
gccScale = bestX(2);
fprintf('      Fixed sensitivity leader scales: TOU %.6f, GCC %.6f\n', priceScale, gccScale);

avgLoss_kW = nan(nM, nP);
avgVoltageDeviation_kV = nan(nM, nP);
renewablePenetration_pct = nan(nM, nP);
totalReactive_kvarh = nan(nM, nP);
minVoltage_pu = nan(nM, nP);
maxVoltage_pu = nan(nM, nP);
emoProfit_CNY = nan(nM, nP);
reoProfit_CNY = nan(nM, nP);
feasible = false(nM, nP);
rejectReason = cell(nM, nP);

fprintf('\n[2/3] Running real sensitivity grid (%d x %d = %d AC-verified cases)...\n', nM, nP, nM*nP);
caseNo = 0;
for iM = 1:nM
    for iP = 1:nP
        caseNo = caseNo + 1;
        d = d0;
        d.gecPrice = gecPrice_kWh(iP) * 1000;  % r21 model uses CNY/MWh-scale certificate price
        d.mu = muValues(iM);
        fprintf('      [%02d/%02d] GEC %.3f CNY/kWh, mu %.3f ... ', caseNo, nM*nP, gecPrice_kWh(iP), muValues(iM));
        try
            out = r21_solve_case(d, priceScale, gccScale, 1);
            avgLoss_kW(iM,iP) = mean(out.ac_loss_kW);
            avgVoltageDeviation_kV(iM,iP) = mean(max(abs(out.ac_voltage - 1), [], 1)) * d.baseKV;
            renewablePenetration_pct(iM,iP) = out.renewable_penetration_pct;
            totalReactive_kvarh(iM,iP) = sum(out.grid.Qpv + out.grid.Qwind);
            minVoltage_pu(iM,iP) = min(out.ac_voltage(:));
            maxVoltage_pu(iM,iP) = max(out.ac_voltage(:));
            emoProfit_CNY(iM,iP) = out.EMO_profit;
            reoProfit_CNY(iM,iP) = out.REO_profit;
            feasible(iM,iP) = out.feasible;
            if out.feasible
                rejectReason{iM,iP} = '';
                fprintf('loss %.4f kW, Vdev %.4f kV, Q %.2f kvarh\n', ...
                    avgLoss_kW(iM,iP), avgVoltageDeviation_kV(iM,iP), totalReactive_kvarh(iM,iP));
            else
                rejectReason{iM,iP} = 'MATPOWER AC infeasible';
                fprintf('network infeasible\n');
            end
        catch ME
            rejectReason{iM,iP} = ME.message;
            fprintf('FAILED: %s\n', ME.message);
        end
    end
end

% Export long-form table.
nRows = nM*nP;
VariableMu = zeros(nRows,1);
GECPrice_CNY_per_kWh = zeros(nRows,1);
AverageACLoss_kW = zeros(nRows,1);
AverageVoltageDeviation_kV = zeros(nRows,1);
RenewablePenetration_pct = zeros(nRows,1);
TotalReactiveSupport_kvarh = zeros(nRows,1);
MinVoltage_pu = zeros(nRows,1);
MaxVoltage_pu = zeros(nRows,1);
EMOProfit_CNY = zeros(nRows,1);
REOProfit_CNY = zeros(nRows,1);
Feasible = false(nRows,1);
RejectReason = cell(nRows,1);
r = 0;
for iM = 1:nM
    for iP = 1:nP
        r = r + 1;
        VariableMu(r) = muValues(iM);
        GECPrice_CNY_per_kWh(r) = gecPrice_kWh(iP);
        AverageACLoss_kW(r) = avgLoss_kW(iM,iP);
        AverageVoltageDeviation_kV(r) = avgVoltageDeviation_kV(iM,iP);
        RenewablePenetration_pct(r) = renewablePenetration_pct(iM,iP);
        TotalReactiveSupport_kvarh(r) = totalReactive_kvarh(iM,iP);
        MinVoltage_pu(r) = minVoltage_pu(iM,iP);
        MaxVoltage_pu(r) = maxVoltage_pu(iM,iP);
        EMOProfit_CNY(r) = emoProfit_CNY(iM,iP);
        REOProfit_CNY(r) = reoProfit_CNY(iM,iP);
        Feasible(r) = feasible(iM,iP);
        RejectReason{r} = rejectReason{iM,iP};
    end
end
resultTable = table(VariableMu, GECPrice_CNY_per_kWh, AverageACLoss_kW, ...
    AverageVoltageDeviation_kV, RenewablePenetration_pct, TotalReactiveSupport_kvarh, ...
    MinVoltage_pu, MaxVoltage_pu, EMOProfit_CNY, REOProfit_CNY, Feasible, RejectReason);

writetable(resultTable, fullfile(workspaceDir, 'GreenCertSensitivity_Real_Data.csv'));

matrixTableLoss = array2table(avgLoss_kW, 'VariableNames', fig10_price_names(gecPrice_kWh));
matrixTableLoss = [table(muValues(:), 'VariableNames', {'mu'}) matrixTableLoss];
writetable(matrixTableLoss, fullfile(workspaceDir, 'GreenCertSensitivity_Real_LossMatrix.csv'));

matrixTableVoltage = array2table(avgVoltageDeviation_kV, 'VariableNames', fig10_price_names(gecPrice_kWh));
matrixTableVoltage = [table(muValues(:), 'VariableNames', {'mu'}) matrixTableVoltage];
writetable(matrixTableVoltage, fullfile(workspaceDir, 'GreenCertSensitivity_Real_VoltageMatrix.csv'));

diagnostics = table(priceScale, gccScale, bestX(3), base.EMO_profit, ...
    min(avgLoss_kW(:)), max(avgLoss_kW(:)), min(avgVoltageDeviation_kV(:)), max(avgVoltageDeviation_kV(:)), ...
    sum(feasible(:)), nM*nP, ...
    'VariableNames', {'FixedTOUScale', 'FixedGCCScale', 'BaselineMuScale', 'BaselineEMOProfit_CNY', ...
    'MinAverageACLoss_kW', 'MaxAverageACLoss_kW', 'MinAverageVoltageDeviation_kV', ...
    'MaxAverageVoltageDeviation_kV', 'FeasibleCases', 'TotalCases'});
writetable(diagnostics, fullfile(workspaceDir, 'GreenCertSensitivity_Real_Diagnostics.csv'));

save(fullfile(workspaceDir, 'GreenCertSensitivity_Real_Results.mat'), ...
    'gecPrice_kWh', 'muValues', 'avgLoss_kW', 'avgVoltageDeviation_kV', ...
    'renewablePenetration_pct', 'totalReactive_kvarh', 'minVoltage_pu', 'maxVoltage_pu', ...
    'emoProfit_CNY', 'reoProfit_CNY', 'feasible', 'rejectReason', 'bestX', 'trace', ...
    'priceScale', 'gccScale', 'd0');

fprintf('\n[3/3] Drawing Fig.10-style real response surfaces...\n');
[X, Y] = meshgrid(gecPrice_kWh, muValues);

figLoss = figure('Color','w','Position',[120 80 820 640], 'PaperPositionMode','auto');
surf(X, Y, avgLoss_kW, 'EdgeColor', [0.35 0.35 0.35], 'LineWidth', 0.35, 'FaceColor', 'interp');
colormap(figLoss, parula(256));
colorbar;
xlabel('GEC price (CNY/kWh)', 'FontName', 'Times New Roman', 'FontSize', 12);
ylabel('Reactive valuation coefficient \mu', 'FontName', 'Times New Roman', 'FontSize', 12);
zlabel('Average AC loss (kW)', 'FontName', 'Times New Roman', 'FontSize', 12);
title('Response surface of grid loss', 'FontName', 'Times New Roman', 'FontSize', 13);
set(gca, 'FontName', 'Times New Roman', 'FontSize', 11, 'LineWidth', 0.9);
grid on; box on; view(135, 28);
print(figLoss, fullfile(workspaceDir, 'GreenCertSensitivity_Real_Fig10a_LossSurface.png'), '-dpng', '-r600');
savefig(figLoss, fullfile(workspaceDir, 'GreenCertSensitivity_Real_Fig10a_LossSurface.fig'));
print(figLoss, fullfile(workspaceDir, 'GreenCertSensitivity_Real_Fig10a_LossSurface.pdf'), '-dpdf', '-painters', '-bestfit');

figVolt = figure('Color','w','Position',[160 100 820 640], 'PaperPositionMode','auto');
surf(X, Y, avgVoltageDeviation_kV, 'EdgeColor', [0.35 0.35 0.35], 'LineWidth', 0.35, 'FaceColor', 'interp');
colormap(figVolt, parula(256));
colorbar;
xlabel('GEC price (CNY/kWh)', 'FontName', 'Times New Roman', 'FontSize', 12);
ylabel('Reactive valuation coefficient \mu', 'FontName', 'Times New Roman', 'FontSize', 12);
zlabel('Average voltage deviation (kV)', 'FontName', 'Times New Roman', 'FontSize', 12);
title('Response surface of voltage deviation', 'FontName', 'Times New Roman', 'FontSize', 13);
set(gca, 'FontName', 'Times New Roman', 'FontSize', 11, 'LineWidth', 0.9);
grid on; box on; view(135, 28);
print(figVolt, fullfile(workspaceDir, 'GreenCertSensitivity_Real_Fig10b_VoltageSurface.png'), '-dpng', '-r600');
savefig(figVolt, fullfile(workspaceDir, 'GreenCertSensitivity_Real_Fig10b_VoltageSurface.fig'));
print(figVolt, fullfile(workspaceDir, 'GreenCertSensitivity_Real_Fig10b_VoltageSurface.pdf'), '-dpdf', '-painters', '-bestfit');

figBoth = figure('Color','w','Position',[80 80 1500 600], 'PaperPositionMode','auto');
ax1 = subplot(1,2,1);
surf(ax1, X, Y, avgLoss_kW, 'EdgeColor', [0.35 0.35 0.35], 'LineWidth', 0.25, 'FaceColor', 'interp');
xlabel(ax1, 'GEC price (CNY/kWh)'); ylabel(ax1, '\mu'); zlabel(ax1, 'Average AC loss (kW)');
title(ax1, '(a) Response surface of grid loss');
set(ax1, 'FontName', 'Times New Roman', 'FontSize', 10); grid(ax1, 'on'); box(ax1, 'on'); view(ax1, 135, 28);
ax2 = subplot(1,2,2);
surf(ax2, X, Y, avgVoltageDeviation_kV, 'EdgeColor', [0.35 0.35 0.35], 'LineWidth', 0.25, 'FaceColor', 'interp');
xlabel(ax2, 'GEC price (CNY/kWh)'); ylabel(ax2, '\mu'); zlabel(ax2, 'Average voltage deviation (kV)');
title(ax2, '(b) Response surface of voltage deviation');
set(ax2, 'FontName', 'Times New Roman', 'FontSize', 10); grid(ax2, 'on'); box(ax2, 'on'); view(ax2, 135, 28);
print(figBoth, fullfile(workspaceDir, 'GreenCertSensitivity_Real_Fig10ab_Combined.png'), '-dpng', '-r600');
savefig(figBoth, fullfile(workspaceDir, 'GreenCertSensitivity_Real_Fig10ab_Combined.fig'));
print(figBoth, fullfile(workspaceDir, 'GreenCertSensitivity_Real_Fig10ab_Combined.pdf'), '-dpdf', '-painters', '-bestfit');

fprintf('\nSaved real Fig.10 sensitivity outputs in:\n  %s\n', workspaceDir);
fprintf('  GreenCertSensitivity_Real_Data.csv\n');
fprintf('  GreenCertSensitivity_Real_LossMatrix.csv\n');
fprintf('  GreenCertSensitivity_Real_VoltageMatrix.csv\n');
fprintf('  GreenCertSensitivity_Real_Fig10a_LossSurface.png/.fig/.pdf\n');
fprintf('  GreenCertSensitivity_Real_Fig10b_VoltageSurface.png/.fig/.pdf\n');
fprintf('  GreenCertSensitivity_Real_Fig10ab_Combined.png/.fig/.pdf\n');

lossDelta = avgLoss_kW(1,1) - avgLoss_kW(end,end);
voltDelta = avgVoltageDeviation_kV(1,1) - avgVoltageDeviation_kV(end,end);
fprintf('\nResult check:\n');
fprintf('  From lowest incentive to highest incentive: average AC loss changes by %.6f kW.\n', lossDelta);
fprintf('  From lowest incentive to highest incentive: average voltage deviation changes by %.6f kV.\n', voltDelta);
fprintf('  If either value is negative, the real model does not support the desired monotonic claim under the current parameters.\n');

function names = fig10_price_names(prices)
    names = cell(1,numel(prices));
    for k = 1:numel(prices)
        names{k} = sprintf('GEC_%03d_CNY_per_MWh', round(prices(k)*1000));
    end
end
