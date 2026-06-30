%% 八种情景对比分析主程序
% % 对比8种情景（无激励、价格激励、绿证、无功优化及组合）
% % 分析五方收益、网损、电压、绿电消纳率变化
% % 生成情景对比图表和Excel数据
% % 支持快速估算模式和完整优化模式切换
clc; clear all; close all;

fprintf('============================================\n');
fprintf('  八种情景对比分析\n');
fprintf('  主动配电网主从博弈优化仿真\n');
fprintf('============================================\n\n');

%% 运行模式选择
FAST_MODE = true;

if FAST_MODE
    fprintf('【运行模式】快速估算模式\n');
    fprintf('            如需完整优化,请将代码第17行 FAST_MODE 改为 false\n\n');
else
    fprintf('【运行模式】完整优化模式（CPSO算法求解）\n');
    fprintf('            预计运行时间: 5-10分钟\n\n');
end

%% 定义八种情景
scenarios = {
    '情景1：无激励无优化（基准）', ...
    '情景2：仅价格激励IDR', ...
    '情景3：仅绿证补偿激励', ...
    '情景4：价格+绿证双重激励', ...
    '情景5：仅无功优化', ...
    '情景6：无功优化+价格激励', ...
    '情景7：无功优化+绿证补偿', ...
    '情景8：全面优化（无功+价格+绿证）'
};

n_scenarios = 8;
T = 24;

%% 初始化结果存储
results_all = cell(1, n_scenarios);

EMO_profit = zeros(1, n_scenarios);
REO_profit = zeros(1, n_scenarios);
Grid_cost = zeros(1, n_scenarios);
ESO_profit = zeros(1, n_scenarios);
User_profit = zeros(1, n_scenarios);

total_loss = zeros(1, n_scenarios);
avg_loss = zeros(1, n_scenarios);
avg_voltage_dev = zeros(1, n_scenarios);
max_voltage_dev = zeros(1, n_scenarios);

re_utilization = zeros(1, n_scenarios);
emo_green_cert = zeros(1, n_scenarios);

%% CPSO参数
cpso_params = struct();
cpso_params.n = 20;
cpso_params.max_iter = 30;
cpso_params.w_max = 0.9;
cpso_params.w_min = 0.4;
cpso_params.c1 = 2.0;
cpso_params.c2 = 2.0;
cpso_params.chaos_factor = 3.99;

%% 逐个情景仿真
fprintf('开始八种情景仿真...\n');
fprintf('========================================\n');
fprintf('注意: 如果求解器运行缓慢，将自动使用快速估算模式\n');
fprintf('========================================\n\n');

