function params = Initialize_Parameters(scenario_config)
% % 配置五方主体参数（EMO/REO/Grid/ESO/User）
% % 设置无功优化设备参数（电容器、变压器、SVG、光伏逆变器、风机整流器）
% % 配置CPSO算法参数
% % 支持八种情景配置开关
% % ESO固定电价设置（峰时0.585元/kWh，谷时0.385元/kWh）

%% 情景配置
if nargin < 1
    scenario_config = struct();
    scenario_config.price_incentive = true;
    scenario_config.green_cert = true;
    scenario_config.reactive_opt = true;
    scenario_config.re_device_opt = true;
end

params.scenario_config = scenario_config;

%% 基本参数
params.T = 24;

%% EMO参数
params.EMO.om_coeff = 0.05;

%% REO参数（可再生能源运营商）
params.REO.green_base_price = 0.43;
params.REO.pv_om = 0.02;
params.REO.wind_om = 0.015;

% 光伏逆变器参数
params.REO.pv_power_factor = 0.92;
params.REO.pv_reactive_capability = 0.426;

% 风机整流器参数
params.REO.wind_reactive_ratio = 0.3;
params.REO.wind_reactive_limit = 150;

%% Grid参数（电网运营商）
params.Grid.rated_voltage = 10.0;
params.Grid.line_R = 0.5;

% 并联电容器组参数
params.Grid.cap_step = 200;
params.Grid.cap_max_groups = 5;
params.Grid.cap_om_cost = 0.01;
params.Grid.cap_loss_coeff = 0.0013;
params.Grid.cap_voltage_coeff = 0.000197;

% 变压器分接头参数
params.Grid.tap_positions = [1, 2, 3, 4, 5];
params.Grid.tap_ratios = [0.95, 0.975, 1.0, 1.025, 1.05];
params.Grid.tap_base = 3;
params.Grid.tap_loss_coeff = 0.65;
params.Grid.tap_voltage_coeff = 0.0003165;
params.Grid.tap_deviation_cost = 5;

% SVG参数
params.Grid.svg_capacity = 500;
params.Grid.svg_om_cost = 0.02;
params.Grid.svg_loss_coeff = 0.004;
params.Grid.svg_voltage_coeff = 0.000471;

% 光伏逆变器无功优化系数
params.Grid.pv_inv_loss_coeff = 0.0011;
params.Grid.pv_inv_voltage_fluct_coeff = 0.000197;
params.Grid.pv_inv_max_adjust_rate = 0.2;

% 风机整流器无功优化系数
params.Grid.wind_rec_loss_coeff = 0.0014;
params.Grid.wind_rec_voltage_fluct_coeff = 0.000681;
params.Grid.wind_rec_max_adjust_rate = 0.3;

% 网损和电压惩罚参数
params.Grid.loss_price = 0.6;
params.Grid.loss_band = 5;
params.Grid.loss_penalty = 2.0;
params.Grid.loss_reward = 1.5;
params.Grid.voltage_price = 100;
params.Grid.voltage_base = 0.05;

%% ESO参数（储能运营商）
% 固定电价
params.ESO.peak_sell_price = 0.585;
params.ESO.valley_buy_price = 0.385;

% 储能功率约束（场景相关）
params.ESO.rated_capacity = 2000;
params.ESO.rated_power_scenario1 = 2000;
params.ESO.rated_power_scenario2 = 2200;
params.ESO.rated_power_scenario3 = 2400;

params.ESO.charge_eff = 0.95;
params.ESO.discharge_eff = 0.95;
params.ESO.soc_min = 0.2;
params.ESO.soc_max = 0.9;
params.ESO.soc_init = 0.5;
params.ESO.chem_loss = 0.01;
params.ESO.mech_loss = 0.005;

%% User参数（用户）
% 用户满意度参数（5种负载类型）
params.User.load_types = {'k', 'p', 'd', 'I', 'A'};

% 满意度偏好系数
params.User.v_k = 1.8;
params.User.v_p = 1.5;
params.User.v_d = 1.2;
params.User.v_I = 0.9;
params.User.v_A = 0.6;

% 满意度惩罚系数
params.User.u_k = 0.002;
params.User.u_p = 0.0015;
params.User.u_d = 0.0012;
params.User.u_I = 0.0008;
params.User.u_A = 0.0005;

% 绿证补偿机制
params.User.green_cert_direct_rate = 0.05;
params.User.green_cert_indirect_rate = 0.03;
params.User.green_cert_excess_price = 0.08;

%% CPSO算法参数
params.CPSO.n = 30;
params.CPSO.max_iter = 50;
params.CPSO.w_max = 0.9;
params.CPSO.w_min = 0.4;
params.CPSO.c1 = 2.0;
params.CPSO.c2 = 2.0;
params.CPSO.chaos_factor = 3.99;

%% EMO向REO的无功优化奖励参数
params.EMO.reo_reward_lambda = 0.35;
params.EMO.reo_reward_c_base = 0.6;
params.EMO.reo_reward_c_volt = 80;

fprintf('参数初始化完成\n');
fprintf('ESO固定电价: 峰时0.585元/kWh, 谷时0.385元/kWh\n');
fprintf('用户满意度: 5种负载类型参数已设置\n');
fprintf('绿证补偿机制已配置\n');
fprintf('储能功率约束: 场景1-2000kW, 场景2-2200kW, 场景3-2400kW\n');
fprintf('电网无功设备系数已更新\n');

% 输出情景配置信息
fprintf('\n【情景配置】\n');
fprintf('  价格激励IDR: %s\n', iif(scenario_config.price_incentive, '启用', '禁用'));
fprintf('  绿证补偿机制: %s\n', iif(scenario_config.green_cert, '启用', '禁用'));
fprintf('  传统无功优化: %s\n', iif(scenario_config.reactive_opt, '启用', '禁用'));
fprintf('  新能源设备无功: %s\n', iif(scenario_config.re_device_opt, '启用', '禁用'));

end

function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        
        result = false_val;
    end
end