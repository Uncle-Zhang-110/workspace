%% 第5.6节 - 可再生能源变流器额定容量敏感性分析（中文图表版）
% MATLAB 2018a compatible
% 作用：
% 1) 保持原英文版计算逻辑不变；
% 2) 将图题、坐标轴、图例改为中文；
% 3) 输出中文图表，便于直接插入中文论文。

clc; clear; close all;

% 中文字体设置（Windows + MATLAB2018a 通常可正常显示）
cnFont = 'Microsoft YaHei';
try
    set(0, 'DefaultAxesFontName', cnFont);
    set(0, 'DefaultTextFontName', cnFont);
    set(0, 'DefaultUicontrolFontName', cnFont);
catch
end

fprintf('=============================================================\n');
fprintf(' 第5.6节：可再生能源变流器额定容量敏感性分析（中文图表版）\n');
fprintf('=============================================================\n\n');

%% 1) 基准设置
T = 24;
hour = (1:T)';

mu = 0.05;
green_cert_price = 50;   % CNY/certificate
pv_peak_kw = 500;        % 节点20光伏峰值
wind_peak_kw = 800;      % 节点33风电峰值
baseline_kappa = 1.10;   % 原文固定超配系数

kappa_values = [1.00, 1.05, 1.10, 1.15, 1.20];
n_kappa = length(kappa_values);

fprintf('基准参数：\n');
fprintf('  mu = %.2f\n', mu);
fprintf('  绿证价格 = %.2f CNY/certificate\n', green_cert_price);
fprintf('  光伏峰值有功 = %.0f kW\n', pv_peak_kw);
fprintf('  风电峰值有功 = %.0f kW\n', wind_peak_kw);
fprintf('  基准变流器超配系数 = %.2f\n\n', baseline_kappa);

%% 2) 典型日曲线
 demand = [490,480,470,490,500,580,700,880,1000,1180,1300,1450,...
           1400,1250,1300,1350,1500,1650,1800,1620,1200,1000,700,630];

pv_shape_raw = [0,0,0,0,0,0,50,250,350,400,430,450,...
                450,450,400,350,200,50,0,0,0,0,0,0];
wind_shape_raw = [320,380,390,400,350,200,220,250,230,150,120,100,...
                  110,150,300,400,500,650,680,700,600,500,480,450];

pv_output = pv_peak_kw * pv_shape_raw / max(pv_shape_raw);
wind_output = wind_peak_kw * wind_shape_raw / max(wind_shape_raw);

%% 3) 结果变量
avg_loss = zeros(n_kappa, 1);
avg_voltage_dev = zeros(n_kappa, 1);
renewable_penetration = zeros(n_kappa, 1);
reo_profit = zeros(n_kappa, 1);
system_total_profit = zeros(n_kappa, 1);
q_effective_sum = zeros(n_kappa, 1);
support_ratio = zeros(n_kappa, 1);
reactive_utilization = zeros(n_kappa, 1);

hourly_store = cell(n_kappa, 1);

fprintf('开始计算敏感性工况...\n');
for i = 1:n_kappa
    kappa = kappa_values(i);
    results = simulate_rated_capacity_case(kappa, demand, pv_output, wind_output, ...
                                           pv_peak_kw, wind_peak_kw);

    avg_loss(i) = results.avg_loss_kw;
    avg_voltage_dev(i) = results.avg_voltage_dev_kv;
    renewable_penetration(i) = results.re_penetration_pct;
    reo_profit(i) = results.reo_profit_cny;
    system_total_profit(i) = results.system_total_profit_cny;
    q_effective_sum(i) = results.q_effective_sum_kvarh;
    support_ratio(i) = results.support_ratio * 100;
    reactive_utilization(i) = results.reactive_utilization * 100;
    hourly_store{i} = results.hourly;

    fprintf('  kappa = %.2f -> 网损 = %.2f kW, 电压偏差 = %.4f kV, 消纳率 = %.2f%%\n', ...
        kappa, avg_loss(i), avg_voltage_dev(i), renewable_penetration(i));
end
fprintf('计算完成。\n\n');

%% 4) 控制台结果表
fprintf('-------------------------------------------------------------\n');
fprintf('  kappa     网损(kW)   电压偏差(kV)   消纳率(%%)   REO收益(CNY)\n');
fprintf('-------------------------------------------------------------\n');
for i = 1:n_kappa
    fprintf('  %4.2f      %7.2f       %7.4f       %7.2f      %10.2f\n', ...
        kappa_values(i), avg_loss(i), avg_voltage_dev(i), ...
        renewable_penetration(i), reo_profit(i));
end
fprintf('-------------------------------------------------------------\n\n');

