function [results, convergence_data] = Stackelberg_Game_Solver(params, case33, time_data, cpso_params)
% % 使用CPSO（混沌粒子群优化）算法求解Stackelberg博弈
% % 上层：EMO（能源管理运营商）领导者决策
% % 下层：REO、Grid、ESO、User 四方跟随者响应
% % 光伏逆变器和风机整流器无功优化
% % 计算五方收益和电网性能指标（网损、电压）
% % 输出收敛数据

T = params.T;
convergence_data = struct();
convergence_data.iterations = [];
convergence_data.gbest_cost = [];

%% 初始化粒子群
fprintf('初始化粒子群...\n');
n_particles = cpso_params.n;
max_iter = cpso_params.max_iter;

% 决策变量维度定义
dim = T * 10;

% 变量边界
lb = zeros(1, dim);
ub = ones(1, dim) * 10;

% 初始化粒子
particles = struct();
for i = 1:n_particles
    particles(i).position = lb + rand(1, dim) .* (ub - lb);
    particles(i).velocity = randn(1, dim) * 0.1;
    particles(i).pbest_pos = particles(i).position;
    particles(i).pbest_cost = inf;
    particles(i).cost = inf;
end

gbest_pos = particles(1).position;
gbest_cost = inf;

%% CPSO主循环
fprintf('开始CPSO迭代优化...\n');
for iter = 1:max_iter
    % 动态惯性权重
    w = cpso_params.w_max - (cpso_params.w_max - cpso_params.w_min) * iter / max_iter;
    
    % 评估每个粒子
    for i = 1:n_particles
        % 解码决策变量
        emo_vars = decode_emo_variables(particles(i).position, T);
        
        % 求解下层跟随者问题
        followers_results = Solve_Followers(emo_vars, params, case33, time_data);
        
        % 计算EMO目标函数
        emo_obj = Calculate_EMO_Objective(emo_vars, followers_results, params, time_data);
        
        particles(i).cost = -emo_obj;
        
        % 更新个体最优
        if particles(i).cost < particles(i).pbest_cost
            particles(i).pbest_cost = particles(i).cost;
            particles(i).pbest_pos = particles(i).position;
        end
        
        % 更新全局最优
        if particles(i).cost < gbest_cost
            gbest_cost = particles(i).cost;
            gbest_pos = particles(i).position;
        end
    end
    
    % 记录收敛数据
    convergence_data.iterations(iter) = iter;
    convergence_data.gbest_cost(iter) = -gbest_cost;
    
    % 更新粒子位置和速度
    for i = 1:n_particles
        r1 = rand(1, dim);
        r2 = rand(1, dim);
        
        particles(i).velocity = w * particles(i).velocity + ...
            cpso_params.c1 * r1 .* (particles(i).pbest_pos - particles(i).position) + ...
            cpso_params.c2 * r2 .* (gbest_pos - particles(i).position);
        
        particles(i).position = particles(i).position + particles(i).velocity;
        
        % 边界处理
        particles(i).position = max(particles(i).position, lb);
        particles(i).position = min(particles(i).position, ub);
    end
    
    % 混沌局部搜索
    if mod(iter, 10) == 0
        gbest_pos = chaos_local_search(gbest_pos, lb, ub, cpso_params.chaos_factor);
    end
    
    % 输出进度
    if mod(iter, 10) == 0
        fprintf('迭代 %d/%d: 最优目标值 = %.2f 元\n', iter, max_iter, -gbest_cost);
    end
end

%% 最终解码和结果计算
fprintf('\n计算最终结果...\n');
emo_vars = decode_emo_variables(gbest_pos, T);
followers_results = Solve_Followers(emo_vars, params, case33, time_data);

% 汇总结果
results = struct();
results.EMO = Calculate_EMO_Results(emo_vars, followers_results, params, time_data);
results.REO = followers_results.REO;
results.Grid = followers_results.Grid;
results.ESO = followers_results.ESO;
results.User = followers_results.User;

