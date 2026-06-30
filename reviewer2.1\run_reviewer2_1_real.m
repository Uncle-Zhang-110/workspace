%% Reviewer 2.1 - genuine local Stackelberg-equilibrium validation
% MATLAB R2018a / YALMIP / CPLEX / MATPOWER. No calibrated outputs.
clc; clear; close all;
rootDir=fileparts(fileparts(mfilename('fullpath'))); outDir=fileparts(mfilename('fullpath'));
addpath(rootDir); addpath(outDir);
runLog=fullfile(outDir,'Reviewer2_1_RunLog.txt');
if exist(runLog,'file'), delete(runLog); end
diary(runLog); diaryCleanup=onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Reviewer 2.1 genuine local validation started: %s\n',datestr(now,30));
fprintf('MATLAB version: %s\n',version);
assert(~isempty(which('sdpvar')),'YALMIP is unavailable.');
assert(~isempty(which('cplexmilp')),'CPLEX MATLAB interface is unavailable.');
assert(~isempty(which('runpf')),'MATPOWER is unavailable.');

data=r21_build_data();
fprintf('Leader domains [TOU GCC mu] LB=[%.6f %.6f %.6f], UB=[%.6f %.6f %.6f]\n',...
    data.leaderLB,data.leaderUB);
fprintf('Bound source TOU: %s\n',data.leaderBoundSource{1});
fprintf('Bound source GCC: %s\n',data.leaderBoundSource{2});
fprintf('Bound source mu : %s\n',data.leaderBoundSource{3});
fprintf('Optimising the Case-8 leader strategy with reproducible CPSO...\n');
[bestX,base,LeaderTrace]=r21_optimize_leader(data);
fprintf('Leader optimum scales: TOU=%.9f, GCC=%.9f, mu=%.9f, EMO=%.6f CNY\n',...
    bestX(1),bestX(2),bestX(3),base.EMO_profit);
fprintf('Leader optimum actual values: max TOU=%.9f CNY/kWh, GCC=%.9f, mu=%.9f\n',...
    max(data.tariff*bestX(1)),data.gccReward*bestX(2),data.mu*bestX(3));

levels=[-5 -3 -1 1 3 5]; names={'TOU price','GCC reward','mu'};
n=1+3*numel(levels); labels=cell(n,1); scales=repmat(bestX,n,1);
labels{1}='Baseline Case 8'; row=1;
for j=1:3
    for k=1:numel(levels)
        row=row+1; labels{row}=sprintf('%s %+d%%',names{j},levels(k));
        scales(row,j)=bestX(j)*(1+levels(k)/100);
    end
end

EMO_profit=nan(n,1); Deviation_gain=nan(n,1); User_profit=nan(n,1);
REO_profit=nan(n,1); ESO_profit=nan(n,1); Renewable_penetration=nan(n,1);
Average_AC_loss=nan(n,1); Average_voltage_deviation=nan(n,1);
Min_voltage=nan(n,1); Max_voltage=nan(n,1);
ViolatesPriceLB=scales(:,1)<data.leaderLB(1)-1e-12;
ViolatesPriceUB=scales(:,1)>data.leaderUB(1)+1e-12;
ViolatesGCCLB=scales(:,2)<data.leaderLB(2)-1e-12;
ViolatesGCCUB=scales(:,2)>data.leaderUB(2)+1e-12;
ViolatesMuLB=scales(:,3)<data.leaderLB(3)-1e-12;
ViolatesMuUB=scales(:,3)>data.leaderUB(3)+1e-12;
LeaderFeasible=~(ViolatesPriceLB|ViolatesPriceUB|ViolatesGCCLB|ViolatesGCCUB|ViolatesMuLB|ViolatesMuUB);
NoEffectiveChange=false(n,1);
for i=2:n, NoEffectiveChange(i)=all(abs(scales(i,:)-bestX)<=1e-12); end
NetworkFeasible=false(n,1); ViolatesVoltage=false(n,1); SolverFailed=false(n,1);
UserResolved=false(n,1); REOResolved=false(n,1); ESOResolved=false(n,1);
DSOResolved=false(n,1); MATPOWERResolved=false(n,1);
RejectReason=repmat({''},n,1); SolverMessage=repmat({''},n,1);
detail=cell(n,1); detail{1}=base;

