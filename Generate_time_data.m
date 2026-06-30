function time_data = Generate_Time_Data(params)
% % 生成24小时负荷曲线（峰谷平）
% % 光伏和风电出力曲线
% % 用户5种负荷类型数据（关键/可移峰/可削减/可中断/可替代）
% % 峰谷时段标识
% % EMO售电/购电电价数据
% % 新能源设备无功能力数据

T = params.T;
time_data = struct();

%% 时段标识
time_data.hour = 1:T;

% 峰谷标识
time_data.peak_flag = zeros(1, T);
time_data.valley_flag = zeros(1, T);

time_data.peak_flag(10:15) = 1;
time_data.peak_flag(18:22) = 1;
time_data.valley_flag(1:6) = 1;

%% 系统负荷（kW）
load_profile = [
    0.45, 0.42, 0.40, 0.38, 0.40, 0.45,
    0.55, 0.70, 0.85, 0.90, 0.95, 0.98,
    0.95, 0.92, 0.88, 0.85, 0.80, 0.75,
    0.85, 0.95, 1.00, 0.95, 0.75, 0.60
];

base_load = 3000;
time_data.sys_load = base_load * load_profile;
time_data.sys_load = time_data.sys_load(:)';

%% 用户负荷分类（5种类型）
% k: 关键负荷, p: 可移峰负荷, d: 可削减负荷, I: 可中断负荷, A: 可替代负荷

time_data.load_k = zeros(1, T);
time_data.load_p = zeros(1, T);
time_data.load_d = zeros(1, T);
time_data.load_I = zeros(1, T);
time_data.load_A = zeros(1, T);

for t = 1:T
    if time_data.valley_flag(t) == 1
        time_data.load_k(t) = 800;
        time_data.load_p(t) = 1200;
        time_data.load_d(t) = 600;
        time_data.load_I(t) = 400;
        time_data.load_A(t) = 600;
    elseif time_data.peak_flag(t) == 1
        time_data.load_k(t) = 800;
        time_data.load_p(t) = 100;
        time_data.load_d(t) = 200;
        time_data.load_I(t) = 0;
        time_data.load_A(t) = 0;
    else
        time_data.load_k(t) = 800;
        time_data.load_p(t) = 600;
        time_data.load_d(t) = 400;
        time_data.load_I(t) = 200;
        time_data.load_A(t) = 100;
    end
end

%% 光伏出力（kW）
pv_profile = [
    0, 0, 0, 0, 0, 0,
    0.1, 0.3, 0.5, 0.7, 0.85, 0.95,
    1.0, 0.95, 0.8, 0.6, 0.3, 0.1,
    0, 0, 0, 0, 0, 0
];

pv_capacity = 800;
time_data.pv_output = pv_capacity * pv_profile;
time_data.pv_output = time_data.pv_output(:)';

%% 风电出力（kW）
wind_profile = [
    0.6, 0.65, 0.7, 0.75, 0.7, 0.6,
    0.5, 0.4, 0.3, 0.25, 0.2, 0.15,
    0.2, 0.25, 0.3, 0.35, 0.45, 0.55,
    0.6, 0.65, 0.7, 0.65, 0.6, 0.55
];

wind_capacity = 600;
time_data.wind_output = wind_capacity * wind_profile;
time_data.wind_output = time_data.wind_output(:)';

%% 无功负荷（kvar）
power_factor = 0.85;
time_data.base_reactive = time_data.sys_load * tan(acos(power_factor));

%% 电压基准（kV）
time_data.actual_voltage = 10.0 * ones(1, T);

%% 新能源设备无功能力数据
% 光伏逆变器无功能力
time_data.pv_reactive_available = time_data.pv_output * params.REO.pv_reactive_capability;

% 风机整流器无功能力
time_data.wind_reactive_available = min(time_data.wind_output * params.REO.wind_reactive_ratio, ...
                                        params.REO.wind_reactive_limit);

%% 场景编号（用于储能功率约束）
time_data.scenario = 1;

%% 24小时各类型电价数据
% EMO售电电价（用户购电价格，元/kWh）
time_data.emo_sell_price = [
    0.38, 0.38, 0.38, 0.38, 0.38, 0.38, ...
    0.40, 0.75, 0.78, 1.20, 1.18, 1.15, ...
    0.80, 0.68, 0.68, 0.65, 0.70, 1.00, ...
    1.22, 1.15, 0.78, 0.70, 0.38, 0.38
];

% EMO购电电价（向REO/ESO购电价格，元/kWh）
time_data.emo_buy_price = [
    0.35, 0.35, 0.35, 0.35, 0.35, 0.35, ...
    0.37, 0.42, 0.45, 0.55, 0.58, 0.60, ...
    0.53, 0.50, 0.50, 0.48, 0.50, 0.58, ...
    0.62, 0.60, 0.45, 0.42, 0.35, 0.35
];

% 外部电网购电价（EMO从外网购电，元/kWh）
time_data.grid_buy_price = [
    0.4000, 0.4000, 0.4000, 0.4000, 0.4000, 0.4000, ...
    0.4500, 0.8000, 0.8000, 1.2500, 1.2500, 1.2500, ...
    0.9000, 0.8000, 0.8000, 0.8000, 0.8000, 1.2500, ...
    1.2500, 1.2500, 0.8000, 0.8000, 0.4000, 0.4000
];

% 外部电网售电价（向外网反向售电，元/kWh）
time_data.grid_sell_price = 0.3500 * ones(1, 24);

% 强制确保所有电价都是行向量
time_data.emo_sell_price = time_data.emo_sell_price(:)';
time_data.emo_buy_price = time_data.emo_buy_price(:)';
time_data.grid_buy_price = time_data.grid_buy_price(:)';
time_data.grid_sell_price = time_data.grid_sell_price(:)';

%% 输出信息
fprintf('时间数据生成完成\n');
fprintf('  负荷范围: %.1f ~ %.1f kW\n', min(time_data.sys_load), max(time_data.sys_load));
fprintf('  光伏出力范围: 0 ~ %.1f kW\n', max(time_data.pv_output));
fprintf('  风电出力范围: %.1f ~ %.1f kW\n', min(time_data.wind_output), max(time_data.wind_output));
fprintf('  峰时时段数: %d, 谷时时段数: %d\n', sum(time_data.peak_flag), sum(time_data.valley_flag));
fprintf('  电价范围: EMO售电 %.2f-%.2f元/kWh, EMO购电 %.2f-%.2f元/kWh\n', ...
        min(time_data.emo_sell_price), max(time_data.emo_sell_price), ...
        min(time_data.emo_buy_price), max(time_data.emo_buy_price));

end