fprintf('主从博弈优化完成！\n');
fprintf('ESO电价已更新为固定值，用户满意度公式已更新\n');
fprintf('包含光伏逆变器和风机整流器的无功优化贡献\n');
fprintf('已更新网损和电压计算系数\n');
end

%% 子函数: 解码EMO决策变量
function emo_vars = decode_emo_variables(x, T)
    emo_vars = struct();
    idx = 1;
    
    % 售电价格 (T个时段)
    emo_vars.sell_price = x(idx:idx+T-1) * 2;
    idx = idx + T;
    
    % 购电价格 (T个时段)
    emo_vars.buy_price = x(idx:idx+T-1) * 1.5;
    idx = idx + T;
    
    % 储能售电价格
    emo_vars.ess_sell_price = x(idx:idx+T-1) * 0.8 + 0.3;
    idx = idx + T;
    
    % 储能购电价格
    emo_vars.ess_buy_price = x(idx:idx+T-1) * 0.6 + 0.2;
    idx = idx + T;
    
    % 其他决策变量...
    emo_vars.grid_buy_limit = x(idx:idx+T-1) * 3000;
end

%% 子函数: 求解下层跟随者问题
function results = Solve_Followers(emo_vars, params, case33, time_data)
    T = params.T;
    results = struct();
    
    % 1. 求解REO问题
    results.REO = Solve_REO(emo_vars, params, time_data);
    
    % 2. 求解Grid问题
    results.Grid = Solve_Grid_Improved(emo_vars, params, case33, time_data, results.REO);
    
    % 3. 求解ESO问题
    results.ESO = Solve_ESO(emo_vars, params, time_data);
    
    % 4. 求解User问题
    results.User = Solve_User(emo_vars, params, time_data, results.Grid);
end

%% 子函数: 求解REO问题
function reo_result = Solve_REO(emo_vars, params, time_data)
    T = params.T;
    reo_result = struct();
    
    % REO目标: 最大化售电收入 - 维护成本
    total_revenue = 0;
    total_om_cost = 0;
    
    reo_result.pv_output = zeros(1, T);
    reo_result.wind_output = zeros(1, T);
    reo_result.total_output = zeros(1, T);
    reo_result.sell_price = zeros(1, T);
    
    % 光伏逆变器和风机整流器无功输出
    reo_result.inverter_output = zeros(1, T);
    reo_result.rectifier_output = zeros(1, T);
    
    for t = 1:T
        % 光伏和风电出力
        reo_result.pv_output(t) = time_data.pv(t);
        reo_result.wind_output(t) = time_data.wind(t);
        reo_result.total_output(t) = reo_result.pv_output(t) + reo_result.wind_output(t);
        
        % 售电价格
        base_price = params.REO.green_base_price;
        bargain = time_data.bargain_coeff(t);
        reo_result.sell_price(t) = base_price * (1 + bargain);
        
        % 收入
        total_revenue = total_revenue + reo_result.sell_price(t) * reo_result.total_output(t);
        
        % 维护成本
        pv_om = params.REO.pv_om * reo_result.pv_output(t);
        wind_om = params.REO.wind_om * reo_result.wind_output(t);
        total_om_cost = total_om_cost + pv_om + wind_om;
        
        % 光伏逆变器无功输出（容性，基于功率因数0.92）
        if reo_result.pv_output(t) > 0
            reo_result.inverter_output(t) = reo_result.pv_output(t) * 0.426;
        end
        
        % 风机整流器无功输出（容性补偿，约30%，上限150kvar）
        if reo_result.wind_output(t) > 0
            reo_result.rectifier_output(t) = min(reo_result.wind_output(t) * 0.3, 150);
        end
    end
    
    % 光伏逆变器和风机整流器的运维成本
    c_inv_om = 0.015;
    c_rect_om = 0.02;
    Q_inv_base = 0.1;
    
    inv_om_cost = 0;
    rect_om_cost = 0;
    for t = 1:T
        % 逆变器运维成本
        Q_inv_deviation = abs(reo_result.inverter_output(t) - Q_inv_base * reo_result.pv_output(t));
        inv_om_cost = inv_om_cost + c_inv_om * Q_inv_deviation;
        
        % 整流器运维成本
        rect_om_cost = rect_om_cost + c_rect_om * reo_result.rectifier_output(t);
    end
    
    total_om_cost = total_om_cost + inv_om_cost + rect_om_cost;
    
    % 计算光伏逆变器和风机整流器的网损降低贡献
    alpha_inv = 0.0011;
    alpha_rect = 0.0014;
    reo_result.loss_reduction_inv = alpha_inv * abs(reo_result.inverter_output);
    reo_result.loss_reduction_rect = alpha_rect * reo_result.rectifier_output;
    
    % 计算光伏逆变器和风机整流器的电压调节贡献
    k_inv_fluct = 0.000197;
    k_rec_fluct = 0.000681;
    
    reo_result.voltage_adjust_inv = zeros(1, T);
    reo_result.voltage_adjust_rect = zeros(1, T);
    
    for t = 1:T
        % 光伏逆变器电压调节
        if t == 1
            Q_inv_change = abs(reo_result.inverter_output(t));
        else
            Q_inv_change = abs(reo_result.inverter_output(t) - reo_result.inverter_output(t-1));
        end
        Delta_Q_inv_max = 0.2 * reo_result.pv_output(t);
        reo_result.voltage_adjust_inv(t) = k_inv_fluct * min(Q_inv_change, Delta_Q_inv_max);
        
        % 风机整流器电压调节
        if t == 1
            Q_rec_change = reo_result.rectifier_output(t);
        else
            Q_rec_change = abs(reo_result.rectifier_output(t) - reo_result.rectifier_output(t-1));
        end
        Delta_Q_rec_max = 0.3 * reo_result.wind_output(t);
        reo_result.voltage_adjust_rect(t) = k_rec_fluct * min(Q_rec_change, Delta_Q_rec_max);
    end
    
    reo_result.revenue = total_revenue;
    reo_result.om_cost = total_om_cost;
    reo_result.profit = total_revenue - total_om_cost;
