% =========================================================================
% YALMIP 环境测试代码：微型机组组合与经济调度问题 (MILP)
% 测试目的：验证 YALMIP 是否正常工作，以及底层求解器（如 CPLEX）能否求解含 0-1 变量的问题
% =========================================================================
clear; clc;

% 1. 定义决策变量
% 两个发电机的有功出力 (连续变量)
P = sdpvar(2, 1); 
% 两个发电机启停状态 (0-1 整数变量，对应你论文里的可中断负荷状态或设备投切)
U = binvar(2, 1); 

% 2. 设置系统参数
Pd = 150;            % 系统的总负荷需求 (MW)
P_min = [10; 20];    % 机组的最小出力限制
P_max = [100; 120];  % 机组的最大出力限制
C = [20; 15];        % 机组的变动发电成本系数 (元/MWh)
C_start = [500; 300];% 机组的固定运行/启动成本 (元)

% 3. 构建约束条件 (Constraints)
Constraints = [];
% 约束 A：功率平衡约束 (总出力必须等于总负荷)
Constraints = [Constraints, sum(P) == Pd];
% 约束 B：机组出力上下限约束 (结合了 0-1 启停状态变量)
% 如果 U=0，则 P 必须为 0；如果 U=1，则 P 在最小和最大出力之间
Constraints = [Constraints, P_min .* U <= P <= P_max .* U];

% 4. 定义目标函数 (Objective: 总成本最小化)
Objective = C'*P + C_start'*U;

% 5. 配置求解器选项
% 这里明确指定调用 'cplex'。如果你的电脑装的是 Gurobi，可以改成 'gurobi'
% 如果你想让 YALMIP 自己找电脑里可用的求解器，可以写成 sdpsettings('verbose', 1)
ops = sdpsettings('solver', 'cplex', 'verbose', 1);

% 6. 求解优化问题
sol = optimize(Constraints, Objective, ops);

% 7. 输出与诊断结果
disp('---------------------------------------------------');
if sol.problem == 0
    disp('? 测试完美通过！YALMIP 和求解器配置非常健康！');
    disp(['系统最优总成本: ', num2str(value(Objective)), ' 元']);
    disp(['机组启停状态 (U): ', num2str(value(U)')]);
    disp(['机组实际出力 (P): ', num2str(value(P)')]);
else
    disp('? 求解失败，请排查环境配置。YALMIP 报错信息如下：');
    disp(sol.info);
    % 常见错误提示：
    % 如果提示 "Solver not found"，说明 YALMIP 没找到 CPLEX，需要检查 CPLEX 的 MATLAB 接口是否已添加到设置路径(Set Path)中。
end
disp('---------------------------------------------------');