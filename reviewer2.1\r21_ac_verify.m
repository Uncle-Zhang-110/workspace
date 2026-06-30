function [V,loss,ok]=r21_ac_verify(d,totalLoad,g)
% Exact MATPOWER AC verification for every hourly dispatch point.
T=d.T; nb=size(d.mpc0.bus,1); V=nan(nb,T); loss=nan(1,T); ok=true;
opt=mpoption('out.all',0,'verbose',0);
for t=1:T
    mpc=d.mpc0;
    sf=(totalLoad(t)/1000)/sum(mpc.bus(:,3));
    mpc.bus(:,3)=mpc.bus(:,3)*sf; mpc.bus(:,4)=mpc.bus(:,4)*sf;
    mpc.bus(d.pvBus,3)=mpc.bus(d.pvBus,3)-g.Ppv(t)/1000;
    mpc.bus(d.windBus,3)=mpc.bus(d.windBus,3)-g.Pwind(t)/1000;
    mpc.bus(d.pvBus,4)=mpc.bus(d.pvBus,4)-g.Qpv(t)/1000;
    mpc.bus(d.windBus,4)=mpc.bus(d.windBus,4)-g.Qwind(t)/1000;
    mpc.bus(d.svgBus,4)=mpc.bus(d.svgBus,4)-g.Qsvg(t)/1000;
    mpc.bus(d.cbBus,4)=mpc.bus(d.cbBus,4)-d.cbStep*g.ncb(t)/1000;
    mpc.branch(1,9)=1/(1+.025*g.tap(t));
    res=runpf(mpc,opt);
    if ~res.success, ok=false; continue; end
    V(:,t)=res.bus(:,8);
    loss(t)=sum(res.branch(:,14)+res.branch(:,16))*1000;
    ok=ok && min(V(:,t))>=d.vmin-1e-6 && max(V(:,t))<=d.vmax+1e-6;
end
end

