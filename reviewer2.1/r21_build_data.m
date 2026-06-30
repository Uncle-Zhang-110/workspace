function d=r21_build_data()
d.T=24; d.baseMVA=10; d.baseKV=12.66;
d.load=[490 480 470 490 500 580 700 880 1000 1180 1300 1450 1400 1250 1300 1350 1500 1650 1800 1620 1200 1000 700 630];
d.pv=[0 0 0 0 0 0 50 250 350 400 430 450 450 450 400 350 200 50 0 0 0 0 0 0];
d.wind=[320 380 390 400 350 200 220 250 230 150 120 100 110 150 300 400 500 650 680 700 600 500 480 450];
d.tariff=[.38 .38 .38 .38 .38 .38 .40 .75 .78 1.20 1.18 1.15 .80 .68 .68 .65 .70 1.00 1.22 1.15 .78 .70 .38 .38];
d.gridPrice=[.40 .40 .40 .40 .40 .40 .45 .80 .80 1.25 1.25 1.25 .90 .80 .80 .80 .80 1.25 1.25 1.25 .80 .80 .40 .40];
d.reoBuyPrice=[.35 .35 .35 .35 .35 .35 .37 .42 .45 .55 .58 .60 .53 .50 .50 .48 .50 .58 .62 .60 .45 .42 .35 .35];
d.gccReward=.08; d.mu=.05; d.gecPrice=50; d.quota=.25;
% Scale domains used by the local validation. The manuscript explicitly
% studies absolute mu in [0,0.1] with baseline 0.05, hence MuScale in [0,2].
% The current manuscript text does not state numerical common-scale bounds
% for the 24 h TOU profile or GCC reward; those two domains are therefore
% reported as validation-code domains rather than manuscript-mandated limits.
d.leaderLB=[.90 .50 0]; d.leaderUB=[1.10 1.50 2.00];
d.leaderBoundSource={'Validation-code TOU scale domain (paper numeric bound not found)',...
    'Validation-code GCC scale domain (paper numeric bound not found)',...
    'Paper mu range 0 to 0.1 with baseline mu=0.05'};
d.voltageDeviationPenalty=120; % CNY per summed p.u. voltage deviation
d.acViolationPenalty=1e6;      % CNY per p.u. outside the statutory band
d.pvS=550; d.windS=880; d.pvBus=20; d.windBus=33;
d.svgBus=18; d.svgMax=500; d.cbBus=30; d.cbStep=100; d.cbN=5;
d.storageP=240; d.storageE=800; d.eta=.95;
d.vmin=.95; d.vmax=1.05; d.lineLimitMVA=5;
d.ops=sdpsettings('solver','cplex','verbose',0,'cachesolvers',1);
d.cpso.nParticles=5; d.cpso.maxIter=2; d.cpso.seed=20260629;
d.cpso.wMax=.9; d.cpso.wMin=.4; d.cpso.c1=1.8; d.cpso.c2=1.8;
d.mpc0=loadcase('case33bw');
end