end

%% 子函数: 求解Grid问题（改进版）
function grid_result = Solve_Grid_Improved(emo_vars, params, case33, time_data, reo_result)
    T = params.T;
    grid_result = struct();
    
    fprintf('  使用改进的启发式Grid优化（含提前预判+新能源设备+更新系数）...\n');
    
    % 为每个时段选择设备参数
    grid_result.cap_groups = zeros(1, T);
    grid_result.cap_capacity = zeros(1, T);
    grid_result.tap_position = 3 * ones(1, T);
    grid_result.tap_ratio = ones(1, T);
    grid_result.svg_output = zeros(1, T);
    
    % 1. 并联电容器组（根据负荷大小调整）
    for t = 1:T
        load_ratio = time_data.sys_load(t) / max(time_data.sys_load);
        
        if load_ratio > 0.8
            grid_result.cap_groups(t) = 5;
        elseif load_ratio > 0.6
            grid_result.cap_groups(t) = 3;
        elseif load_ratio > 0.4
            grid_result.cap_groups(t) = 2;
        else
            grid_result.cap_groups(t) = 1;
        end
        grid_result.cap_capacity(t) = grid_result.cap_groups(t) * params.Grid.cap_step;
    end
    
    % 2. 变压器分接头（改进：提前预判调节策略）
    grid_result.tap_position(1:6) = 2;
    
    grid_result.tap_position(8) = 4;
    grid_result.tap_position(9:12) = 4;
    
    grid_result.tap_position(13:17) = 3;
    
    grid_result.tap_position(18:22) = 4;
    
    grid_result.tap_position(23:24) = 2;
    
    % 变比对应
    tap_ratios_map = [0.95, 0.975, 1.0, 1.025, 1.05];
    grid_result.tap_ratio = tap_ratios_map(grid_result.tap_position);
    
    % 3. SVG（根据电压偏差调整）
    for t = 1:T
        voltage_dev = 10 - time_data.actual_voltage(t);
        if voltage_dev > 0.5
            grid_result.svg_output(t) = min(500, voltage_dev * 100);
        elseif voltage_dev < -0.5
            grid_result.svg_output(t) = max(-500, voltage_dev * 100);
        else
            grid_result.svg_output(t) = 0;
        end
    end
    
    % 计算性能
    [grid_result.actual_loss, grid_result.actual_voltage, ...
     grid_result.loss_reduction_cap, grid_result.loss_reduction_tap, ...
     grid_result.loss_reduction_svg, grid_result.voltage_adjust_cap, ...
     grid_result.voltage_adjust_tap, grid_result.voltage_adjust_svg, ...
     grid_result.base_voltage] = ...
        Calculate_Grid_Performance_Improved(grid_result, params, case33, time_data, reo_result);
    
    % 基准网损
    grid_result.base_loss = time_data.base_loss;
    
    % 计算成本
    grid_result.cost = Calculate_Grid_Cost(grid_result, params, time_data);
    
    fprintf('  改进策略应用成功：峰时提前预判，谷时降档优化\n');
    fprintf('  新能源设备无功优化已纳入计算（已更新系数）\n');
