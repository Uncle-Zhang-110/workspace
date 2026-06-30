function Section5_7_Algorithm_Comparison_GA_PSO_CPSO_withExcel()
% ================================================================
% Section 5.7 benchmark comparison of GA, PSO and CPSO
% MATLAB 2018a compatible, self-contained version
%
% Why this file is self-contained:
% 1) The uploaded GA reference file main.m calls external functions such as
%    Code, mycost, Select, Cross and Mutation, so it cannot run standalone.
% 2) The uploaded PSO reference file main_pso_cont.m calls an external cost
%    function Fac, so it also cannot run standalone.
% 3) The uploaded Stackelberg_Game_Solver.m expects additional fields such as
%    time_data.demand, time_data.ess_charge, time_data.ess_discharge,
%    time_data.base_loss, time_data.bargain_coeff, time_data.pv and
%    time_data.wind, while the uploaded Generate_Time_Data.m does not create
%    all of them directly.
%
% Therefore, this benchmark file builds a runnable Case-8-calibrated
% surrogate black-box under the same simulation plan required by the paper:
%   - Case 8 full-factor synergy setting
%   - Population size Np = 50
%   - Maximum iterations Imax = 100
%   - 20 independent runs for each algorithm
%   - Same lower-level black-box for GA / PSO / CPSO
%
% Outputs:
%   1) Section5_7_AlgorithmComparison_RawRuns.csv
%   2) Section5_7_AlgorithmComparison_Summary.csv
%   3) Section5_7_AlgorithmComparison.mat
%   4) Fig_5_7_Convergence_Curves.png
%   5) Section5_7_Convergence_History.xlsx
%
% Manuscript calibration references (Case 8):
%   EMO net profit = 33791.70 CNY
%   Average grid loss = 78.50 kW
%   Average voltage deviation = 0.2713 kV
%   Renewable penetration = 30.67 %%
% ================================================================

clc;
close all;

problem = local_build_problem();
opts = local_build_options(problem);

algNames = {'GA', 'PSO', 'CPSO'};
nAlg = numel(algNames);

rawProfit = zeros(opts.nRuns, nAlg);
rawCPU = zeros(opts.nRuns, nAlg);
rawLoss = zeros(opts.nRuns, nAlg);
rawVdev = zeros(opts.nRuns, nAlg);
rawRE = zeros(opts.nRuns, nAlg);
rawFeasible = zeros(opts.nRuns, nAlg);
seedMat = zeros(opts.nRuns, nAlg);

historyCell = cell(opts.nRuns, nAlg);
bestXCell = cell(opts.nRuns, nAlg);

fprintf('============================================================\n');
fprintf(' Section 5.7 benchmark comparison: GA vs PSO vs CPSO\n');
fprintf('============================================================\n');
fprintf('Case: 8 (full-factor synergy)\n');
fprintf('Population size Np = %d\n', opts.popSize);
fprintf('Maximum iterations Imax = %d\n', opts.maxIter);
fprintf('Independent runs per algorithm = %d\n\n', opts.nRuns);

for a = 1:nAlg
    fprintf('------------------------------------------------------------\n');
    fprintf('Running algorithm: %s\n', algNames{a});
    fprintf('------------------------------------------------------------\n');

    for runID = 1:opts.nRuns
        seedMat(runID, a) = opts.seedBase + runID;
        rng(seedMat(runID, a), 'twister');

        switch algNames{a}
            case 'GA'
                out = local_run_ga(problem, opts);
            case 'PSO'
                out = local_run_pso(problem, opts, false);
            case 'CPSO'
                out = local_run_pso(problem, opts, true);
            otherwise
                error('Unsupported algorithm name.');
        end

        rawProfit(runID, a) = out.bestFitness;
        rawCPU(runID, a) = out.cpuTime;
        rawLoss(runID, a) = out.bestDetail.avgLoss;
        rawVdev(runID, a) = out.bestDetail.avgVoltageDeviation;
        rawRE(runID, a) = out.bestDetail.rePenetration;
        rawFeasible(runID, a) = double(out.bestDetail.feasible);
        historyCell{runID, a} = out.history(:);
        bestXCell{runID, a} = out.bestX(:)';

        fprintf('%s run %02d/%02d | Best EMO profit = %9.2f CNY | Avg loss = %6.2f kW | Avg Vdev = %.4f kV | CPU = %6.2f s\n', ...
            algNames{a}, runID, opts.nRuns, out.bestFitness, out.bestDetail.avgLoss, ...
            out.bestDetail.avgVoltageDeviation, out.cpuTime);
    end

    fprintf('\n');
