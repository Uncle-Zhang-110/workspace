function [bestX,bestDetail,trace]=r21_optimize_leader(d)
% Reproducible CPSO leader search over [TOU scale, GCC scale, mu scale].
% Every fitness evaluation resolves all followers and the network model.
rng(d.cpso.seed,'twister');
lb=d.leaderLB; ub=d.leaderUB; dim=3;
n=d.cpso.nParticles; maxIter=d.cpso.maxIter;
X=lb+rand(n,dim).*(ub-lb);
% Include the economically relevant corner and the manuscript reference;
% the remaining particles preserve global exploration.
X(1,:)=[ub(1) lb(2) lb(3)]; X(2,:)=[1 1 1];
V=zeros(n,dim); pbest=X; pbestF=-inf(n,1);
gbest=X(1,:); gbestF=-inf; bestDetail=[];
trace=zeros(maxIter,1);
for iter=1:maxIter
    for i=1:n
        try
            detail=r21_solve_case(d,X(i,1),X(i,2),X(i,3));
            f=detail.EMO_profit;
            if ~detail.feasible, f=-inf; end
        catch ME
            warning('r21:CPSOInfeasible','CPSO particle rejected: %s',ME.message);
            f=-inf; detail=[];
        end
        if f>pbestF(i), pbestF(i)=f; pbest(i,:)=X(i,:); end
        if f>gbestF, gbestF=f; gbest=X(i,:); bestDetail=detail; end
    end
    trace(iter)=gbestF;
    fprintf('  CPSO iteration %d/%d: best EMO profit %.6f CNY\n',iter,maxIter,gbestF);
    w=d.cpso.wMax-(d.cpso.wMax-d.cpso.wMin)*(iter-1)/max(maxIter-1,1);
    V=w*V+d.cpso.c1*rand(n,dim).*(pbest-X)...
        +d.cpso.c2*rand(n,dim).*(repmat(gbest,n,1)-X);
    X=min(max(X+V,repmat(lb,n,1)),repmat(ub,n,1));
end
assert(isfinite(gbestF) && ~isempty(bestDetail),...
    'No feasible leader strategy was found by CPSO.');
bestX=gbest;
end