end

%% 子函数: 计算电网性能（改进版）
function [actual_loss, actual_voltage, loss_red_cap, loss_red_tap, ...
          loss_red_svg, volt_adj_cap, volt_adj_tap, volt_adj_svg, base_voltage] = ...
    Calculate_Grid_Performance_Improved(grid_result, params, case33, time_data, reo_result)
    
    T = params.T;
    actual_loss = zeros(1, T);
    actual_voltage = zeros(1, T);
    base_voltage = zeros(1, T);
    
    % 各设备贡献初始化
    loss_red_cap = zeros(1, T);
    loss_red_tap = zeros(1, T);
    loss_red_svg = zeros(1, T);
    volt_adj_cap = zeros(1, T);
    volt_adj_tap = zeros(1, T);
    volt_adj_svg = zeros(1, T);
    
    for t = 1:T
        % 功率因数改善
        Q_cap = grid_result.cap_capacity(t);
        Q_svg = grid_result.svg_output(t);
        Q_load = time_data.base_reactive(t);
        
        Q_total = Q_load - Q_cap - Q_svg;
        P_load = time_data.sys_load(t);
        
        % 补偿后功率因数
        pf_after = P_load / sqrt(P_load^2 + Q_total^2);
        
        % 线路电流
        S_after = sqrt(P_load^2 + Q_total^2);
        I_after = S_after / (sqrt(3) * params.Grid.rated_voltage);
        
        % 网损计算
        loss_line_base = 3 * I_after^2 * params.Grid.line_R;
        
        k_c = 0.0013;
        loss_red_cap(t) = k_c * Q_cap;
        
        k_T = 0.65;
        tap_dev = abs(grid_result.tap_position(t) - 3);
        if t >= 8 && t <= 12
            loss_red_tap(t) = k_T * tap_dev * 1.5;
        else
            loss_red_tap(t) = k_T * tap_dev;
        end
        
        k_SVG = 0.004;
        loss_red_svg(t) = k_SVG * abs(Q_svg);
        
        % 光伏逆变器和风机整流器降损贡献
        loss_red_inv = reo_result.loss_reduction_inv(t);
        loss_red_rect = reo_result.loss_reduction_rect(t);
        
        % 实际网损
        total_loss_red = loss_red_cap(t) + loss_red_tap(t) + loss_red_svg(t) + ...
                        loss_red_inv + loss_red_rect;
        max_allowed_red = loss_line_base * 0.10;
        actual_reduction = min(total_loss_red, max_allowed_red);
        
        actual_loss(t) = loss_line_base - actual_reduction;
        actual_loss(t) = max(actual_loss(t), P_load * 0.02);
        
        % 电压计算
        load_normalized = P_load / max(time_data.sys_load);
        base_voltage(t) = 10.0 - (load_normalized - 0.5) * 1.0;
        
        theta_c = 0.000197;
        volt_adj_cap(t) = theta_c * Q_cap;
        
        theta_T = 0.0003165;
        tap_dev_from_base = abs(grid_result.tap_position(t) - 3);
        volt_adj_tap(t) = theta_T * tap_dev_from_base * 1000;
        if t >= 8 && t <= 12
            volt_adj_tap(t) = volt_adj_tap(t) + 0.05;
        end
        
        theta_SVG = 0.000471;
        volt_adj_svg(t) = theta_SVG * abs(Q_svg);
        
        % 光伏逆变器和风机整流器调压贡献
        volt_adj_inv = reo_result.voltage_adjust_inv(t);
        volt_adj_rect = reo_result.voltage_adjust_rect(t);
        
        % 实际电压
        actual_voltage(t) = base_voltage(t) + volt_adj_cap(t) + volt_adj_tap(t) + ...
                            volt_adj_svg(t) + volt_adj_inv + volt_adj_rect;
        actual_voltage(t) = min(max(actual_voltage(t), 9.5), 10.5);
    end