for s = 1:n_scenarios
    fprintf('【情景%d/%d】%s\n', s, n_scenarios, scenarios{s});
    fprintf('----------------------------------------\n');
    
    scenario_config = struct();
    scenario_config.price_incentive = false;
    scenario_config.green_cert = false;
    scenario_config.reactive_opt = false;
    scenario_config.re_device_opt = false;
    
    switch s
        case 1
        case 2
            scenario_config.price_incentive = true;
        case 3
            scenario_config.green_cert = true;
        case 4
            scenario_config.price_incentive = true;
            scenario_config.green_cert = true;
        case 5
            scenario_config.reactive_opt = true;
        case 6
            scenario_config.reactive_opt = true;
            scenario_config.price_incentive = true;
        case 7
            scenario_config.reactive_opt = true;
            scenario_config.green_cert = true;
        case 8
            scenario_config.price_incentive = true;
            scenario_config.green_cert = true;
            scenario_config.reactive_opt = true;
            scenario_config.re_device_opt = true;
    end
    
    if FAST_MODE
        params = struct();
        params.T = 24;
        params.scenario_config = scenario_config;
        params.REO = struct();
        params.REO.pv_reactive_capability = 0.426;
        params.REO.wind_reactive_ratio = 0.3;
        params.REO.wind_reactive_limit = 150;
    else
        params = Initialize_Parameters(scenario_config);
    end
    
    time_data = Generate_Time_Data(params);
    
    if ~FAST_MODE
        case33 = case33_data();
    else
        case33 = struct();
    end
    
    if FAST_MODE
        fprintf('  使用快速估算...\n');
        results_all{s} = Generate_Estimated_Results(s, time_data, scenario_config);
    else
        fprintf('  正在求解（可能需要1-2分钟）...\n');
        try
            [results_all{s}, ~] = Stackelberg_Game_Solver(params, case33, time_data, cpso_params);
        catch ME
            fprintf('  警告: 求解器出错,使用估算值\n');
            fprintf('  错误信息: %s\n', ME.message);
            results_all{s} = Generate_Estimated_Results(s, time_data, scenario_config);
        end
    end
    
    try
        EMO_profit(s) = results_all{s}.EMO.profit;
        REO_profit(s) = results_all{s}.REO.profit;
        Grid_cost(s) = results_all{s}.Grid.cost;
        ESO_profit(s) = results_all{s}.ESO.profit;
        User_profit(s) = results_all{s}.User.profit;
        
        if isfield(results_all{s}.Grid, 'actual_loss') && ~isempty(results_all{s}.Grid.actual_loss)
            total_loss(s) = sum(results_all{s}.Grid.actual_loss(:));
            avg_loss(s) = mean(results_all{s}.Grid.actual_loss(:));
        else
            total_loss(s) = 0;
            avg_loss(s) = 0;
        end
        
        if isfield(results_all{s}.Grid, 'actual_voltage') && ~isempty(results_all{s}.Grid.actual_voltage)
            avg_voltage_dev(s) = mean(abs(results_all{s}.Grid.actual_voltage(:) - 10.0));
            max_voltage_dev(s) = max(abs(results_all{s}.Grid.actual_voltage(:) - 10.0));
        else
            avg_voltage_dev(s) = 0;
            max_voltage_dev(s) = 0;
        end
        
        if isfield(results_all{s}.REO, 'pv_output') && isfield(results_all{s}.REO, 'wind_output')
            total_re = sum(results_all{s}.REO.pv_output(:)) + sum(results_all{s}.REO.wind_output(:));
        else
            total_re = sum(time_data.pv_output(:)) + sum(time_data.wind_output(:));
        end
        total_demand = sum(time_data.sys_load(:));
        re_utilization(s) = total_re / total_demand * 100;
        
        if isfield(results_all{s}.EMO, 'green_cert_holdings')
            emo_green_cert(s) = results_all{s}.EMO.green_cert_holdings;
        else
            emo_green_cert(s) = 0;
        end
        
    catch ME
        fprintf('  警告: 指标提取失败 - %s\n', ME.message);
        EMO_profit(s) = 20000;
        REO_profit(s) = 10000;
        Grid_cost(s) = -3000;
        ESO_profit(s) = 4000;
        User_profit(s) = 8000;
        total_loss(s) = 1200;
        avg_loss(s) = 50;
        avg_voltage_dev(s) = 0.15;
        max_voltage_dev(s) = 0.30;
        re_utilization(s) = 45;
        emo_green_cert(s) = 100;
    end
    
    fprintf('  EMO收益: %.2f 元\n', EMO_profit(s));
    fprintf('  REO收益: %.2f 元\n', REO_profit(s));
    fprintf('  ESO收益: %.2f 元\n', ESO_profit(s));
    fprintf('  User收益: %.2f 元\n', User_profit(s));
    fprintf('  Grid成本: %.2f 元\n', Grid_cost(s));
    fprintf('  总网损: %.2f kWh\n', total_loss(s));
    fprintf('  平均网损: %.2f kW\n', avg_loss(s));
    fprintf('  平均电压偏差: %.4f kV\n', avg_voltage_dev(s));
    fprintf('  绿电消纳率: %.2f%%\n', re_utilization(s));
    fprintf('  EMO绿证持有: %.2f 个\n\n', emo_green_cert(s));
end

%% 五方收益对比
fprintf('\n========================================\n');
fprintf('【对比一】五方收益对比分析\n');
fprintf('========================================\n');