for i=1:n
    reasons={};
    if ViolatesPriceLB(i), reasons{end+1}=sprintf('PriceScale %.9f < LB %.9f',scales(i,1),data.leaderLB(1)); end %#ok<SAGROW>
    if ViolatesPriceUB(i), reasons{end+1}=sprintf('PriceScale %.9f > UB %.9f',scales(i,1),data.leaderUB(1)); end %#ok<SAGROW>
    if ViolatesGCCLB(i), reasons{end+1}=sprintf('GCCScale %.9f < LB %.9f',scales(i,2),data.leaderLB(2)); end %#ok<SAGROW>
    if ViolatesGCCUB(i), reasons{end+1}=sprintf('GCCScale %.9f > UB %.9f',scales(i,2),data.leaderUB(2)); end %#ok<SAGROW>
    if ViolatesMuLB(i), reasons{end+1}=sprintf('MuScale %.9f < LB %.9f',scales(i,3),data.leaderLB(3)); end %#ok<SAGROW>
    if ViolatesMuUB(i), reasons{end+1}=sprintf('MuScale %.9f > UB %.9f',scales(i,3),data.leaderUB(3)); end %#ok<SAGROW>
    if ~LeaderFeasible(i)
        RejectReason{i}=strjoin(reasons,'; ');
        fprintf('[%02d/%02d] %-20s REJECTED: %s\n',i,n,labels{i},RejectReason{i});
        continue;
    end
    if i>1
        try
            % Full fresh solve: User, ESO, REO, DSO and MATPOWER AC.
            detail{i}=r21_solve_case(data,scales(i,1),scales(i,2),scales(i,3));
        catch ME
            SolverFailed(i)=true; SolverMessage{i}=ME.message;
            RejectReason{i}=['Solver failed: ' ME.message];
            fprintf('[%02d/%02d] %-20s SOLVER FAILED: %s\n',i,n,labels{i},ME.message);
            continue;
        end
    end
    d=detail{i}; NetworkFeasible(i)=d.feasible;
    UserResolved(i)=d.audit.UserResolved; REOResolved(i)=d.audit.REOResolved;
    ESOResolved(i)=d.audit.ESOResolved; DSOResolved(i)=d.audit.DSOResolved;
    MATPOWERResolved(i)=d.audit.MATPOWERResolved;
    EMO_profit(i)=d.EMO_profit; User_profit(i)=d.User_profit;
    REO_profit(i)=d.REO_profit; ESO_profit(i)=d.ESO_profit;
    Renewable_penetration(i)=d.renewable_penetration_pct;
    Average_AC_loss(i)=mean(d.ac_loss_kW);
    Average_voltage_deviation(i)=mean(abs(d.ac_voltage(:)-1));
    Min_voltage(i)=min(d.ac_voltage(:)); Max_voltage(i)=max(d.ac_voltage(:));
    ViolatesVoltage(i)=Min_voltage(i)<data.vmin-1e-6 || Max_voltage(i)>data.vmax+1e-6;
    if ~NetworkFeasible(i)
        if ViolatesVoltage(i)
            RejectReason{i}=sprintf('Network infeasible: MATPOWER AC voltage outside [%.4f, %.4f] p.u.',data.vmin,data.vmax);
        else
            RejectReason{i}='Network infeasible: DSO or MATPOWER AC verification failed';
        end
    else
        if NoEffectiveChange(i)
            RejectReason{i}='Accepted but no effective parameter change (baseline scale is zero)';
        else
            RejectReason{i}='Accepted';
        end
    end
    fprintf('[%02d/%02d] %-20s leader=%d network=%d EMO=%.6f minV=%.6f maxV=%.6f\n',...
        i,n,labels{i},LeaderFeasible(i),NetworkFeasible(i),EMO_profit(i),Min_voltage(i),Max_voltage(i));
end

