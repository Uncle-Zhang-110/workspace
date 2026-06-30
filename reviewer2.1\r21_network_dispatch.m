function g=r21_network_dispatch(d,totalLoad,reo)
% Hourly LinDistFlow security dispatch. Each hour is an actual CPLEX MIQCP.
T=d.T; mpc=d.mpc0; nb=size(mpc.bus,1);
active=mpc.branch(:,11)>0; branch=mpc.branch(active,:); nl=size(branch,1);
from=branch(:,1); to=branch(:,2);
zbase=d.baseKV^2/d.baseMVA;
r=branch(:,3)/zbase; x=branch(:,4)/zbase;
basePd=mpc.bus(:,3); baseQd=mpc.bus(:,4);
pdShare=basePd/sum(basePd); qRatio=sum(baseQd)/sum(basePd);
if isfield(d,'dsoVoltageWeight')
    dsoVoltageWeight=d.dsoVoltageWeight;
else
    dsoVoltageWeight=0;
end
if isfield(d,'dsoVoltageAbsCap')
    dsoVoltageAbsCap=d.dsoVoltageAbsCap;
else
    dsoVoltageAbsCap=[];
end
if isfield(d,'dsoVoltageCapPenalty')
    dsoVoltageCapPenalty=d.dsoVoltageCapPenalty;
else
    dsoVoltageCapPenalty=1e7;
end
if isfield(d,'disablePVReactive')
    disablePVReactive=logical(d.disablePVReactive);
else
    disablePVReactive=false;
end
if isfield(d,'disableWindReactive')
    disableWindReactive=logical(d.disableWindReactive);
else
    disableWindReactive=false;
end
if isfield(d,'disableSVG')
    disableSVG=logical(d.disableSVG);
else
    disableSVG=false;
end
if isfield(d,'disableCB')
    disableCB=logical(d.disableCB);
else
    disableCB=false;
end
if isfield(d,'fixTap')
    fixTap=logical(d.fixTap);
else
    fixTap=false;
end
if disableSVG
    svgMaxLocal=0;
else
    svgMaxLocal=d.svgMax;
end
if disableCB
    cbNLocal=0;
else
    cbNLocal=d.cbN;
end

g.Ppv=zeros(1,T); g.Pwind=zeros(1,T); g.Qpv=zeros(1,T); g.Qwind=zeros(1,T);
g.Qsvg=zeros(1,T); g.ncb=zeros(1,T); g.tap=zeros(1,T); g.v2=zeros(nb,T);
g.deviceCost=0; g.maxLinVoltageSlack=0; g.maxVoltageCapSlack=0; g.feasible=true;

for t=1:T
    P=sdpvar(nl,1); Q=sdpvar(nl,1); v=sdpvar(nb,1);
    Ppv=sdpvar(1); Pwind=sdpvar(1); Qpv=sdpvar(1); Qwind=sdpvar(1);
    Qsvg=sdpvar(1); ncb=intvar(1); tap=intvar(1); tapAbs=sdpvar(1);
    sLow=sdpvar(nb,1); sHigh=sdpvar(nb,1);
    capPenalty=0;
    qpvMax=reo.Qpv(t);
    qwindMax=reo.Qwind(t);
    if disablePVReactive, qpvMax=0; end
    if disableWindReactive, qwindMax=0; end
    C=[0<=Ppv<=reo.Ppv(t),0<=Pwind<=reo.Pwind(t),...
       0<=Qpv<=qpvMax,0<=Qwind<=qwindMax,...
       0<=Qsvg<=svgMaxLocal,0<=ncb<=cbNLocal,...
       tapAbs>=tap,tapAbs>=-tap,tapAbs>=0,...
       sLow>=0,sHigh>=0,v(1)==1+0.05*tap,...
       v>=d.vmin^2-sLow,v<=d.vmax^2+sHigh];
    if fixTap
        C=[C,tap==0]; %#ok<AGROW>
    else
        C=[C,-2<=tap<=2]; %#ok<AGROW>
    end
    if ~isempty(dsoVoltageAbsCap)
        if numel(dsoVoltageAbsCap)==1
            capT=dsoVoltageAbsCap;
        else
            capT=dsoVoltageAbsCap(min(t,numel(dsoVoltageAbsCap)));
        end
        sCap=sdpvar(nb,1);
        C=[C,sCap>=0,v<=1+capT+sCap,v>=1-capT-sCap]; %#ok<AGROW>
        capPenalty=dsoVoltageCapPenalty*sum(sCap);
    end
    PdMW=pdShare*totalLoad(t)/1000; QdMVAr=PdMW*qRatio;
    for ell=1:nl
        j=to(ell); children=find(from==j); pg=0; qg=0;
        if j==d.pvBus, pg=pg+Ppv/1000; qg=qg+Qpv/1000; end
        if j==d.windBus, pg=pg+Pwind/1000; qg=qg+Qwind/1000; end
        if j==d.svgBus, qg=qg+Qsvg/1000; end
        if j==d.cbBus, qg=qg+d.cbStep*ncb/1000; end
        C=[C,P(ell)==PdMW(j)-pg+sum(P(children)),...
            Q(ell)==QdMVAr(j)-qg+sum(Q(children)),...
            v(j)==v(from(ell))-2*(r(ell)*P(ell)/d.baseMVA+x(ell)*Q(ell)/d.baseMVA),...
            P(ell)^2+Q(ell)^2<=d.lineLimitMVA^2]; %#ok<AGROW>
    end
    loss=sum(r.*((P/d.baseMVA).^2+(Q/d.baseMVA).^2))*d.baseMVA*1000;
    curtail=(reo.Ppv(t)-Ppv)+(reo.Pwind(t)-Pwind);
    devCost=.02*Qsvg+.5*d.cbStep*ncb+2*tapAbs;
    voltageTrack=dsoVoltageWeight*sum((v-1).^2);
    securityPenalty=1e6*sum(sLow+sHigh);
    sol=optimize(C,100*curtail+loss+devCost+voltageTrack+securityPenalty+capPenalty,d.ops);
    assert(sol.problem==0,sprintf('DSO hour %d: %s',t,sol.info));
    g.Ppv(t)=value(Ppv); g.Pwind(t)=value(Pwind);
    g.Qpv(t)=value(Qpv); g.Qwind(t)=value(Qwind); g.Qsvg(t)=value(Qsvg);
    g.ncb(t)=round(value(ncb)); g.tap(t)=round(value(tap)); g.v2(:,t)=value(v);
    g.deviceCost=g.deviceCost+value(devCost);
    g.maxLinVoltageSlack=max(g.maxLinVoltageSlack,max([value(sLow);value(sHigh)]));
    if ~isempty(dsoVoltageAbsCap)
        g.maxVoltageCapSlack=max(g.maxVoltageCapSlack,max(value(sCap)));
    end
end
g.feasible=g.maxLinVoltageSlack<=1e-5;
end