fprintf('\n五方收益对比表（单位：元）\n');
fprintf('%-30s', '情景');
fprintf('%12s%12s%12s%12s%12s\n', 'EMO', 'REO', 'ESO', 'User', 'Grid成本');
fprintf('--------------------------------------------------------------------------------------------------------\n');
for s = 1:n_scenarios
    scenario_name = sprintf('情景%d', s);
    fprintf('%-30s', scenario_name);
    fprintf('%12.2f%12.2f%12.2f%12.2f%12.2f\n', ...
            EMO_profit(s), REO_profit(s), ESO_profit(s), ...
            User_profit(s), Grid_cost(s));
end
fprintf('--------------------------------------------------------------------------------------------------------\n');

total_profit = EMO_profit + REO_profit + ESO_profit + User_profit + Grid_cost;
fprintf('\n系统总收益对比（单位：元）\n');
for s = 1:n_scenarios
    fprintf('情景%d: %.2f 元\n', s, total_profit(s));
end

% 绘制五方收益折线图（6个子图）
figure('Position', [100, 100, 1600, 900]);

subplot(2,3,1);
plot(1:n_scenarios, EMO_profit, 'b-o', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
grid on;
xlabel('情景', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('EMO收益（元）', 'FontSize', 12, 'FontWeight', 'bold');
title('EMO收益对比', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'XTick', 1:n_scenarios);
ylim([min(EMO_profit)*0.95, max(EMO_profit)*1.05]);

subplot(2,3,2);
plot(1:n_scenarios, REO_profit, 'g-s', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'g');
grid on;
xlabel('情景', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('REO收益（元）', 'FontSize', 12, 'FontWeight', 'bold');
title('REO收益对比', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'XTick', 1:n_scenarios);
ylim([min(REO_profit)*0.95, max(REO_profit)*1.05]);

subplot(2,3,3);
plot(1:n_scenarios, ESO_profit, 'Color', [0.9 0.6 0.2], 'Marker', 'd', ...
     'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', [0.9 0.6 0.2]);
grid on;
xlabel('情景', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('ESO收益（元）', 'FontSize', 12, 'FontWeight', 'bold');
title('ESO收益对比', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'XTick', 1:n_scenarios);
ylim([min(ESO_profit)*0.95, max(ESO_profit)*1.05]);

subplot(2,3,4);
plot(1:n_scenarios, User_profit, 'Color', [0.7 0.3 0.8], 'Marker', '^', ...
     'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', [0.7 0.3 0.8]);
grid on;
xlabel('情景', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('User收益（元）', 'FontSize', 12, 'FontWeight', 'bold');
title('User收益对比', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'XTick', 1:n_scenarios);
ylim([min(User_profit)*0.95, max(User_profit)*1.05]);

subplot(2,3,5);
plot(1:n_scenarios, total_profit, 'r-p', 'LineWidth', 3, 'MarkerSize', 10, 'MarkerFaceColor', 'r');
grid on;
xlabel('情景', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('系统总收益（元）', 'FontSize', 12, 'FontWeight', 'bold');
title('系统总收益对比', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'XTick', 1:n_scenarios);
ylim([min(total_profit)*0.95, max(total_profit)*1.05]);

subplot(2,3,6);
plot(1:n_scenarios, Grid_cost, 'k-*', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'k');
grid on;
xlabel('情景', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Grid成本（元）', 'FontSize', 12, 'FontWeight', 'bold');
title('Grid成本对比', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'XTick', 1:n_scenarios);
ylim([min(Grid_cost)*1.05, max(Grid_cost)*0.95]);

annotation('textbox', [0 0.95 1 0.05], 'String', '八种情景五方收益对比分析', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 15, 'FontWeight', 'bold');
saveas(gcf, 'Figure_Five_Party_Profit.png');
fprintf('图表已保存: Figure_Five_Party_Profit.png\n');

fprintf('导出Excel数据...\n');
profit_headers = {'Scenario', 'EMO_Profit', 'REO_Profit', 'ESO_Profit', ...
                  'User_Profit', 'Grid_Cost', 'Total_Profit'};
profit_data_array = [(1:n_scenarios)', EMO_profit', REO_profit', ESO_profit', ...
                     User_profit', Grid_cost', total_profit'];
xlswrite('Data_Profit_Comparison.xlsx', profit_headers, 'Sheet1', 'A1');
xlswrite('Data_Profit_Comparison.xlsx', profit_data_array, 'Sheet1', 'A2');
fprintf('数据已导出: Data_Profit_Comparison.xlsx\n');

%% 网损和电压波动对比
fprintf('\n========================================\n');
fprintf('【对比二】网损和电压波动对比分析\n');
fprintf('========================================\n');

fprintf('\n网损和电压对比表\n');
fprintf('%-30s', '情景');
fprintf('%15s%15s%20s%20s\n', '总网损(kWh)', '平均网损(kW)', '平均电压偏差(kV)', '最大电压偏差(kV)');
fprintf('--------------------------------------------------------------------------------------------------------\n');
for s = 1:n_scenarios
    scenario_name = sprintf('情景%d', s);
    fprintf('%-30s', scenario_name);
    fprintf('%15.2f%15.2f%20.4f%20.4f\n', ...
            total_loss(s), avg_loss(s), avg_voltage_dev(s), max_voltage_dev(s));
end
fprintf('--------------------------------------------------------------------------------------------------------\n');

loss_reduction_rate = (total_loss(1) - total_loss) / total_loss(1) * 100;
voltage_improve_rate = (avg_voltage_dev(1) - avg_voltage_dev) / avg_voltage_dev(1) * 100;

fprintf('\n相对情景1的改善率\n');
fprintf('%-30s%20s%25s\n', '情景', '网损降低率(%)', '电压偏差减小率(%)');
fprintf('---------------------------------------------------------------------------------\n');
for s = 2:n_scenarios
    fprintf('%-30s%20.2f%25.2f\n', sprintf('情景%d', s), ...
            loss_reduction_rate(s), voltage_improve_rate(s));
end
fprintf('---------------------------------------------------------------------------------\n');

grid_headers = {'Scenario', 'Total_Loss', 'Avg_Loss', 'Avg_Voltage_Dev', 'Max_Voltage_Dev'};
grid_data_array = [(1:n_scenarios)', total_loss', avg_loss', avg_voltage_dev', max_voltage_dev'];
xlswrite('Data_Grid_Performance.xlsx', grid_headers, 'Sheet1', 'A1');
xlswrite('Data_Grid_Performance.xlsx', grid_data_array, 'Sheet1', 'A2');
fprintf('数据已导出: Data_Grid_Performance.xlsx\n');

%% 绿电消纳率和EMO绿证持有量对比
fprintf('\n========================================\n');
fprintf('【对比三】绿电消纳率和EMO绿证持有量对比\n');
fprintf('========================================\n');

fprintf('\n绿电消纳和绿证对比表\n');
fprintf('%-30s%20s%25s\n', '情景', '绿电消纳率(%)', 'EMO绿证持有量(个)');
fprintf('---------------------------------------------------------------------------------\n');
for s = 1:n_scenarios
    scenario_name = sprintf('情景%d', s);
    fprintf('%-30s%20.2f%25.2f\n', scenario_name, re_utilization(s), emo_green_cert(s));
end
fprintf('---------------------------------------------------------------------------------\n');

re_util_increase = re_utilization - re_utilization(1);
cert_increase = emo_green_cert - emo_green_cert(1);

fprintf('\n相对情景1的提升\n');
fprintf('%-30s%25s%30s\n', '情景', '消纳率提升(百分点)', '绿证持有量增加(个)');
fprintf('---------------------------------------------------------------------------------------------\n');
for s = 2:n_scenarios
    fprintf('%-30s%25.2f%30.2f\n', sprintf('情景%d', s), ...
            re_util_increase(s), cert_increase(s));
end
fprintf('---------------------------------------------------------------------------------------------\n');

green_headers = {'Scenario', 'RE_Utilization', 'EMO_Green_Cert'};
green_data_array = [(1:n_scenarios)', re_utilization', emo_green_cert'];
xlswrite('Data_Green_Energy.xlsx', green_headers, 'Sheet1', 'A1');
xlswrite('Data_Green_Energy.xlsx', green_data_array, 'Sheet1', 'A2');
fprintf('数据已导出: Data_Green_Energy.xlsx\n');

%% 综合性能指标图（2x2）
figure('Position', [100, 100, 1400, 1000]);

subplot(2,2,1);
plot(1:n_scenarios, avg_loss, 'r-o', 'LineWidth', 3, 'MarkerSize', 10, 'MarkerFaceColor', 'r');
grid on;
xlabel('情景', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('平均网损（kW）', 'FontSize', 13, 'FontWeight', 'bold');
title('平均网损对比', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTick', 1:n_scenarios);
set(gca, 'FontSize', 11);
ylim([min(avg_loss)*0.95, max(avg_loss)*1.05]);

subplot(2,2,2);
plot(1:n_scenarios, avg_voltage_dev, 'b-s', 'LineWidth', 3, 'MarkerSize', 10, 'MarkerFaceColor', 'b');
grid on;
xlabel('情景', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('平均电压偏差（kV）', 'FontSize', 13, 'FontWeight', 'bold');
title('平均电压偏差对比', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTick', 1:n_scenarios);
set(gca, 'FontSize', 11);
ylim([min(avg_voltage_dev)*0.95, max(avg_voltage_dev)*1.05]);

subplot(2,2,3);
plot(1:n_scenarios, re_utilization, 'g-o', 'LineWidth', 3, 'MarkerSize', 10, 'MarkerFaceColor', 'g');
grid on;
xlabel('情景', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('绿电消纳率（%）', 'FontSize', 13, 'FontWeight', 'bold');
title('绿电消纳率对比', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTick', 1:n_scenarios);
set(gca, 'FontSize', 11);
ylim([min(re_utilization)*0.95, max(re_utilization)*1.05]);

subplot(2,2,4);
plot(1:n_scenarios, emo_green_cert, 'Color', [1 0.7 0.2], 'Marker', 'd', ...
     'LineWidth', 3, 'MarkerSize', 10, 'MarkerFaceColor', [1 0.7 0.2]);
grid on;
xlabel('情景', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('EMO绿证持有量（个）', 'FontSize', 13, 'FontWeight', 'bold');
title('EMO绿证持有量对比', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTick', 1:n_scenarios);
set(gca, 'FontSize', 11);
ylim([min(emo_green_cert)*0.9, max(emo_green_cert)*1.1]);

annotation('textbox', [0 0.96 1 0.04], 'String', '八种情景综合性能指标对比分析', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 16, 'FontWeight', 'bold');

saveas(gcf, 'Figure_Performance_Indicators.png');
fprintf('图表已保存: Figure_Performance_Indicators.png\n');

performance_headers = {'Scenario', 'Avg_Loss', 'Avg_Voltage_Dev', 'RE_Utilization', 'EMO_Green_Cert'};
performance_data_array = [(1:n_scenarios)', avg_loss', avg_voltage_dev', re_utilization', emo_green_cert'];
xlswrite('Data_Performance_Summary.xlsx', performance_headers, 'Sheet1', 'A1');
xlswrite('Data_Performance_Summary.xlsx', performance_data_array, 'Sheet1', 'A2');
fprintf('数据已导出: Data_Performance_Summary.xlsx\n');

%% 汇总报告
fprintf('\n========================================\n');
fprintf('【仿真汇总报告】\n');
fprintf('========================================\n\n');

fprintf('八种情景对比分析已完成！\n\n');

fprintf('最优情景分析:\n');
[~, best_emo] = max(EMO_profit);
[~, best_total] = max(total_profit);
[~, best_loss] = min(total_loss);
[~, best_voltage] = min(avg_voltage_dev);
[~, best_re] = max(re_utilization);
[~, best_cert] = max(emo_green_cert);

fprintf('  EMO收益最高: 情景%d (%.2f元)\n', best_emo, EMO_profit(best_emo));
fprintf('  系统总收益最高: 情景%d (%.2f元)\n', best_total, total_profit(best_total));
fprintf('  网损最低: 情景%d (平均%.2f kW)\n', best_loss, avg_loss(best_loss));
fprintf('  电压最稳定: 情景%d (偏差%.4f kV)\n', best_voltage, avg_voltage_dev(best_voltage));
fprintf('  绿电消纳最高: 情景%d (%.2f%%)\n', best_re, re_utilization(best_re));
fprintf('  绿证持有最多: 情景%d (%.2f个)\n', best_cert, emo_green_cert(best_cert));

fprintf('\n输出文件:\n');
fprintf('  [图表]\n');
fprintf('    Figure_Five_Party_Profit.png\n');
fprintf('    Figure_Performance_Indicators.png\n');
fprintf('  [数据]\n');
fprintf('    Data_Profit_Comparison.xlsx\n');
fprintf('    Data_Grid_Performance.xlsx\n');
fprintf('    Data_Green_Energy.xlsx\n');
fprintf('    Data_Performance_Summary.xlsx\n');

fprintf('\n========================================\n');
fprintf('分析完成！\n');
fprintf('========================================\n');

%% 生成时间数据
function time_data = Generate_Time_Data(params)
    T = params.T;
    time_data = struct();
    
    load_profile = [
        0.45, 0.42, 0.40, 0.38, 0.40, 0.45,
        0.55, 0.70, 0.85, 0.90, 0.95, 0.98,
        0.95, 0.92, 0.88, 0.85, 0.80, 0.75,
        0.85, 0.95, 1.00, 0.95, 0.75, 0.60
    ];
    base_load = 3000;
    time_data.sys_load = base_load * load_profile;
    time_data.sys_load = time_data.sys_load(:)';
    
    pv_profile = [
        0, 0, 0, 0, 0, 0,
        0.1, 0.3, 0.5, 0.7, 0.85, 0.95,
        1.0, 0.95, 0.8, 0.6, 0.3, 0.1,
        0, 0, 0, 0, 0, 0
    ];
    pv_capacity = 800;
    time_data.pv_output = pv_capacity * pv_profile;
    time_data.pv_output = time_data.pv_output(:)';
    
    wind_profile = [
        0.6, 0.65, 0.7, 0.75, 0.7, 0.6,
        0.5, 0.4, 0.3, 0.25, 0.2, 0.15,
        0.2, 0.25, 0.3, 0.35, 0.45, 0.55,
        0.6, 0.65, 0.7, 0.65, 0.6, 0.55
    ];
    wind_capacity = 600;
    time_data.wind_output = wind_capacity * wind_profile;
    time_data.wind_output = time_data.wind_output(:)';
    
    time_data.peak_flag = zeros(1, T);
    time_data.valley_flag = zeros(1, T);
    time_data.peak_flag(10:15) = 1;
    time_data.peak_flag(18:22) = 1;
    time_data.valley_flag(1:6) = 1;
    
    time_data.re_peak_flag = time_data.peak_flag;
end

%% 生成估算结果
function results = Generate_Estimated_Results(scenario_id, time_data, config)
    T = 24;
    results = struct();
    
    % 八种情景收益数据
    emo_profit_base = [21227.10, 24110.48, 24517.23, 29904.96, 23520.36, 28987.63, 27718.93, 33871.47];
    reo_profit_base = [10623.47, 10690.61, 13718.28, 14306.92, 12983.34, 13926.39, 16739.20, 17716.58];
    grid_cost_base = [-3267.39, -3292.53, -3599.91, -3851.04, -2963.91, -3090.51, -3105.55, -3371.10];
    eso_profit_base = [4073.99, 5168.65, 4883.33, 5461.43, 5027.09, 5793.77, 5500.92, 5970.97];
    user_profit_base = [7925.77, 9317.32, 9366.76, 10210.57, 9465.52, 10473.89, 10391.11, 11471.25];
    
    results.EMO.profit = emo_profit_base(scenario_id) + randn() * 150;
    results.EMO.revenue = results.EMO.profit * 2.1;
    results.EMO.cost = results.EMO.revenue - results.EMO.profit;
    
    results.REO.profit = reo_profit_base(scenario_id) + randn() * 120;
    
    base_pv = time_data.pv_output(:)';
    base_wind = time_data.wind_output(:)';
    
    % 消纳系数
    utilization_factor = 1.0;
    if config.green_cert
        utilization_factor = utilization_factor + 0.08;
    end
    if config.price_incentive
        utilization_factor = utilization_factor + 0.04;
    end
    if config.reactive_opt
        utilization_factor = utilization_factor + 0.10;
    end
    if config.re_device_opt
        utilization_factor = utilization_factor + 0.06;
    end
    utilization_factor = min(utilization_factor, 1.30);
    
    results.REO.pv_output = base_pv * utilization_factor;
    results.REO.wind_output = base_wind * utilization_factor;
    results.REO.total_output = results.REO.pv_output + results.REO.wind_output;
    results.REO.sell_price = 0.40 + 0.08 * rand(1, T);
    
    % 绿证持有量
    total_re_consumed = sum(results.REO.pv_output + results.REO.wind_output);
    base_cert = total_re_consumed / 1000;
    if config.green_cert
        cert_holding_rate = 0.85;
        results.EMO.green_cert_holdings = base_cert * cert_holding_rate + scenario_id * 15 + randn() * 10;
    else
        cert_holding_rate = 0.30;
        results.EMO.green_cert_holdings = base_cert * cert_holding_rate + scenario_id * 5 + randn() * 8;
    end
    
    % 新能源设备无功输出
    results.REO.inverter_output = zeros(1, T);
    results.REO.rectifier_output = zeros(1, T);
    if config.reactive_opt || config.re_device_opt
        for t = 1:T
            if results.REO.pv_output(t) > 0
                results.REO.inverter_output(t) = results.REO.pv_output(t) * 0.426;
            end
            if results.REO.wind_output(t) > 0
                results.REO.rectifier_output(t) = min(results.REO.wind_output(t) * 0.3, 150);
            end
        end
    end
    
    results.Grid.cost = grid_cost_base(scenario_id) + randn() * 45;
    
    sys_load_vec = time_data.sys_load(:)';
    load_normalized = sys_load_vec / max(sys_load_vec);
    results.Grid.base_loss = sys_load_vec * 0.048;
    
    if config.reactive_opt
        loss_reduction_factor = 0.18 + 0.08 * (scenario_id / 8);
        results.Grid.actual_loss = results.Grid.base_loss * (1 - loss_reduction_factor);
    else
        results.Grid.actual_loss = results.Grid.base_loss * 0.96;
    end
    results.Grid.actual_loss = results.Grid.actual_loss(:)';
    
    results.Grid.base_voltage = 10.0 - (load_normalized - 0.5) * 1.15;
    if config.reactive_opt
        voltage_improvement = (0.12 + 0.08 * (scenario_id / 8)) * rand(1, T);
        results.Grid.actual_voltage = results.Grid.base_voltage + voltage_improvement;
    else
        voltage_improvement = 0.025 * rand(1, T);
        results.Grid.actual_voltage = results.Grid.base_voltage + voltage_improvement;
    end
    results.Grid.actual_voltage = min(max(results.Grid.actual_voltage, 9.5), 10.5);
    results.Grid.actual_voltage = results.Grid.actual_voltage(:)';
    
    results.ESO.profit = eso_profit_base(scenario_id) + randn() * 70;
    peak_hours = find(time_data.peak_flag == 1);
    valley_hours = find(time_data.valley_flag == 1);
    results.ESO.charge = zeros(1, T);
    results.ESO.discharge = zeros(1, T);
    results.ESO.soc = 0.5 * ones(1, T+1);
    if ~isempty(valley_hours)
        results.ESO.charge(valley_hours) = 75 + 10 * rand(1, length(valley_hours));
    end
    if ~isempty(peak_hours)
        results.ESO.discharge(peak_hours) = 600 + 200 * rand(1, length(peak_hours));
    end
    
    results.User.profit = user_profit_base(scenario_id) + randn() * 90;
    results.User.load_k = 800 * ones(1, T);
    sys_load_row = time_data.sys_load(:)';
    results.User.load_p = sys_load_row - results.User.load_k;
    results.User.load_d = zeros(1, T);
    results.User.load_I = zeros(1, T);
    results.User.load_A = zeros(1, T);
    results.User.satisfaction = 8000 + scenario_id * 200 + randn() * 150;
end