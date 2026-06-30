%% Reviewer 2.1 - combined publication figure
% Reads genuine local-test results only; no model/data recalibration.
% MATLAB R2018a compatible. Figure text is English; output filename is Chinese.
clc; close all;

outDir=fileparts(mfilename('fullpath'));
exportDir=fileparts(outDir); % ...\实验2\workspace
resultFile=fullfile(outDir,'Reviewer2_1_Local_Perturbation.csv');
assert(exist(resultFile,'file')==2,...
    'Run run_reviewer2_1_local_main.m before generating figures.');

R=readtable(resultFile);
assert(height(R)==19 && strcmp(R.Strategy{1},'Baseline Case 8'),...
    'Unexpected local-test table structure.');

% Origin-style colours requested by the user.
% Gradient is drawn only inside each black axes box.
topColor=[253 193 193]/255;       % #FDC1C1
bottomColor=[172 255 255]/255;    % #ACFFFF
blue=[31 111 166]/255;
blueEdge=[15 70 110]/255;

xLabels={'-2%','-1%','-0.5%','+0.5%','+1%','+2%'};
xAxisLabels={...
    'TOU Price Perturbation (%)',...
    'GCC Reward Perturbation (%)',...
    'Mu Perturbation (%)'};
panelText={'(a) TOU','(b) GCC','(c) \mu'};

% One combined figure: white page outside the black axes boxes.
fig=figure('Color','w','Position',[80 120 1500 520]);

axPos=[...
    .065 .225 .275 .680;...
    .380 .225 .275 .680;...
    .695 .225 .275 .680];

nGrad=256;
grad=zeros(nGrad,2,3);
for k=1:nGrad
    a=(k-1)/(nGrad-1);
    c=(1-a)*bottomColor+a*topColor;
    grad(k,:,1)=c(1);
    grad(k,:,2)=c(2);
    grad(k,:,3)=c(3);
end

legendHandles=[];
legendText={};
hasLeaderOutside=false;
hasNetworkBad=false;
hasSolverBad=false;

for j=1:3
    idx=(2+(j-1)*6):(1+j*6);
    y=R.DeviationGain_pct(idx);
    feasible=logical(R.Feasible(idx));
    leaderOutside=~logical(R.LeaderFeasible(idx));
    networkBad=logical(R.LeaderFeasible(idx)) & ~logical(R.NetworkFeasible(idx)) & ~logical(R.SolverFailed(idx));
    solverBad=logical(R.SolverFailed(idx));
    noChange=logical(R.NoEffectiveChange(idx));
    hasLeaderOutside=hasLeaderOutside || any(leaderOutside);
    hasNetworkBad=hasNetworkBad || any(networkBad);
    hasSolverBad=hasSolverBad || any(solverBad);

    finiteY=y(feasible & isfinite(y));
    if isempty(finiteY) || max(abs(finiteY))<1e-10
        yLim=[-.05 .05];
    else
        lo=min([finiteY;0]);
        hi=max([finiteY;0]);
        span=max(hi-lo,1e-4);
        yLim=[lo-.10*span, hi+.14*span];
    end

    ax=axes('Parent',fig,'Position',axPos(j,:));

    % Background only inside the axes rectangle.
    image(ax,[.45 6.55],yLim,grad);
    set(ax,'YDir','normal');
    hold(ax,'on');

    yBar=y;
    yBar(~feasible | ~isfinite(yBar))=0;
    hBar=bar(ax,1:6,yBar,.62,'FaceColor',blue,'EdgeColor',blueEdge,'LineWidth',.8);
    plot(ax,find(feasible),y(feasible),'o','Color',blueEdge,...
        'MarkerFaceColor',blue,'MarkerSize',4.8,'LineWidth',.8);

    hZero=plot(ax,[.45 6.55],[0 0],'k--','LineWidth',1.05);

    hDomain=plot(ax,nan,nan,'rx','MarkerSize',8,'LineWidth',1.7);
    plot(ax,find(leaderOutside),zeros(sum(leaderOutside),1),'rx',...
        'MarkerSize',8,'LineWidth',1.7);

    hNetwork=plot(ax,nan,nan,'k^','MarkerSize',7,'LineWidth',1.4,...
        'MarkerFaceColor',[.65 .65 .65]);
    plot(ax,find(networkBad),zeros(sum(networkBad),1),'k^',...
        'MarkerSize',7,'LineWidth',1.4,'MarkerFaceColor',[.65 .65 .65]);

    hSolver=plot(ax,nan,nan,'md','MarkerSize',7,'LineWidth',1.4);
    plot(ax,find(solverBad),zeros(sum(solverBad),1),'md',...
        'MarkerSize',7,'LineWidth',1.4);

    set(ax,'XLim',[.45 6.55],'YLim',yLim,'XTick',1:6,'XTickLabel',xLabels,...
        'FontName','Times New Roman','FontSize',11,'LineWidth',1,'Box','on',...
        'Layer','top','Color','none','XGrid','off','YGrid','off');
    xlabel(ax,xAxisLabels{j},'FontName','Times New Roman','FontSize',12);
    if j==1
        ylabel(ax,'Relative EMO Deviation Gain (%)','FontName','Times New Roman','FontSize',12);
    end

    % Use small in-panel identifiers instead of titles.
    text(ax,.60,yLim(2)-.08*(yLim(2)-yLim(1)),panelText{j},...
        'FontName','Times New Roman','FontSize',11,'FontWeight','normal',...
        'BackgroundColor','none','Color',[0 0 0]);

    if any(noChange)
        text(ax,3.5,yLim(1)+.18*(yLim(2)-yLim(1)),...
            'Optimized mu = 0: no effective change',...
            'HorizontalAlignment','center','FontName','Times New Roman','FontSize',9,...
            'BackgroundColor',[1 1 1],'Margin',2);
    end

    if isempty(legendHandles)
        legendHandles=[hBar hDomain hNetwork hSolver hZero];
    end
end

plotHandles=legendHandles(1);
legendText={'Feasible deviation'};
if hasLeaderOutside
    plotHandles=[plotHandles legendHandles(2)]; %#ok<AGROW>
    legendText=[legendText {'Outside leader domain'}]; %#ok<AGROW>
end
if hasNetworkBad
    plotHandles=[plotHandles legendHandles(3)]; %#ok<AGROW>
    legendText=[legendText {'Network infeasible'}]; %#ok<AGROW>
end
if hasSolverBad
    plotHandles=[plotHandles legendHandles(4)]; %#ok<AGROW>
    legendText=[legendText {'Solver failed'}]; %#ok<AGROW>
end
plotHandles=[plotHandles legendHandles(5)];
legendText=[legendText {'Zero-gain reference'}];

lgd=legend(plotHandles,legendText,'Location','southoutside',...
    'Orientation','horizontal','FontName','Times New Roman','FontSize',10,...
    'Box','off');
set(lgd,'Units','normalized');
drawnow;
set(lgd,'Position',[.345 .050 .390 .055]);

set(fig,'PaperPositionMode','auto');

outStem=char([19977 21442 25968 23616 37096 25200 21160 21512 25104 22270]); % 三参数局部扰动合成图
savefig(fig,fullfile(exportDir,[outStem '.fig']));
print(fig,fullfile(exportDir,[outStem '.png']),'-dpng','-r300');
print(fig,fullfile(exportDir,[outStem '.pdf']),'-dpdf','-painters','-bestfit');

fprintf('Combined figure generated with white outer background and gradient only inside axes.\n');
fprintf('Output directory: %s\n',exportDir);