Deviation_gain=EMO_profit-EMO_profit(1);
Feasible=LeaderFeasible & NetworkFeasible & ~SolverFailed;
Result=table(labels,scales(:,1),scales(:,2),scales(:,3),EMO_profit,Deviation_gain,...
    User_profit,REO_profit,ESO_profit,Renewable_penetration,Average_AC_loss,...
    Average_voltage_deviation,Min_voltage,Max_voltage,Feasible,LeaderFeasible,NetworkFeasible,...
    RejectReason,ViolatesPriceLB,ViolatesPriceUB,ViolatesGCCLB,ViolatesGCCUB,...
    ViolatesMuLB,ViolatesMuUB,ViolatesVoltage,SolverFailed,NoEffectiveChange,...
    'VariableNames',{'Strategy','PriceScale','GCCScale','MuScale','EMOProfit_CNY',...
    'DeviationGain_CNY','UserProfit_CNY','REOProfit_CNY','ESOProfit_CNY',...
    'RenewablePenetration_pct','AverageACLoss_kW','AverageVoltageDeviation_pu',...
    'MinVoltage_pu','MaxVoltage_pu','Feasible','LeaderFeasible','NetworkFeasible',...
    'RejectReason','ViolatesPriceLB','ViolatesPriceUB','ViolatesGCCLB','ViolatesGCCUB',...
    'ViolatesMuLB','ViolatesMuUB','ViolatesVoltage','SolverFailed','NoEffectiveChange'});

Diagnostics=table(labels,repmat(bestX(1),n,1),scales(:,1),repmat(data.leaderLB(1),n,1),repmat(data.leaderUB(1),n,1),...
    repmat(bestX(2),n,1),scales(:,2),repmat(data.leaderLB(2),n,1),repmat(data.leaderUB(2),n,1),...
    repmat(bestX(3),n,1),scales(:,3),repmat(data.leaderLB(3),n,1),repmat(data.leaderUB(3),n,1),...
    repmat(data.leaderBoundSource(1),n,1),repmat(data.leaderBoundSource(2),n,1),repmat(data.leaderBoundSource(3),n,1),...
    LeaderFeasible,NetworkFeasible,Feasible,RejectReason,ViolatesPriceLB,ViolatesPriceUB,...
    ViolatesGCCLB,ViolatesGCCUB,ViolatesMuLB,ViolatesMuUB,ViolatesVoltage,SolverFailed,SolverMessage,...
    UserResolved,REOResolved,ESOResolved,DSOResolved,MATPOWERResolved,NoEffectiveChange,...
    'VariableNames',{'Strategy','BaselinePriceScale','TestPriceScale','PriceLB','PriceUB',...
    'BaselineGCCScale','TestGCCScale','GCCLB','GCCUB','BaselineMuScale','TestMuScale','MuLB','MuUB',...
    'PriceBoundSource','GCCBoundSource','MuBoundSource',...
    'LeaderFeasible','NetworkFeasible','Feasible','RejectReason','ViolatesPriceLB','ViolatesPriceUB',...
    'ViolatesGCCLB','ViolatesGCCUB','ViolatesMuLB','ViolatesMuUB','ViolatesVoltage','SolverFailed','SolverMessage',...
    'UserResolved','REOResolved','ESOResolved','DSOResolved','MATPOWERResolved','NoEffectiveChange'});

valid=Feasible & ~NoEffectiveChange; valid(1)=false; validIdx=find(valid);
if isempty(validIdx)
    maxGain=NaN; maxGainStrategy={'None'};
else
    [maxGain,localIdx]=max(Deviation_gain(validIdx));
    maxGainStrategy=labels(validIdx(localIdx));
end
epsilon=max([0;Deviation_gain(valid)]);
relativeEpsilonPct=100*epsilon/max(abs(EMO_profit(1)),1);
tolerance=max(1,0.001*abs(EMO_profit(1)));
allWithinTolerance=~isnan(maxGain) && maxGain<=tolerance;
baselineFeasible=Feasible(1); pass=baselineFeasible && allWithinTolerance;
Summary=table(bestX(1),bestX(2),bestX(3),EMO_profit(1),baselineFeasible,maxGainStrategy,...
    maxGain,epsilon,relativeEpsilonPct,tolerance,allWithinTolerance,pass,...
    'VariableNames',{'OptimalPriceScale','OptimalGCCScale','OptimalMuScale',...
    'BaselineEMOProfit_CNY','BaselineFeasible','MaxGainStrategy','MaxFeasibleDeviationGain_CNY',...
    'LocalEpsilon_CNY','RelativeEpsilonToAbsBaseline_pct','Tolerance_CNY','AllFeasibleWithinTolerance','Pass'});

paperNames={'Baseline Case 8','TOU price +5%','TOU price -5%',...
    'GCC reward +5%','GCC reward -5%','mu +5%','mu -5%'};
