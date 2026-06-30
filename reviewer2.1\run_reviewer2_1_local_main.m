%% Reviewer 2.1 - manuscript local deviation test
% Main-text neighbourhood: +/-0.5%, +/-1%, +/-2%.
% The existing Reviewer2_1_Real_* +/-1%, +/-3%, +/-5% outputs are retained
% unchanged as the supplementary sensitivity check.
clc; clear; close all;
rootDir=fileparts(fileparts(mfilename('fullpath'))); outDir=fileparts(mfilename('fullpath'));
addpath(rootDir); addpath(outDir);
runLog=fullfile(outDir,'Reviewer2_1_Local_RunLog.txt');
if exist(runLog,'file'), delete(runLog); end
diary(runLog); diaryCleanup=onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Reviewer 2.1 manuscript local test started: %s\n',datestr(now,30));
fprintf('MATLAB version: %s\n',version);
assert(~isempty(which('sdpvar')),'YALMIP is unavailable.');
assert(~isempty(which('cplexmilp')),'CPLEX MATLAB interface is unavailable.');
assert(~isempty(which('runpf')),'MATPOWER is unavailable.');

data=r21_build_data();
sourceMat=fullfile(outDir,'Reviewer2_1_Real_Results.mat');
assert(exist(sourceMat,'file')==2,'Run the supplementary validation first: source MAT is missing.');
source=load(sourceMat,'bestX'); bestX=source.bestX;
assert(numel(bestX)==3 && all(isfinite(bestX)),'Invalid bestX in source MAT.');
fprintf('Using reproducible CPSO bestX from %s\n',sourceMat);
fprintf('Baseline scales [TOU GCC mu] = [%.9f %.9f %.9f]\n',bestX);
fprintf('Domains LB=[%.9f %.9f %.9f], UB=[%.9f %.9f %.9f]\n',data.leaderLB,data.leaderUB);

% Re-solve the baseline rather than reusing stored follower outcomes.
base=r21_solve_case(data,bestX(1),bestX(2),bestX(3));
levels=[-2 -1 -.5 .5 1 2]; names={'TOU price','GCC reward','mu'};
n=1+3*numel(levels); labels=cell(n,1); scales=repmat(bestX,n,1);
labels{1}='Baseline Case 8'; row=1;
for j=1:3
    for k=1:numel(levels)
        row=row+1;
        labels{row}=sprintf('%s %+.1f%%',names{j},levels(k));
        scales(row,j)=bestX(j)*(1+levels(k)/100);
    end
end

EMO_profit=nan(n,1); Deviation_gain=nan(n,1); Deviation_gain_pct=nan(n,1);
User_profit=nan(n,1); REO_profit=nan(n,1); ESO_profit=nan(n,1);
Renewable_penetration=nan(n,1); Average_AC_loss=nan(n,1);
Average_voltage_deviation=nan(n,1); Min_voltage=nan(n,1); Max_voltage=nan(n,1);
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
        fprintf('[%02d/%02d] %-21s REJECTED: %s\n',i,n,labels{i},RejectReason{i});
        continue;
    end
    if i>1
        try
            % Mandatory fresh lower-level and AC solution for every feasible test.
            detail{i}=r21_solve_case(data,scales(i,1),scales(i,2),scales(i,3));
        catch ME
            SolverFailed(i)=true; SolverMessage{i}=ME.message;
            RejectReason{i}=['Solver failed: ' ME.message];
            fprintf('[%02d/%02d] %-21s SOLVER FAILED: %s\n',i,n,labels{i},ME.message);
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
    elseif NoEffectiveChange(i)
        RejectReason{i}='Accepted but no effective parameter change (baseline scale is zero)';
    else
        RejectReason{i}='Accepted';
    end
    fprintf('[%02d/%02d] %-21s leader=%d network=%d EMO=%.6f\n',...
        i,n,labels{i},LeaderFeasible(i),NetworkFeasible(i),EMO_profit(i));
end

Deviation_gain=EMO_profit-EMO_profit(1);
Deviation_gain_pct=100*Deviation_gain/max(abs(EMO_profit(1)),eps);
Feasible=LeaderFeasible & NetworkFeasible & ~SolverFailed;
Result=table(labels,scales(:,1),scales(:,2),scales(:,3),EMO_profit,Deviation_gain,Deviation_gain_pct,...
    User_profit,REO_profit,ESO_profit,Renewable_penetration,Average_AC_loss,...
    Average_voltage_deviation,Min_voltage,Max_voltage,Feasible,LeaderFeasible,NetworkFeasible,...
    RejectReason,ViolatesPriceLB,ViolatesPriceUB,ViolatesGCCLB,ViolatesGCCUB,...
    ViolatesMuLB,ViolatesMuUB,ViolatesVoltage,SolverFailed,NoEffectiveChange,...
    'VariableNames',{'Strategy','PriceScale','GCCScale','MuScale','EMOProfit_CNY',...
    'DeviationGain_CNY','DeviationGain_pct','UserProfit_CNY','REOProfit_CNY','ESOProfit_CNY',...
    'RenewablePenetration_pct','AverageACLoss_kW','AverageVoltageDeviation_pu',...
    'MinVoltage_pu','MaxVoltage_pu','Feasible','LeaderFeasible','NetworkFeasible','RejectReason',...
    'ViolatesPriceLB','ViolatesPriceUB','ViolatesGCCLB','ViolatesGCCUB','ViolatesMuLB','ViolatesMuUB',...
    'ViolatesVoltage','SolverFailed','NoEffectiveChange'});