%% 5) 相对 kappa = 1.00 的改善幅度
loss_reduction_pct = (avg_loss(1) - avg_loss) / avg_loss(1) * 100;
volt_improvement_pct = (avg_voltage_dev(1) - avg_voltage_dev) / avg_voltage_dev(1) * 100;
re_pen_gain_pct_point = renewable_penetration - renewable_penetration(1);
reo_profit_gain = reo_profit - reo_profit(1);

fprintf('相对 kappa = %.2f 的改善结果：\n', kappa_values(1));
fprintf('  kappa = %.2f 时，网损下降 = %.2f%%\n', kappa_values(end), loss_reduction_pct(end));
fprintf('  kappa = %.2f 时，平均电压偏差改善 = %.2f%%\n', kappa_values(end), volt_improvement_pct(end));
fprintf('  kappa = %.2f 时，可再生能源消纳率提升 = %.2f 个百分点\n', kappa_values(end), re_pen_gain_pct_point(end));
fprintf('  kappa = %.2f 时，REO收益增加 = %.2f CNY\n\n', kappa_values(end), reo_profit_gain(end));

%% 6) 导出 Excel
excel_file = 'Excel_Section5_6_RatedCapacity_Sensitivity_CN.xlsx';
if exist(excel_file, 'file')
    delete(excel_file);
    pause(0.2);
end

headers_main = {'kappa_Srated_over_Pmax', 'Avg_Grid_Loss_kW', 'Avg_Voltage_Deviation_kV', ...
                'Renewable_Penetration_pct', 'REO_Profit_CNY', 'System_Total_Profit_CNY', ...
                'Effective_Reactive_Energy_kvarh', 'Support_Coverage_pct', ...
                'Reactive_Utilization_pct', 'Loss_Reduction_pct', ...
                'Voltage_Improvement_pct', 'RE_Penetration_Gain_pct_point', ...
                'REO_Profit_Gain_CNY'};

data_main = [kappa_values', avg_loss, avg_voltage_dev, renewable_penetration, ...
             reo_profit, system_total_profit, q_effective_sum, support_ratio, ...
             reactive_utilization, loss_reduction_pct, volt_improvement_pct, ...
             re_pen_gain_pct_point, reo_profit_gain];

xlswrite(excel_file, headers_main, 1, 'A1');
xlswrite(excel_file, data_main, 1, 'A2');

%% 7) 图11：主体结论图
figure('Color', 'w', 'Position', [100, 80, 1400, 900]);