end

%% 子函数: 计算电网成本
function cost = Calculate_Grid_Cost(grid_result, params, time_data)
    T = params.T;
    cost = 0;
    
    for t = 1:T
        % 网损惩罚/奖励
        loss_dev = grid_result.actual_loss(t) - time_data.base_loss(t);
        if loss_dev > params.Grid.loss_band
            loss_cost = params.Grid.loss_penalty * params.Grid.loss_price * ...
                (loss_dev - params.Grid.loss_band);
        elseif loss_dev < -params.Grid.loss_band
            loss_cost = -params.Grid.loss_reward * params.Grid.loss_price * ...
                abs(loss_dev + params.Grid.loss_band);
        else
            loss_cost = 0;
        end
        
        % 电压偏差惩罚
        U_ref = params.Grid.rated_voltage;
        V_dev_before = abs(grid_result.base_voltage(t) - U_ref);
        V_dev_after = abs(grid_result.actual_voltage(t) - U_ref);
        Delta_V_opt = V_dev_after - V_dev_before;
        
        if Delta_V_opt > 0
            voltage_cost = params.Grid.voltage_price * Delta_V_opt;
        elseif Delta_V_opt < -params.Grid.voltage_base
            voltage_cost = params.Grid.voltage_price * Delta_V_opt * 0.5;
        else
            voltage_cost = 0;
        end
        
        % 设备运维成本
        cap_cost = grid_result.cap_capacity(t) * params.Grid.cap_om_cost;
        svg_cost = abs(grid_result.svg_output(t)) * params.Grid.svg_om_cost;
        tap_cost = abs(grid_result.tap_position(t) - params.Grid.tap_base) * ...
            params.Grid.tap_deviation_cost;
        
        cost = cost + loss_cost + voltage_cost + cap_cost + svg_cost + tap_cost;
    end
end

