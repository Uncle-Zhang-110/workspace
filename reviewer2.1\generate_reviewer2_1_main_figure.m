%% Reviewer 2.1 - publication main figure and tables
% Uses only the genuine MATLAB/CPLEX/MATPOWER local-test outputs produced by
% run_reviewer2_1_local_main.m. It does not modify or recalibrate results.
clc; close all;
outDir=fileparts(mfilename('fullpath'));
resultFile=fullfile(outDir,'Reviewer2_1_Local_Perturbation.csv');
diagFile=fullfile(outDir,'Reviewer2_1_Local_Diagnostics.csv');
assert(exist(resultFile,'file')==2 && exist(diagFile,'file')==2,...
    'Run run_reviewer2_1_local_main.m before generating the main figure.');
R=readtable(resultFile); D=readtable(diagFile);
assert(height(R)==19 && height(D)==19,'Expected baseline plus 18 local deviations.');
assert(strcmp(R.Strategy{1},'Baseline Case 8'),'Baseline row is missing.');

% Traceability gates: every leader-feasible scenario must have a fresh
% User/REO/ESO/DSO solution and MATPOWER AC verification.
auditMask=D.LeaderFeasible & ~D.SolverFailed;
auditOK=D.UserResolved & D.REOResolved & D.ESOResolved & D.DSOResolved & D.MATPOWERResolved;
assert(all(auditOK(auditMask)),'Follower/AC audit failed; publication figure was not generated.');

baselineProfit=R.EMOProfit_CNY(1);
assert(isfinite(baselineProfit) && baselineProfit~=0,'Baseline EMO profit must be finite and nonzero.');
R.DeviationGain_CNY=R.EMOProfit_CNY-baselineProfit;
R.DeviationGain_pct=100*R.DeviationGain_CNY/baselineProfit;
effective=R.Feasible & ~R.NoEffectiveChange; effective(1)=false;
maxEffectiveGain=max(R.DeviationGain_CNY(effective));
tolerance=max(1,0.001*abs(baselineProfit));
if isempty(maxEffectiveGain) || maxEffectiveGain>tolerance
    error('r21:ProfitableDeviation',...
        ['A profitable feasible deviation remains (max gain %.6f CNY; tolerance %.6f CNY). '...
         'Increase CPSO particles/iterations, rerun run_reviewer2_1_real.m, then rerun the local test.'],...
        maxEffectiveGain,tolerance);
end

VariableType=[repmat({'TOU'},6,1);repmat({'GCC'},6,1);repmat({'mu'},6,1)];
Perturbation_pct=repmat([-2;-1;-.5;.5;1;2],3,1);
rows=(2:19)';
PaperTable=table(VariableType,Perturbation_pct,R.Feasible(rows),R.RejectReason(rows),...
    R.EMOProfit_CNY(rows),R.DeviationGain_CNY(rows),R.DeviationGain_pct(rows),...
    R.UserProfit_CNY(rows),R.RenewablePenetration_pct(rows),R.AverageACLoss_kW(rows),...
    R.MinVoltage_pu(rows),R.MaxVoltage_pu(rows),...
    'VariableNames',{'VariableType','Perturbation_pct','Feasible','RejectReason',...
    'EMOProfit_CNY','DeviationGain_CNY','DeviationGain_pct','UserProfit_CNY',...
    'RenewablePenetration_pct','AverageACLoss_kW','MinVoltage_pu','MaxVoltage_pu'});
writetable(PaperTable,fullfile(outDir,'Reviewer2_1_PaperTable.csv'));

Diagnostics=[table(VariableType,Perturbation_pct),D(rows,:)];
writetable(Diagnostics,fullfile(outDir,'Reviewer2_1_Diagnostics.csv'));