paperIdx=zeros(numel(paperNames),1);
for k=1:numel(paperNames), paperIdx(k)=find(strcmp(labels,paperNames{k}),1); end
PaperTable=Result(paperIdx,{'Strategy','EMOProfit_CNY','DeviationGain_CNY','UserProfit_CNY',...
    'RenewablePenetration_pct','AverageACLoss_kW','MinVoltage_pu','MaxVoltage_pu','Feasible','RejectReason'});

writetable(Result,fullfile(outDir,'Reviewer2_1_Real_Perturbation.csv'));
writetable(Summary,fullfile(outDir,'Reviewer2_1_Real_Summary.csv'));
writetable(Diagnostics,fullfile(outDir,'Reviewer2_1_Real_Diagnostics.csv'));
writetable(PaperTable,fullfile(outDir,'Reviewer2_1_Paper_Table.csv'));
dataForSave=rmfield(data,'ops');
save(fullfile(outDir,'Reviewer2_1_Real_Results.mat'),'Result','Summary','Diagnostics',...
    'PaperTable','LeaderTrace','bestX','dataForSave','detail');

fig=figure('Color','w','Position',[100 100 1300 560]);
plotGain=Deviation_gain; plotGain(~isfinite(plotGain))=0;
validBar=plotGain; validBar(~Feasible)=0;
hBar=bar(validBar,'FaceColor',[.12 .47 .71]); hold on;
hZero=plot([.5 n+.5],[0 0],'k--','LineWidth',1); grid on;
outOfBounds=find(~LeaderFeasible);
hDomain=plot(nan,nan,'rx','MarkerSize',9,'LineWidth',1.8);
plot(outOfBounds,zeros(size(outOfBounds)),'rx','MarkerSize',9,'LineWidth',1.8);
networkRejected=find(LeaderFeasible & ~NetworkFeasible & ~SolverFailed);
hNetwork=plot(nan,nan,'k^','MarkerSize',8,...
    'LineWidth',1.5,'MarkerFaceColor',[.65 .65 .65]);
plot(networkRejected,zeros(size(networkRejected)),'k^','MarkerSize',8,...
    'LineWidth',1.5,'MarkerFaceColor',[.65 .65 .65]);
solverRejected=find(SolverFailed);
hSolver=plot(nan,nan,'md','MarkerSize',7,'LineWidth',1.5);
plot(solverRejected,zeros(size(solverRejected)),'md','MarkerSize',7,'LineWidth',1.5);
set(gca,'XTick',1:n,'XTickLabel',labels,'XTickLabelRotation',38);
ylabel('EMO unilateral-deviation gain (CNY)');
title('Local deviation test: CPSO + CPLEX followers + MATPOWER AC');
legend([hBar hDomain hNetwork hSolver hZero],{'Feasible deviation gain','Outside leader domain',...
    'Network infeasible','Solver failed','Zero-gain reference'},...
    'Location','southoutside','Orientation','horizontal');
saveas(fig,fullfile(outDir,'Reviewer2_1_Real_DeviationGain.png'));
savefig(fig,fullfile(outDir,'Reviewer2_1_Real_DeviationGain.fig'));

disp(Result); disp(Summary); disp(PaperTable);
if pass
    fprintf(['Baseline Case 8 is feasible under MATPOWER AC verification. Among all leader-feasible and network-feasible local deviations, '...
        'the maximum unilateral EMO profit gain is %.6f CNY (%s), corresponding to %.6f%% of the absolute baseline EMO profit. '...
        'Therefore, no profitable feasible unilateral deviation is found within the tested local neighborhood, supporting the obtained '...
        'solution as a practical approximate Stackelberg equilibrium.\n'],epsilon,maxGainStrategy{1},relativeEpsilonPct);
else
    fprintf(['VALIDATION FAILED. Baseline feasible=%d. Maximum feasible deviation gain=%.6f CNY (%s), epsilon=%.6f CNY, '...
        'relative epsilon=%.6f%%, tolerance=%.6f CNY. A stronger leader re-optimization is required before an equilibrium claim.\n'],...
        baselineFeasible,maxGain,maxGainStrategy{1},epsilon,relativeEpsilonPct,tolerance);
end
fprintf('Reviewer 2.1 genuine local validation finished: %s\n',datestr(now,30));
diary off;