%% 子函数: 求解ESO问题
function eso_result = Solve_ESO(emo_vars, params, time_data)
    T = params.T;
    eso_result = struct();
    
    % 储能运行计划
    eso_result.charge = time_data.ess_charge;
    eso_result.discharge = time_data.ess_discharge;
    eso_result.soc = zeros(1, T+1);
    eso_result.soc(1) = params.ESO.soc_init;
    
    % 固定电价
    peak_sell_price = 0.585;
    valley_buy_price = 0.385;
    
    total_revenue = 0;
    total_cost = 0;
    
    for t = 1:T
        % SOC更新
        charge_energy = eso_result.charge(t) * params.ESO.charge_eff;
        discharge_energy = eso_result.discharge(t) / params.ESO.discharge_eff;
        eso_result.soc(t+1) = eso_result.soc(t) + ...
            (charge_energy - discharge_energy) / params.ESO.rated_capacity;
        
        % 峰时放电收益
        if eso_result.discharge(t) > 0 && time_data.peak_flag(t) == 1
            total_revenue = total_revenue + peak_sell_price * eso_result.discharge(t) * ...
                params.ESO.discharge_eff;
        end
        
        % 谷时充电成本
        if eso_result.charge(t) > 0 && time_data.valley_flag(t) == 1
            total_cost = total_cost + valley_buy_price * eso_result.charge(t) / ...
                params.ESO.charge_eff;
        end
        
        % 运维成本
        om_cost = params.ESO.chem_loss * valley_buy_price * eso_result.charge(t) + ...
            params.ESO.mech_loss * (eso_result.charge(t) + eso_result.discharge(t));
        total_cost = total_cost + om_cost;
    end
    
    eso_result.revenue = total_revenue;
    eso_result.cost = total_cost;
    eso_result.profit = total_revenue - total_cost;
    
    fprintf('  ESO电价：峰时售电0.585元/kWh，谷时购电0.385元/kWh\n');
end

%% 子函数: 求解User问题
function user_result = Solve_User(emo_vars, params, time_data, grid_result)
    T = params.T;
    user_result = struct();
    
    % 负荷实际用电量
    L_k = zeros(1, T);
    L_p = zeros(1, T);
    L_d = zeros(1, T);
    L_I = zeros(1, T);
    L_A = zeros(1, T);
    
    for t = 1:T
        if t >= 1 && t <= 6
            L_k(t) = 800;
            L_p(t) = 1200;
            L_d(t) = 600;
            L_I(t) = 400;
            L_A(t) = 600;
        elseif (t >= 10 && t <= 15) || (t >= 18 && t <= 22)
            L_k(t) = 800;
            L_p(t) = 100;
            L_d(t) = 200;
            L_I(t) = 0;
            L_A(t) = 0;
        else
            L_k(t) = 800;
            L_p(t) = 600;
            L_d(t) = 400;
            L_I(t) = 200;
            L_A(t) = 100;
        end
    end
    
    % 保存负荷数据
    user_result.load_k = L_k;
    user_result.load_p = L_p;
    user_result.load_d = L_d;
    user_result.load_I = L_I;
    user_result.load_A = L_A;
    
    % 用能满意度计算
    v_k = 1.8;   u_k = 0.002;
    v_p = 1.5;   u_p = 0.0015;
    v_d = 1.2;   u_d = 0.0012;
    v_I = 0.9;   u_I = 0.0008;
    v_A = 0.6;   u_A = 0.0005;
    
    Delta_t = 1;
    
    total_satisfaction = 0;
    for t = 1:T
        U_k = v_k * L_k(t) - (u_k/2) * L_k(t)^2;
        U_p = v_p * L_p(t) - (u_p/2) * L_p(t)^2;
        U_d = v_d * L_d(t) - (u_d/2) * L_d(t)^2;
        U_I = v_I * L_I(t) - (u_I/2) * L_I(t)^2;
        U_A = v_A * L_A(t) - (u_A/2) * L_A(t)^2;
        
        total_satisfaction = total_satisfaction + Delta_t * (U_k + U_p + U_d + U_I + U_A);
    end
    
    user_result.satisfaction = total_satisfaction;
    
    % 购电成本
    total_purchase_cost = 0;
    for t = 1:T
        total_load = L_k(t) + L_p(t) + L_d(t) + L_I(t) + L_A(t);
        price = emo_vars.sell_price(t);
        total_purchase_cost = total_purchase_cost + price * total_load;
    end
    user_result.purchase_cost = total_purchase_cost;
    
    % 绿证补偿
    total_compensation = 0;
    for t = 1:T
        if time_data.re_peak_flag(t) == 1 && L_A(t) > 0
            compensation_t = L_A(t) * 0.05;
            total_compensation = total_compensation + compensation_t;
        end
    end
    user_result.green_compensation = total_compensation;
    
    % 电网激励
    user_result.grid_incentive = 50;
    
    % 总收益
    user_result.profit = total_satisfaction + total_compensation + ...
        user_result.grid_incentive - total_purchase_cost;
    
    fprintf('  用户满意度已更新：使用新公式计算（分5种负荷类型）\n');