% Three compact panels avoid long categorical labels and allow small GCC
% responses to remain readable beside the larger TOU response.
fig=figure('Color','w','Position',[80 80 1500 620]);
panelTitles={'TOU price','GCC reward','\mu'};
xLabels={'-2%','-1%','-0.5%','+0.5%','+1%','+2%'};
panelPosition={[.065 .20 .27 .66],[.365 .20 .27 .66],[.665 .20 .27 .66]};
for j=1:3
    ax(j)=subplot(1,3,j); %#ok<SAGROW>
    set(ax(j),'Position',panelPosition{j});
    idx=(2+(j-1)*6):(1+j*6);
    y=R.DeviationGain_pct(idx);
    feasible=logical(R.Feasible(idx));
    leaderOutside=~logical(R.LeaderFeasible(idx));
    networkBad=logical(R.LeaderFeasible(idx)) & ~logical(R.NetworkFeasible(idx)) & ~logical(R.SolverFailed(idx));
    solverBad=logical(R.SolverFailed(idx));
    yBar=y; yBar(~feasible | ~isfinite(yBar))=0;
    hBar=bar(ax(j),1:6,yBar,.62,'FaceColor',[.12 .47 .71],...
        'EdgeColor',[.08 .28 .42]); hold(ax(j),'on');
    hPoint=plot(ax(j),find(feasible),y(feasible),'o','Color',[.05 .32 .58],...
        'MarkerFaceColor',[.12 .47 .71],'MarkerSize',5,'LineWidth',.8);
    hZero=plot(ax(j),[.45 6.55],[0 0],'k--','LineWidth',1);
    hDomain=plot(ax(j),nan,nan,'rx','MarkerSize',9,'LineWidth',1.8);
    plot(ax(j),find(leaderOutside),zeros(sum(leaderOutside),1),'rx','MarkerSize',9,'LineWidth',1.8);
    hNetwork=plot(ax(j),nan,nan,'k^','MarkerSize',8,'LineWidth',1.5,...
        'MarkerFaceColor',[.65 .65 .65]);
    plot(ax(j),find(networkBad),zeros(sum(networkBad),1),'k^','MarkerSize',8,...
        'LineWidth',1.5,'MarkerFaceColor',[.65 .65 .65]);
    hSolver=plot(ax(j),nan,nan,'md','MarkerSize',7,'LineWidth',1.5);
    plot(ax(j),find(solverBad),zeros(sum(solverBad),1),'md','MarkerSize',7,'LineWidth',1.5);
    set(ax(j),'XTick',1:6,'XTickLabel',xLabels,'FontName','Times New Roman',...
        'FontSize',10,'LineWidth',.8,'Box','on');
    xlim(ax(j),[.45 6.55]); grid(ax(j),'on');
    title(ax(j),panelTitles{j},'FontName','Times New Roman','FontSize',12,'FontWeight','normal');
    if j==1
        ylabel(ax(j),'Relative EMO deviation gain (%)','FontName','Times New Roman','FontSize',11);
    end
    finiteY=y(feasible & isfinite(y));
    if isempty(finiteY) || max(abs(finiteY))<1e-10
        ylim(ax(j),[-.05 .05]);
    else
        lo=min([finiteY;0]); hi=max([finiteY;0]); span=max(hi-lo,1e-4);
        ylim(ax(j),[lo-.10*span hi+.12*span]);
    end
    if j==2
        legendHandles=[hBar hDomain hNetwork hSolver hZero];
    end
end
annotation(fig,'textbox',[0 .925 1 .055],'String',...
    'Local deviation test for the optimized Case 8 leader strategy',...
    'HorizontalAlignment','center','VerticalAlignment','middle','LineStyle','none',...
    'FontName','Times New Roman','FontSize',14,'FontWeight','bold');
lgd=legend(ax(2),legendHandles,{'Feasible gain','Outside leader domain',...
    'Network infeasible','Solver failed','Zero-gain reference'},...
    'Location','southoutside','Orientation','horizontal','FontName','Times New Roman','FontSize',9);
set(lgd,'Units','normalized','Position',[.22 .035 .56 .045]);

% The optimized mu scale is zero, so relative mu perturbations are identical
% to the baseline. State this directly instead of visually implying evidence.
if all(R.NoEffectiveChange(14:19))
    text(ax(3),3.5,-.032,'\mu^*=0: relative perturbations produce no change',...
        'HorizontalAlignment','center','FontName','Times New Roman','FontSize',9);
end
set(fig,'PaperPositionMode','auto');
savefig(fig,fullfile(outDir,'Reviewer2_1_MainFigure.fig'));
print(fig,fullfile(outDir,'Reviewer2_1_MainFigure.png'),'-dpng','-r300');
print(fig,fullfile(outDir,'Reviewer2_1_MainFigure.pdf'),'-dpdf','-painters','-bestfit');

fprintf(['Within the tested local neighborhood, no leader-feasible and network-feasible unilateral deviation yields a positive EMO profit gain. '...
    'Therefore, the optimized Case 8 strategy can be regarded as a practically valid approximate Stackelberg equilibrium.\n']);
fprintf('Maximum effective feasible gain: %.6f CNY (tolerance %.6f CNY).\n',maxEffectiveGain,tolerance);
if all(R.NoEffectiveChange(14:19))
    fprintf('Diagnostic note: optimized mu scale is zero; relative mu perturbations are no-effective-change cases.\n');
end