Diagnostics=table(labels,scales(:,1),scales(:,2),scales(:,3),LeaderFeasible,NetworkFeasible,Feasible,...
    RejectReason,ViolatesPriceLB,ViolatesPriceUB,ViolatesGCCLB,ViolatesGCCUB,ViolatesMuLB,ViolatesMuUB,...
    ViolatesVoltage,SolverFailed,SolverMessage,NoEffectiveChange,UserResolved,REOResolved,ESOResolved,...
    DSOResolved,MATPOWERResolved,...
    'VariableNames',{'Strategy','PriceScale','GCCScale','MuScale','LeaderFeasible','NetworkFeasible','Feasible',...
    'RejectReason','ViolatesPriceLB','ViolatesPriceUB','ViolatesGCCLB','ViolatesGCCUB','ViolatesMuLB','ViolatesMuUB',...
    'ViolatesVoltage','SolverFailed','SolverMessage','NoEffectiveChange','UserResolved','REOResolved','ESOResolved',...
    'DSOResolved','MATPOWERResolved'});

valid=Feasible & ~NoEffectiveChange; valid(1)=false; validIdx=find(valid);
if isempty(validIdx)
    maxGain=NaN; maxGainPct=NaN; maxGainStrategy={'None'};
else
    [maxGain,localIdx]=max(Deviation_gain(validIdx)); idx=validIdx(localIdx);
    maxGainPct=Deviation_gain_pct(idx); maxGainStrategy=labels(idx);
end
epsilon=max([0;Deviation_gain(valid)]);
relativeEpsilonPct=100*epsilon/max(abs(EMO_profit(1)),eps);
tolerance=max(1,0.001*abs(EMO_profit(1)));
pass=Feasible(1) && ~isnan(maxGain) && maxGain<=tolerance;
Summary=table(EMO_profit(1),Feasible(1),maxGainStrategy,maxGain,maxGainPct,epsilon,...
    relativeEpsilonPct,tolerance,pass,...
    'VariableNames',{'BaselineEMOProfit_CNY','BaselineFeasible','MaxGainStrategy',...
    'MaxFeasibleDeviationGain_CNY','MaxFeasibleDeviationGain_pct','LocalEpsilon_CNY',...
    'RelativeEpsilonToAbsBaseline_pct','Tolerance_CNY','Pass'});

writetable(Result,fullfile(outDir,'Reviewer2_1_Local_Perturbation.csv'));
writetable(Summary,fullfile(outDir,'Reviewer2_1_Local_Summary.csv'));
writetable(Diagnostics,fullfile(outDir,'Reviewer2_1_Local_Diagnostics.csv'));
dataForSave=rmfield(data,'ops');
save(fullfile(outDir,'Reviewer2_1_Local_Results.mat'),'Result','Summary','Diagnostics',...
    'bestX','base','dataForSave','detail','levels');

fig=figure('Color','w','Position',[100 100 1300 560]);
plotGain=Deviation_gain_pct; plotGain(~isfinite(plotGain))=0;
validBar=plotGain; validBar(~Feasible)=0;
hBar=bar(validBar,'FaceColor',[.12 .47 .71]); hold on;
hZero=plot([.5 n+.5],[0 0],'k--','LineWidth',1); grid on;
hDomain=plot(nan,nan,'rx','MarkerSize',9,'LineWidth',1.8);
plot(find(~LeaderFeasible),zeros(sum(~LeaderFeasible),1),'rx','MarkerSize',9,'LineWidth',1.8);
hNetwork=plot(nan,nan,'k^','MarkerSize',8,'LineWidth',1.5,'MarkerFaceColor',[.65 .65 .65]);
networkRejected=find(LeaderFeasible & ~NetworkFeasible & ~SolverFailed);
plot(networkRejected,zeros(size(networkRejected)),'k^','MarkerSize',8,'LineWidth',1.5,'MarkerFaceColor',[.65 .65 .65]);
hSolver=plot(nan,nan,'md','MarkerSize',7,'LineWidth',1.5);
plot(find(SolverFailed),zeros(sum(SolverFailed),1),'md','MarkerSize',7,'LineWidth',1.5);
set(gca,'XTick',1:n,'XTickLabel',labels,'XTickLabelRotation',38);
ylabel('EMO unilateral-deviation gain (%)');
title('Manuscript local deviation test (\pm0.5%, \pm1%, \pm2%)');
legend([hBar hDomain hNetwork hSolver hZero],{'Feasible deviation gain','Outside leader domain',...
    'Network infeasible','Solver failed','Zero-gain reference'},...
    'Location','southoutside','Orientation','horizontal');
saveas(fig,fullfile(outDir,'Reviewer2_1_Local_DeviationGainPct.png'));
savefig(fig,fullfile(outDir,'Reviewer2_1_Local_DeviationGainPct.fig'));

disp(Result); disp(Summary);
if pass
    fprintf(['Baseline Case 8 is feasible under MATPOWER AC verification. The maximum effective feasible local deviation gain is '...
        '%.6f CNY (%.6f%%), from %s. The positive-part epsilon is %.6f CNY (%.6f%%). PASS.\n'],...
        maxGain,maxGainPct,maxGainStrategy{1},epsilon,relativeEpsilonPct);
else
    fprintf(['LOCAL VALIDATION FAILED. Maximum effective feasible gain %.6f CNY (%.6f%%), from %s; '...
        'epsilon %.6f CNY, tolerance %.6f CNY.\n'],maxGain,maxGainPct,maxGainStrategy{1},epsilon,tolerance);
end
fprintf('Reviewer 2.1 manuscript local test finished: %s\n',datestr(now,30));
diary off;