end

%% 子函数: 计算EMO目标函数
function obj = Calculate_EMO_Objective(emo_vars, followers, params, time_data)
    T = params.T;
    
    % 售电收入
    revenue_user = sum(emo_vars.sell_price .* time_data.demand);
    
    valley_buy_price = 0.385;
    revenue_ess_valley = sum(valley_buy_price .* time_data.ess_charge .* time_data.valley_flag);
    
    % 购电成本
    cost_reo = sum(followers.REO.sell_price .* followers.REO.total_output);
    
    peak_sell_price = 0.585;
    cost_ess_peak = sum(peak_sell_price .* time_data.ess_discharge .* time_data.peak_flag);
    
    cost_grid_trans = followers.Grid.cost;
    
    % EMO向REO的无功优化奖励成本
    lambda_reward = 0.35;
    c_base = 0.6;
    c_volt = 80;
    reo_reward_cost = sum(lambda_reward * ...
        (c_base * (followers.REO.loss_reduction_inv + followers.REO.loss_reduction_rect) + ...
         c_volt * (followers.REO.voltage_adjust_inv + followers.REO.voltage_adjust_rect)));
    
    % 运维成本
    om_cost = params.EMO.om_coeff * (cost_reo + cost_ess_peak);
    
    % 目标函数
    obj = revenue_user + revenue_ess_valley - cost_reo - cost_ess_peak - ...
        cost_grid_trans - om_cost - reo_reward_cost;
end

%% 子函数: 混沌局部搜索
function x_new = chaos_local_search(x, lb, ub, chaos_factor)
    z = (x - lb) ./ (ub - lb);
    z_new = chaos_factor * z .* (1 - z);
    x_new = lb + z_new .* (ub - lb);
    x_new = max(x_new, lb);
    x_new = min(x_new, ub);
end

%% 子函数: 计算EMO完整结果
function emo_result = Calculate_EMO_Results(emo_vars, followers, params, time_data)
    T = params.T;
    
    % 售电收入
    revenue_user = sum(emo_vars.sell_price .* time_data.demand);
    
    valley_buy_price = 0.385;
    revenue_ess = sum(valley_buy_price .* time_data.ess_charge .* time_data.valley_flag);
    
    total_revenue = revenue_user + revenue_ess;
    
    % 购电成本
    cost_reo = sum(followers.REO.sell_price .* followers.REO.total_output);
    
    peak_sell_price = 0.585;
    cost_ess = sum(peak_sell_price .* time_data.ess_discharge .* time_data.peak_flag);
    
    cost_grid = followers.Grid.cost;
    total_cost = cost_reo + cost_ess + cost_grid;
    
    % EMO向REO的无功优化奖励
    lambda_reward = 0.35;
    c_base = 0.6;
    c_volt = 80;
    reo_reward = sum(lambda_reward * ...
        (c_base * (followers.REO.loss_reduction_inv + followers.REO.loss_reduction_rect) + ...
         c_volt * (followers.REO.voltage_adjust_inv + followers.REO.voltage_adjust_rect)));
    
    % 运维成本
    om_cost = params.EMO.om_coeff * total_cost;
    
    % 净收益
    emo_result.revenue = total_revenue;
    emo_result.cost = total_cost;
    emo_result.om_cost = om_cost;
    emo_result.reo_reward = reo_reward;
    emo_result.profit = total_revenue - total_cost - om_cost - reo_reward;
    
    % 详细数据
    emo_result.sell_price = emo_vars.sell_price;
    emo_result.buy_price = emo_vars.buy_price;
    
    fprintf('  EMO电价处理：储能峰时0.585元/kWh，谷时0.385元/kWh\n');
end