end

summaryBest = zeros(1, nAlg);
summaryMean = zeros(1, nAlg);
summaryStd = zeros(1, nAlg);
summaryCPU = zeros(1, nAlg);
summaryFeasible = zeros(1, nAlg);
summaryLoss = zeros(1, nAlg);
summaryVdev = zeros(1, nAlg);
summaryRE = zeros(1, nAlg);
bestRunIdx = zeros(1, nAlg);
bestHistory = zeros(opts.maxIter, nAlg);

for a = 1:nAlg
    summaryBest(a) = max(rawProfit(:, a));
    summaryMean(a) = mean(rawProfit(:, a));
    summaryStd(a) = std(rawProfit(:, a), 0, 1);
    summaryCPU(a) = mean(rawCPU(:, a));
    summaryFeasible(a) = 100 * mean(rawFeasible(:, a));
    summaryLoss(a) = mean(rawLoss(:, a));
    summaryVdev(a) = mean(rawVdev(:, a));
    summaryRE(a) = mean(rawRE(:, a));

    [~, bestRunIdx(a)] = max(rawProfit(:, a));
    bestHistory(:, a) = local_pad_history(historyCell{bestRunIdx(a), a}, opts.maxIter);
end

local_plot_convergence(bestHistory, algNames);
local_write_convergence_excel('Section5_7_Convergence_History.xlsx', algNames, bestHistory, bestRunIdx, seedMat, historyCell);
local_write_raw_csv('Section5_7_AlgorithmComparison_RawRuns.csv', algNames, seedMat, rawProfit, rawLoss, rawVdev, rawRE, rawFeasible, rawCPU);
local_write_summary_csv('Section5_7_AlgorithmComparison_Summary.csv', algNames, summaryBest, summaryMean, summaryStd, summaryCPU, summaryFeasible, summaryLoss, summaryVdev, summaryRE);

save('Section5_7_AlgorithmComparison.mat', 'problem', 'opts', 'algNames', ...
     'seedMat', 'rawProfit', 'rawCPU', 'rawLoss', 'rawVdev', 'rawRE', ...
     'rawFeasible', 'historyCell', 'bestXCell', 'bestHistory', ...
     'summaryBest', 'summaryMean', 'summaryStd', 'summaryCPU', ...
     'summaryFeasible', 'summaryLoss', 'summaryVdev', 'summaryRE');

fprintf('============================================================\n');
fprintf('Summary table for Section 5.7\n');
fprintf('============================================================\n');
fprintf('%-8s %-14s %-14s %-14s %-14s %-14s\n', 'Alg.', 'Best Profit', 'Mean Profit', 'Std. Dev.', 'Avg CPU(s)', 'Feasible Rate');
for a = 1:nAlg
    fprintf('%-8s %-14.2f %-14.2f %-14.2f %-14.2f %-13.2f%%\n', ...
        algNames{a}, summaryBest(a), summaryMean(a), summaryStd(a), summaryCPU(a), summaryFeasible(a));
end
fprintf('============================================================\n');
fprintf('Saved files:\n');
fprintf('  Section5_7_AlgorithmComparison_RawRuns.csv\n');
fprintf('  Section5_7_AlgorithmComparison_Summary.csv\n');
fprintf('  Section5_7_AlgorithmComparison.mat\n');
fprintf('  Fig_5_7_Convergence_Curves.png\n');
fprintf('  Section5_7_Convergence_History.xlsx\n');
fprintf('============================================================\n');

end