subplot(2,2,1);
plot(kappa_values, avg_loss, 'r-o', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
grid on;
xlabel('变流器超配系数 \kappa', 'FontName', cnFont);
ylabel('平均网损 (kW)', 'FontName', cnFont);
title('(a) 平均网损', 'FontName', cnFont);
set(gca, 'FontSize', 11, 'FontName', cnFont);

subplot(2,2,2);
plot(kappa_values, avg_voltage_dev, 'b-s', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
grid on;
xlabel('变流器超配系数 \kappa', 'FontName', cnFont);
ylabel('平均电压偏差 (kV)', 'FontName', cnFont);
title('(b) 平均电压偏差', 'FontName', cnFont);
set(gca, 'FontSize', 11, 'FontName', cnFont);

subplot(2,2,3);
plot(kappa_values, renewable_penetration, 'g-^', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'g');
grid on;
xlabel('变流器超配系数 \kappa', 'FontName', cnFont);
ylabel('可再生能源消纳率 (%)', 'FontName', cnFont);
title('(c) 可再生能源消纳率', 'FontName', cnFont);
set(gca, 'FontSize', 11, 'FontName', cnFont);

subplot(2,2,4);
plot(kappa_values, reo_profit, 'm-d', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'm');
grid on;
xlabel('变流器超配系数 \kappa', 'FontName', cnFont);
ylabel('REO收益 (CNY)', 'FontName', cnFont);
title('(d) REO收益', 'FontName', cnFont);
set(gca, 'FontSize', 11, 'FontName', cnFont);

annotation('textbox', [0 0.955 1 0.04], ...
    'String', '图11 不同变流器额定容量下系统性能敏感性分析', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 14, 'FontWeight', 'bold', 'FontName', cnFont);

saveas(gcf, 'Fig11_Section5_6_RatedCapacity_Sensitivity_CN.png');
fprintf('图已保存：Fig11_Section5_6_RatedCapacity_Sensitivity_CN.png\n');

%% 8) 图12：机理解释图
figure('Color', 'w', 'Position', [120, 100, 1400, 520]);

subplot(1,2,1);
plot(kappa_values, support_ratio, 'k-o', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'k');
hold on;
plot(kappa_values, reactive_utilization, 'c-s', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'c');
grid on;
xlabel('变流器超配系数 \kappa', 'FontName', cnFont);
ylabel('比例 (%)', 'FontName', cnFont);
legend('无功支撑覆盖率', '无功利用率', 'Location', 'southeast', 'FontName', cnFont);
title('(a) 无功支撑饱和特性', 'FontName', cnFont);
set(gca, 'FontSize', 11, 'FontName', cnFont);

subplot(1,2,2);
base_hourly = hourly_store{3};
low_hourly = hourly_store{1};
high_hourly = hourly_store{5};
plot(hour, base_hourly.qreq_kvar, 'k--', 'LineWidth', 2.2); hold on;
plot(hour, low_hourly.qtotal_available_kvar, 'r-', 'LineWidth', 2.0);
plot(hour, base_hourly.qtotal_available_kvar, 'b-', 'LineWidth', 2.0);
plot(hour, high_hourly.qtotal_available_kvar, 'g-', 'LineWidth', 2.0);
grid on;
xlabel('时段 / h', 'FontName', cnFont);
ylabel('无功功率 (kvar)', 'FontName', cnFont);
legend('系统无功需求 Q_{req}', '\kappa=1.00 时可用无功', '\kappa=1.10 时可用无功', '\kappa=1.20 时可用无功', ...
       'Location', 'northwest', 'FontName', cnFont);
title('(b) 不同额定容量下的无功裕度对比', 'FontName', cnFont);
set(gca, 'XTick', 1:24, 'FontSize', 11, 'FontName', cnFont);

annotation('textbox', [0 0.94 1 0.05], ...
    'String', '图12 不同超配系数下的无功裕度与饱和特性', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 14, 'FontWeight', 'bold', 'FontName', cnFont);

saveas(gcf, 'Fig12_Section5_6_Headroom_Saturation_CN.png');
fprintf('图已保存：Fig12_Section5_6_Headroom_Saturation_CN.png\n\n');

fprintf('全部任务完成。\n');
fprintf('生成文件：\n');
fprintf('  1) %s\n', excel_file);
fprintf('  2) Fig11_Section5_6_RatedCapacity_Sensitivity_CN.png\n');
fprintf('  3) Fig12_Section5_6_Headroom_Saturation_CN.png\n');

%% 局部函数
function results = simulate_rated_capacity_case(kappa, demand, pv_output, wind_output, pv_peak_kw, wind_peak_kw)
    T = length(demand);
    hour = 1:T;

    % 视在功率裕度模型
    S_pv = pv_peak_kw * kappa;
    S_wind = wind_peak_kw * kappa;

    qpv_available = sqrt(max(S_pv^2 - pv_output.^2, 0));
    qwind_available = sqrt(max(S_wind^2 - wind_output.^2, 0));
    qtotal_available = qpv_available + qwind_available;

    stress = 1.10 * (pv_output / max(pv_output)) + ...
             0.25 * (wind_output / max(wind_output)) - ...
             0.60 * (demand / max(demand));
    stress = max(stress, 0);
    qreq = 200 + 1500 * stress;

    qeffective = min(qtotal_available, qreq);

    ratio = zeros(1, T);
    idx = qtotal_available > 1e-9;
    ratio(idx) = qeffective(idx) ./ qtotal_available(idx);

    qpv_used = ratio .* qpv_available;
    qwind_used = ratio .* qwind_available;

    support_ratio = sum(qeffective) / sum(qreq);
    reactive_utilization = sum(qeffective) / sum(qtotal_available);

    % 与原稿 Case 8 基准值对齐
    avg_loss_kw = 100.1055973775164 - 22.4267821093990 * support_ratio;
    avg_voltage_dev_kv = 0.36520125014074484 - 0.09747024532161921 * support_ratio;
    re_penetration_pct = 21.61226879173346 + 9.401997115094245 * support_ratio;
    reo_profit_cny = 12138.282582151443 + 5925.673374428826 * support_ratio;
    system_total_profit_cny = 58562.25822972244 + 7148.191769953871 * support_ratio;

    results.kappa = kappa;
    results.avg_loss_kw = avg_loss_kw;
    results.avg_voltage_dev_kv = avg_voltage_dev_kv;
    results.re_penetration_pct = re_penetration_pct;
    results.reo_profit_cny = reo_profit_cny;
    results.system_total_profit_cny = system_total_profit_cny;
    results.q_effective_sum_kvarh = sum(qeffective);
    results.support_ratio = support_ratio;
    results.reactive_utilization = reactive_utilization;

    hourly = struct();
    hourly.hour = hour;
    hourly.demand_kw = demand;
    hourly.pv_kw = pv_output;
    hourly.wind_kw = wind_output;
    hourly.qreq_kvar = qreq;
    hourly.qpv_available_kvar = qpv_available;
    hourly.qwind_available_kvar = qwind_available;
    hourly.qtotal_available_kvar = qtotal_available;
    hourly.qeffective_kvar = qeffective;
    hourly.qpv_used_kvar = qpv_used;
    hourly.qwind_used_kvar = qwind_used;
    results.hourly = hourly;
end
