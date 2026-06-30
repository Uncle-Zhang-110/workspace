function out=r21_solve_case(d,priceScale,gccScale,muScale)
if nargin<4, muScale=1; end
T=d.T; tariff=d.tariff*priceScale; gcc=d.gccReward*gccScale;

%% User follower: convex MIQP with shiftable, curtailable and interruptible loads
Ls=sdpvar(1,T); Lc=sdpvar(1,T); Le=sdpvar(1,T); z=binvar(1,T);
baseS=.18*d.load; baseC=.06*d.load; baseE=.20*d.load;
baseI=.04*d.load; fixed=.52*d.load;
L=fixed+Ls+Lc+Le+baseI.*(1-z);
reFlag=double((d.pv+d.wind)>=prctile(d.pv+d.wind,60));
peakFlag=double(tariff>=prctile(tariff,70));
gccVolume=sum(reFlag.*Ls + peakFlag.*(baseC-Lc+baseI.*z));
% The elastic block gives the user a genuine consumption response to a
% common TOU-price change; the remaining blocks retain shifting/curtailment.
elasticUtility=sum(1.35*Le-0.00135/2*(Le.^2));
utility=elasticUtility+sum(1.10*(fixed+Ls+Lc+baseI.*(1-z)));
Cu=[.6*baseS<=Ls<=1.4*baseS, sum(Ls)==sum(baseS),...
    .5*baseC<=Lc<=baseC, .25*baseE<=Le<=1.10*baseE, sum(z)<=4];
objU=-(utility-sum(tariff.*L)+gcc*gccVolume);
sol=optimize(Cu,objU,d.ops); assert(sol.problem==0,sol.info);
user.load=value(L); user.gcc=value(gccVolume);
user.profit=value(utility-sum(tariff.*L)+gcc*gccVolume);

%% ESO follower: MILP arbitrage response
Pc=sdpvar(1,T); Pd=sdpvar(1,T); soc=sdpvar(1,T+1);
uc=binvar(1,T); ud=binvar(1,T);
Ce=[0<=Pc<=d.storageP*uc,0<=Pd<=d.storageP*ud,uc+ud<=1,...
    soc(1)==.5, soc(T+1)==soc(1), .2<=soc<=.9];
for t=1:T
    Ce=[Ce,soc(t+1)==soc(t)+(d.eta*Pc(t)-Pd(t)/d.eta)/d.storageE]; %#ok<AGROW>
end
objE=sum(tariff.*Pc-tariff.*Pd)+.01*sum(Pc+Pd);
sol=optimize(Ce,objE,d.ops); assert(sol.problem==0,sol.info);
eso.charge=value(Pc); eso.discharge=value(Pd); eso.profit=-value(objE);

%% REO follower: convex QCP with actual P-Q converter capability
Ppv=sdpvar(1,T); Pwind=sdpvar(1,T); Qpv=sdpvar(1,T); Qwind=sdpvar(1,T);
Cr=[0<=Ppv<=d.pv,0<=Pwind<=d.wind,0<=Qpv,0<=Qwind];
for t=1:T
    Cr=[Cr,Ppv(t)^2+Qpv(t)^2<=(d.pvS)^2,...
        Pwind(t)^2+Qwind(t)^2<=(d.windS)^2]; %#ok<AGROW>
end
qRate=d.mu*muScale*d.gecPrice;
if isfield(d,'reactiveQCost')
    reactiveQCost=d.reactiveQCost;
else
    reactiveQCost=.01;
end
if isfield(d,'reactiveQQuadCost')
    reactiveQQuadCost=d.reactiveQQuadCost;
else
    reactiveQQuadCost=0;
end
reoRevenue=sum(d.reoBuyPrice.*(Ppv+Pwind))+qRate*sum(Qpv+Qwind);
reoCost=.02*sum(Ppv)+.015*sum(Pwind)+reactiveQCost*sum(Qpv+Qwind)...
    +.5*reactiveQQuadCost*sum(Qpv.^2+Qwind.^2);
sol=optimize(Cr,-(reoRevenue-reoCost),d.ops); assert(sol.problem==0,sol.info);
reo.Ppv=value(Ppv); reo.Pwind=value(Pwind); reo.Qpv=value(Qpv); reo.Qwind=value(Qwind);

%% DSO physical gatekeeper: LinDistFlow MIQCP followed by AC verification
netLoad=user.load+eso.charge-eso.discharge;
grid=r21_network_dispatch(d,netLoad,reo);
[acV,acLoss,acOK]=r21_ac_verify(d,netLoad,grid);

renew=sum(grid.Ppv+grid.Pwind); sales=sum(user.load);
externalPower=max(netLoad-grid.Ppv-grid.Pwind,0);
external=sum(externalPower)+sum(acLoss);
cert=renew/1000; obligation=d.quota*sales/1000; gecPos=cert-obligation;
if gecPos>=0, gecSettlement=.5*d.gecPrice*gecPos;
else, gecSettlement=1.5*d.gecPrice*gecPos; end
gccPayment=gcc*user.gcc; qPayment=qRate*sum(grid.Qpv+grid.Qwind);
emoRevenue=sum(tariff.*user.load)+gecSettlement;
lossCost=mean(d.gridPrice)*sum(acLoss);
voltageDeviationCost=d.voltageDeviationPenalty*sum(abs(acV(:)-1));
acViolation=sum(max(d.vmin-acV(:),0)+max(acV(:)-d.vmax,0));
securityCost=voltageDeviationCost+d.acViolationPenalty*acViolation;
emoCost=sum(d.reoBuyPrice.*(grid.Ppv+grid.Pwind))+sum(d.gridPrice.*externalPower)...
    +lossCost+gccPayment+qPayment+grid.deviceCost+securityCost;

out.EMO_profit=emoRevenue-emoCost;
out.User_profit=user.profit;
% reoRevenue/reoCost are YALMIP expressions. Store their solved numeric
% value so scenario-detail MAT files contain no sdpvar objects.
out.REO_profit=value(reoRevenue-reoCost);
out.ESO_profit=eso.profit; out.renewable_penetration_pct=100*renew/sales;
out.ac_voltage=acV; out.ac_loss_kW=acLoss;
out.feasible=grid.feasible && acOK;
out.cost.loss=lossCost; out.cost.voltage=voltageDeviationCost;
out.cost.securityViolation=d.acViolationPenalty*acViolation;
% Per-call audit flags: reaching this point means every lower-level block
% was solved afresh for the strategy passed to this function.
out.audit.UserResolved=true; out.audit.ESOResolved=true;
out.audit.REOResolved=true; out.audit.DSOResolved=true;
out.audit.MATPOWERResolved=true;
out.user=user; out.eso=eso; out.reo=reo; out.grid=grid;
end