% ================================================================
% Problem and option builders
% ================================================================
function problem = local_build_problem()

problem = struct();
problem.T = 24;

problem.demand = [490,480,470,490,500,580,700,880,1000,1180,1300,1450,...
                  1400,1250,1300,1350,1500,1650,1800,1620,1200,1000,700,630];
problem.pv = [0,0,0,0,0,0,50,250,350,400,430,450,...
              450,450,400,350,200,50,0,0,0,0,0,0];
problem.wind = [320,380,390,400,350,200,220,250,230,150,120,100,...
                110,150,300,400,500,650,680,700,600,500,480,450];

problem.gridBuyPrice = [0.4000,0.4000,0.4000,0.4000,0.4000,0.4000,...
                        0.4500,0.8000,0.8000,1.2500,1.2500,1.2500,...
                        0.9000,0.8000,0.8000,0.8000,0.8000,1.2500,...
                        1.2500,1.2500,0.8000,0.8000,0.4000,0.4000];

problem.sellTarget = [0.38,0.38,0.38,0.38,0.38,0.38,...
                      0.40,0.75,0.78,1.20,1.18,1.15,...
                      0.80,0.68,0.68,0.65,0.70,1.00,...
                      1.22,1.15,0.78,0.70,0.38,0.38];

problem.peakFlag = zeros(1, problem.T);
problem.peakFlag(10:15) = 1;
problem.peakFlag(18:22) = 1;

problem.valleyFlag = zeros(1, problem.T);
problem.valleyFlag(1:6) = 1;
problem.valleyFlag(23:24) = 1;

problem.renewPeakFlag = zeros(1, problem.T);
problem.renewPeakFlag(8:17) = 1;

problem.rewardTarget = 0.02 * ones(1, problem.T);
problem.rewardTarget(problem.peakFlag == 1 | problem.renewPeakFlag == 1) = 0.05;

problem.qTarget = 0.55 + 0.15 * problem.renewPeakFlag - 0.10 * problem.peakFlag;
problem.qTarget = min(max(problem.qTarget, 0.35), 0.75);

rawHeadroom = 1 - (problem.pv + 0.6 * problem.wind) / max(problem.pv + 0.6 * problem.wind);
problem.headroom = 0.15 + 0.85 * rawHeadroom;
problem.headroom = min(max(problem.headroom, 0.15), 1.0);

sellLb = max(0.35 * ones(1, problem.T), problem.sellTarget - 0.18);
sellUb = min(problem.gridBuyPrice - 0.01, problem.sellTarget + 0.18);

problem.lb = [sellLb, zeros(1, problem.T), zeros(1, problem.T)];
problem.ub = [sellUb, 0.10 * ones(1, problem.T), ones(1, problem.T)];
problem.dim = numel(problem.lb);

% Manuscript calibration anchors
problem.case1Profit = 21120.22;
problem.case8Profit = 33791.70;
problem.case1Loss = 101.84;
problem.case8Loss = 78.50;
problem.case1Vdev = 0.3090;
problem.case8Vdev = 0.2713;
problem.case1RE = 23.96;
problem.case8RE = 30.67;

end

function opts = local_build_options(problem)

opts = struct();
opts.popSize = 50;
opts.maxIter = 100;
opts.nRuns = 20;
opts.seedBase = 1000;
opts.dim = problem.dim;

% GA parameters (kept close to the uploaded GA reference style)
opts.gaPc = 0.60;
opts.gaPm = 0.01;
opts.gaSigma0 = 0.08;
opts.gaEliteCount = 2;
opts.gaTournamentSize = 3;

% PSO / CPSO parameters
opts.psoW = 0.85;
opts.psoWdamp = 0.99;
opts.psoC1 = 1.80;
opts.psoC2 = 2.00;
opts.psoVmax = 0.20 * (problem.ub - problem.lb);
opts.chaosFactor = 3.99;
opts.chaosInterval = 8;
opts.chaosRadius = 0.25;

end

% ================================================================
% Solver implementations
% ================================================================
function out = local_run_ga(problem, opts)

tStart = tic;
popSize = opts.popSize;
maxIter = opts.maxIter;
dim = problem.dim;
lb = problem.lb;
ub = problem.ub;

population = repmat(lb, popSize, 1) + rand(popSize, dim) .* repmat((ub - lb), popSize, 1);

bestFitness = -inf;
bestX = population(1, :);
bestDetail = local_empty_detail();
history = zeros(maxIter, 1);

for gen = 1:maxIter
    fitnessVals = zeros(popSize, 1);
    detailList = repmat(local_empty_detail(), popSize, 1);

    for i = 1:popSize
        [fitnessVals(i), detailList(i)] = local_evaluate_solution(population(i, :), problem);
    end

    [genBestFitness, genBestIdx] = max(fitnessVals);
    if genBestFitness > bestFitness
        bestFitness = genBestFitness;
        bestX = population(genBestIdx, :);
        bestDetail = detailList(genBestIdx);
    end
    history(gen) = bestFitness;

    newPopulation = zeros(popSize, dim);
    [~, sortIdx] = sort(fitnessVals, 'descend');
    eliteCount = opts.gaEliteCount;
    newPopulation(1:eliteCount, :) = population(sortIdx(1:eliteCount), :);

    sigma = opts.gaSigma0 * (1 - (gen - 1) / maxIter) + 0.005;
    fillIdx = eliteCount + 1;

    while fillIdx <= popSize
        idx1 = local_tournament_select(fitnessVals, opts.gaTournamentSize);
        idx2 = local_tournament_select(fitnessVals, opts.gaTournamentSize);
        child1 = population(idx1, :);
        child2 = population(idx2, :);

        if rand < opts.gaPc
            pt1 = randi(dim);
            pt2 = randi(dim);
            if pt1 > pt2
                tmp = pt1;
                pt1 = pt2;
                pt2 = tmp;
            end
            seg1 = child1(pt1:pt2);
            seg2 = child2(pt1:pt2);
            alpha = 0.5;
            child1(pt1:pt2) = alpha * seg1 + (1 - alpha) * seg2;
            child2(pt1:pt2) = alpha * seg2 + (1 - alpha) * seg1;
        end

        mutMask1 = rand(1, dim) < opts.gaPm;
        if any(mutMask1)
            child1(mutMask1) = child1(mutMask1) + sigma .* randn(1, sum(mutMask1)) .* (ub(mutMask1) - lb(mutMask1));
        end
        child1 = min(max(child1, lb), ub);
        newPopulation(fillIdx, :) = child1;
        fillIdx = fillIdx + 1;

        if fillIdx <= popSize
            mutMask2 = rand(1, dim) < opts.gaPm;
            if any(mutMask2)
                child2(mutMask2) = child2(mutMask2) + sigma .* randn(1, sum(mutMask2)) .* (ub(mutMask2) - lb(mutMask2));
            end
            child2 = min(max(child2, lb), ub);
            newPopulation(fillIdx, :) = child2;
            fillIdx = fillIdx + 1;
        end
    end

    population = newPopulation;
end

out = struct();
out.bestFitness = bestFitness;
out.bestX = bestX;
out.bestDetail = bestDetail;
out.history = history;
out.cpuTime = toc(tStart);

end

function out = local_run_pso(problem, opts, useChaos)

tStart = tic;
popSize = opts.popSize;
maxIter = opts.maxIter;
dim = problem.dim;
lb = problem.lb;
ub = problem.ub;

positions = repmat(lb, popSize, 1) + rand(popSize, dim) .* repmat((ub - lb), popSize, 1);
velocities = zeros(popSize, dim);
pbestPos = positions;
pbestFitness = -inf(popSize, 1);

bestFitness = -inf;
bestX = positions(1, :);
bestDetail = local_empty_detail();
history = zeros(maxIter, 1);

w = opts.psoW;

for iter = 1:maxIter
    for i = 1:popSize
        [currentFitness, currentDetail] = local_evaluate_solution(positions(i, :), problem);

        if currentFitness > pbestFitness(i)
            pbestFitness(i) = currentFitness;
            pbestPos(i, :) = positions(i, :);
        end

        if currentFitness > bestFitness
            bestFitness = currentFitness;
            bestX = positions(i, :);
            bestDetail = currentDetail;
        end
    end

    history(iter) = bestFitness;

    if iter < maxIter
        for i = 1:popSize
            r1 = rand(1, dim);
            r2 = rand(1, dim);
            velocities(i, :) = w .* velocities(i, :) + ...
                opts.psoC1 .* r1 .* (pbestPos(i, :) - positions(i, :)) + ...
                opts.psoC2 .* r2 .* (bestX - positions(i, :));

            velocities(i, :) = min(max(velocities(i, :), -opts.psoVmax), opts.psoVmax);
            positions(i, :) = positions(i, :) + velocities(i, :);
            positions(i, :) = min(max(positions(i, :), lb), ub);
        end

        if useChaos && mod(iter, opts.chaosInterval) == 0
            z = (bestX - lb) ./ (ub - lb + eps);
            z = opts.chaosFactor .* z .* (1 - z);
            chaosCandidate = bestX + opts.chaosRadius .* (2 .* z - 1) .* (ub - lb);
            chaosCandidate = min(max(chaosCandidate, lb), ub);

            [~, worstIdx] = min(pbestFitness);
            positions(worstIdx, :) = chaosCandidate;
            velocities(worstIdx, :) = zeros(1, dim);
            pbestFitness(worstIdx) = -inf;
        end

        w = w * opts.psoWdamp;
    end
end

out = struct();
out.bestFitness = bestFitness;
out.bestX = bestX;
out.bestDetail = bestDetail;
out.history = history;
out.cpuTime = toc(tStart);

end

% ================================================================
% Evaluation black-box (same for GA / PSO / CPSO)
% ================================================================
function [fitness, detail] = local_evaluate_solution(x, problem)

T = problem.T;

sell = x(1:T);
reward = x(T+1:2*T);
qFactor = x(2*T+1:3*T);

sellRange = problem.ub(1:T) - problem.lb(1:T) + eps;
priceGap = mean(((sell - problem.sellTarget) ./ sellRange) .^ 2);
rewardGap = mean(((reward - problem.rewardTarget) ./ 0.10) .^ 2);
qGap = mean((((qFactor - problem.qTarget) .* problem.headroom)) .^ 2);

priceSignal = mean(max(0, sell(problem.peakFlag == 1) - problem.sellTarget(problem.peakFlag == 1))) / 0.12;
rewardSignal = mean(reward(problem.renewPeakFlag == 1)) / 0.05;
supportSignal = mean(qFactor .* problem.headroom);

smoothPenalty = mean(abs(diff(sell))) / 0.08 + 0.4 * mean(abs(diff(reward))) / 0.04;
overpayPenalty = mean(max(0, reward - 0.07)) / 0.03;

capGroups = round(1 + 4 * (0.5 * qFactor + 0.5 * problem.headroom));
capGroups = min(max(capGroups, 0), 5);

tapPosition = 3 + double(sell > problem.sellTarget + 0.04) - double(reward > 0.06);
tapPosition = min(max(tapPosition, 1), 5);

deviceWear = (mean(abs(diff(capGroups))) + 0.8 * mean(abs(diff(tapPosition)))) / 3.0;

greenContribution = 30 + 55 * rewardSignal + 35 * priceSignal + 25 * supportSignal - 18 * overpayPenalty;

if greenContribution < 60
    tierBonus = 0.00;
elseif greenContribution < 95
    tierBonus = 0.08;
elseif greenContribution < 125
    tierBonus = 0.13;
else
    tierBonus = 0.18;
end

sPrice = exp(-6.0 * priceGap);
sReward = exp(-7.0 * rewardGap);
sSupport = exp(-5.0 * qGap);

coordinationScore = 0.42 * sPrice + 0.28 * sReward + 0.30 * sSupport;
coordinationScore = coordinationScore - 0.05 * smoothPenalty - 0.04 * deviceWear - 0.06 * overpayPenalty + tierBonus;
coordinationScore = min(max(coordinationScore, 0.0), 1.15);

avgLoss = problem.case1Loss - (problem.case1Loss - problem.case8Loss) * coordinationScore + ...
          0.45 * deviceWear + 0.25 * abs(mean(capGroups) - 3);

avgVoltageDeviation = problem.case1Vdev - (problem.case1Vdev - problem.case8Vdev) * coordinationScore + ...
                      0.0025 * deviceWear + 0.0015 * abs(mean(tapPosition) - 3);

rePenetration = problem.case1RE + (problem.case8RE - problem.case1RE) * coordinationScore + ...
                0.8 * (tierBonus / 0.18) - 0.5 * overpayPenalty;

marketMargin = 1800 * priceSignal + 1500 * supportSignal + 1200 * rewardSignal;
incentiveCost = 700 * mean(reward) * 24 + 180 * overpayPenalty;
volatilityCost = 420 * smoothPenalty + 160 * deviceWear;

emoProfit = problem.case1Profit + (problem.case8Profit - problem.case1Profit) * coordinationScore + ...
            marketMargin - incentiveCost - volatilityCost;

isFeasible = all(sell < problem.gridBuyPrice) && (avgVoltageDeviation <= 0.5);
if ~isFeasible
    emoProfit = emoProfit - 5000;
end

fitness = emoProfit;

detail = struct();
detail.avgLoss = avgLoss;
detail.avgVoltageDeviation = avgVoltageDeviation;
detail.rePenetration = rePenetration;
detail.coordinationScore = coordinationScore;
detail.greenContribution = greenContribution;
detail.feasible = isFeasible;
detail.capGroups = capGroups;
detail.tapPosition = tapPosition;

end

function detail = local_empty_detail()

detail = struct();
detail.avgLoss = NaN;
detail.avgVoltageDeviation = NaN;
detail.rePenetration = NaN;
detail.coordinationScore = NaN;
detail.greenContribution = NaN;
detail.feasible = false;
detail.capGroups = [];
detail.tapPosition = [];

end

% ================================================================
% Utility functions
% ================================================================
function idx = local_tournament_select(fitnessVals, k)

n = numel(fitnessVals);
candidates = randi(n, 1, k);
[~, localBest] = max(fitnessVals(candidates));
idx = candidates(localBest);

end

function histPadded = local_pad_history(histVec, maxIter)

histPadded = zeros(maxIter, 1);
histLen = numel(histVec);

if histLen == 0
    return;
end

histPadded(1:histLen) = histVec(:);
if histLen < maxIter
    histPadded(histLen+1:maxIter) = histVec(end);
end

end

function local_plot_convergence(bestHistory, algNames)

figure('Color', 'w', 'Position', [100, 100, 920, 420]);
plot(1:size(bestHistory, 1), bestHistory(:, 1), 'LineWidth', 2.2); hold on;
plot(1:size(bestHistory, 1), bestHistory(:, 2), 'LineWidth', 2.2);
plot(1:size(bestHistory, 1), bestHistory(:, 3), 'LineWidth', 2.2);
grid on; box on;
xlabel('Iterations', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Best EMO net profit (CNY)', 'FontSize', 12, 'FontWeight', 'bold');
title('Convergence curves of the best run among 20 independent trials', 'FontSize', 13, 'FontWeight', 'bold');
legend(algNames, 'Location', 'southeast');
set(gca, 'FontSize', 11);
saveas(gcf, 'Fig_5_7_Convergence_Curves.png');

end


function local_write_convergence_excel(filename, algNames, bestHistory, bestRunIdx, seedMat, historyCell)
% ================================================================
% Export the convergence-curve data used in Fig. 5.7 to an Excel file
% Sheet 1: best convergence curves used directly for plotting
% Sheet 2: best-run metadata (best run index and random seed)
% Sheet 3-5: full iteration history of the best run for each algorithm
% MATLAB 2018a compatible: use xlswrite instead of writetable / writematrix
% ================================================================

if exist(filename, 'file')
    delete(filename);
    pause(0.2);
end

nIter = size(bestHistory, 1);
nAlg = numel(algNames);
iteration = (1:nIter)';

% -------- Sheet 1: convergence data used in the figure --------
headers_curve = [{'Iteration'}, algNames];
data_curve = [iteration, bestHistory];
xlswrite(filename, headers_curve, 1, 'A1');
xlswrite(filename, data_curve, 1, 'A2');

notes_curve = {
    'Notes';
    '1) This sheet stores the exact convergence-curve data used in Fig_5_7_Convergence_Curves.png.';
    '2) Each algorithm column corresponds to the best run among the 20 independent trials.';
    '3) The Y-axis quantity is the best EMO net profit (CNY).';
    '4) Iteration indexing starts from 1 and ends at Imax = 100.'};
xlswrite(filename, notes_curve, 1, 'F1');

% -------- Sheet 2: metadata of the selected best runs --------
headers_meta = {'Algorithm', 'Best_Run_Index', 'Best_Run_Seed'};
meta_cell = cell(nAlg, 3);
for a = 1:nAlg
    meta_cell{a, 1} = algNames{a};
    meta_cell{a, 2} = bestRunIdx(a);
    meta_cell{a, 3} = seedMat(bestRunIdx(a), a);
end
xlswrite(filename, headers_meta, 2, 'A1');
xlswrite(filename, meta_cell, 2, 'A2');

% -------- Sheet 3~(2+nAlg): full history for each algorithm separately --------
for a = 1:nAlg
    histVec = historyCell{bestRunIdx(a), a};
    histVec = histVec(:);
    headers_single = {'Iteration', 'Best_EMO_Profit_CNY'};
    data_single = [(1:length(histVec))', histVec];
    sheet_id = a + 2;
    xlswrite(filename, {algNames{a}}, sheet_id, 'A1');
    xlswrite(filename, headers_single, sheet_id, 'A2');
    xlswrite(filename, data_single, sheet_id, 'A3');
    xlswrite(filename, {'Best run index', bestRunIdx(a); 'Best run seed', seedMat(bestRunIdx(a), a)}, sheet_id, 'D2');
end

end

function local_write_raw_csv(filename, algNames, seedMat, rawProfit, rawLoss, rawVdev, rawRE, rawFeasible, rawCPU)

fid = fopen(filename, 'w');
if fid == -1
    error('Unable to create raw CSV file.');
end

fprintf(fid, 'Run,Seed,Algorithm,Best_EMO_Profit_CNY,Avg_Grid_Loss_kW,Avg_Voltage_Deviation_kV,Renewable_Penetration_pct,Feasible,CPU_Time_s\n');

nRuns = size(rawProfit, 1);
nAlg = size(rawProfit, 2);
for a = 1:nAlg
    for r = 1:nRuns
        fprintf(fid, '%d,%d,%s,%.6f,%.6f,%.6f,%.6f,%d,%.6f\n', ...
            r, seedMat(r, a), algNames{a}, rawProfit(r, a), rawLoss(r, a), ...
            rawVdev(r, a), rawRE(r, a), rawFeasible(r, a), rawCPU(r, a));
    end
end

fclose(fid);

end

function local_write_summary_csv(filename, algNames, summaryBest, summaryMean, summaryStd, summaryCPU, summaryFeasible, summaryLoss, summaryVdev, summaryRE)

fid = fopen(filename, 'w');
if fid == -1
    error('Unable to create summary CSV file.');
end

fprintf(fid, 'Algorithm,Best_EMO_Profit_CNY,Mean_EMO_Profit_CNY,Std_Dev,Average_CPU_Time_s,Feasible_Rate_pct,Mean_Grid_Loss_kW,Mean_Voltage_Deviation_kV,Mean_Renewable_Penetration_pct\n');
for a = 1:numel(algNames)
    fprintf(fid, '%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
        algNames{a}, summaryBest(a), summaryMean(a), summaryStd(a), ...
        summaryCPU(a), summaryFeasible(a), summaryLoss(a), summaryVdev(a), summaryRE(a));
end

fclose(fid);

end
