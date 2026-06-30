%% 绿证价格 & 无功-绿证转化系数 独立敏感性分析（物理饱和版）
clc; clear all; close all;

% 固定随机种子
rng(42);

fprintf('============================================\n');
fprintf('  绿证价格 & μ 独立敏感性分析\n');
fprintf('  【物理饱和版】自动生成Excel\n');
fprintf('============================================\n\n');

%% 参数设置
green_cert_prices = 0:10:100;    % 绿证价格范围（修改为从0开始）
mu_values = 0:0.01:0.1;          % 转化系数范围
fixed_mu = 0.05;                 % 固定μ值
fixed_price = 50;                % 固定绿证价格

fprintf('参数范围:\n');
fprintf('  绿证价格: %d ~ %d 元/张 (%d个点)\n', ...
        min(green_cert_prices), max(green_cert_prices), length(green_cert_prices));
fprintf('  转化系数μ: %.2f ~ %.2f (%d个点)\n\n', ...
        min(mu_values), max(mu_values), length(mu_values));

%% 基础数据
T = 24;
demand = [490,480,470,490,500,580,700,880,1000,1180,1300,1450,...
          1400,1250,1300,1350,1500,1650,1800,1620,1200,1000,700,630];
pv = [0,0,0,0,0,0,50,250,350,400,430,450,...
      450,450,400,350,200,50,0,0,0,0,0,0];
wind = [320,380,390,400,350,200,220,250,230,150,120,100,...
        110,150,300,400,500,650,680,700,600,500,480,450];
peak_hours = [9:12, 18:22];
valley_hours = [1:6, 23:24];

%% 绿证价格敏感性分析
fprintf('【1/4】绿证价格敏感性分析...\n');
loss_vs_price = zeros(1, length(green_cert_prices));
voltage_dev_vs_price = zeros(1, length(green_cert_prices));
reo_profit_vs_price = zeros(1, length(green_cert_prices));
system_profit_vs_price = zeros(1, length(green_cert_prices));

for i = 1:length(green_cert_prices)
    cert_price_kwh = green_cert_prices(i) / 1000;
    results = Generate_Results_With_Saturation(T, demand, pv, wind, peak_hours, valley_hours, ...
                                               fixed_mu, cert_price_kwh);
    loss_vs_price(i) = mean(results.Grid.actual_loss);
    voltage_dev_vs_price(i) = mean(abs(results.Grid.actual_voltage - 10.0));
    reo_profit_vs_price(i) = results.REO.profit;
    system_profit_vs_price(i) = results.EMO.profit + results.REO.profit + ...
                                 results.ESO.profit + results.User.profit + results.Grid.cost;
end
fprintf('  完成！\n\n');

%% μ敏感性分析
fprintf('【2/4】转化系数μ敏感性分析...\n');
loss_vs_mu = zeros(1, length(mu_values));
voltage_dev_vs_mu = zeros(1, length(mu_values));
reo_profit_vs_mu = zeros(1, length(mu_values));
system_profit_vs_mu = zeros(1, length(mu_values));
saturation_ratio_vs_mu = zeros(1, length(mu_values));

fixed_price_kwh = fixed_price / 1000;

for i = 1:length(mu_values)
    results = Generate_Results_With_Saturation(T, demand, pv, wind, peak_hours, valley_hours, ...
                                               mu_values(i), fixed_price_kwh);
    loss_vs_mu(i) = mean(results.Grid.actual_loss);
    voltage_dev_vs_mu(i) = mean(abs(results.Grid.actual_voltage - 10.0));
    reo_profit_vs_mu(i) = results.REO.profit;
    system_profit_vs_mu(i) = results.EMO.profit + results.REO.profit + ...
                              results.ESO.profit + results.User.profit + results.Grid.cost;
    saturation_ratio_vs_mu(i) = results.REO.saturation_ratio;
end
fprintf('  完成！\n\n');

%% 计算改善率
improvement_pct_loss = (loss_vs_price(1) - loss_vs_price(end)) / loss_vs_price(1) * 100;
improvement_pct_voltage = (voltage_dev_vs_price(1) - voltage_dev_vs_price(end)) / voltage_dev_vs_price(1) * 100;
improvement_pct_loss_mu = (loss_vs_mu(1) - loss_vs_mu(end)) / loss_vs_mu(1) * 100;
improvement_pct_voltage_mu = (voltage_dev_vs_mu(1) - voltage_dev_vs_mu(end)) / voltage_dev_vs_mu(1) * 100;

%% 导出Excel（使用xlswrite）
fprintf('【3/4】导出Excel数据...\n');

excel_file = 'Excel_敏感性分析数据.xlsx';

% 删除旧文件
if exist(excel_file, 'file')
    delete(excel_file);
    pause(0.5);  % 等待文件删除完成
end

% --- Sheet 1: 绿证价格影响 ---
headers1 = {'绿证价格(元/张)', '平均网损(kW)', '平均电压偏差(kV)', 'REO收益(元)', '系统总收益(元)'};
data1 = [green_cert_prices', loss_vs_price', voltage_dev_vs_price', ...
         reo_profit_vs_price', system_profit_vs_price'];

xlswrite(excel_file, headers1, 1, 'A1');
xlswrite(excel_file, data1, 1, 'A2');
xlswrite(excel_file, {sprintf('说明: 固定μ = %.2f', fixed_mu)}, 1, sprintf('A%d', size(data1,1)+3));

fprintf('  ? Sheet 1: 绿证价格影响数据\n');

% --- Sheet 2: μ影响 ---
headers2 = {'转化系数μ', '平均网损(kW)', '平均电压偏差(kV)', 'REO收益(元)', '系统总收益(元)', '饱和度(%)'};
data2 = [mu_values', loss_vs_mu', voltage_dev_vs_mu', ...
         reo_profit_vs_mu', system_profit_vs_mu', saturation_ratio_vs_mu'*100];

xlswrite(excel_file, headers2, 2, 'A1');
xlswrite(excel_file, data2, 2, 'A2');
xlswrite(excel_file, {sprintf('说明: 固定绿证价格 = %d 元/张', fixed_price)}, 2, sprintf('A%d', size(data2,1)+3));

fprintf('  ? Sheet 2: 转化系数μ影响数据\n');

% --- Sheet 3: 改善率汇总 ---
headers3 = {'指标', '绿证价格影响', 'μ影响'};
summary = {
    '网损起点(kW)', loss_vs_price(1), loss_vs_mu(1);
    '网损终点(kW)', loss_vs_price(end), loss_vs_mu(end);
    '网损降低(kW)', loss_vs_price(1)-loss_vs_price(end), loss_vs_mu(1)-loss_vs_mu(end);
    '网损改善率(%)', improvement_pct_loss, improvement_pct_loss_mu;
    '', '', '';
    '电压偏差起点(kV)', voltage_dev_vs_price(1), voltage_dev_vs_mu(1);
    '电压偏差终点(kV)', voltage_dev_vs_price(end), voltage_dev_vs_mu(end);
    '电压偏差改善(kV)', voltage_dev_vs_price(1)-voltage_dev_vs_price(end), voltage_dev_vs_mu(1)-voltage_dev_vs_mu(end);
    '电压偏差改善率(%)', improvement_pct_voltage, improvement_pct_voltage_mu;
    '', '', '';
    'REO收益起点(元)', reo_profit_vs_price(1), reo_profit_vs_mu(1);
    'REO收益终点(元)', reo_profit_vs_price(end), reo_profit_vs_mu(end);
    'REO收益增长(元)', reo_profit_vs_price(end)-reo_profit_vs_price(1), reo_profit_vs_mu(end)-reo_profit_vs_mu(1);
    '', '', '';
    '固定参数', sprintf('μ=%.2f', fixed_mu), sprintf('绿证=%d元/张', fixed_price);
    '平均饱和度(%)', '-', mean(saturation_ratio_vs_mu)*100;
};

xlswrite(excel_file, headers3, 3, 'A1');
xlswrite(excel_file, summary, 3, 'A2');

fprintf('  ? Sheet 3: 改善率汇总\n');

%% 计算3D曲面数据
fprintf('【4/5】计算3D曲面数据...\n');
loss_3d = zeros(length(mu_values), length(green_cert_prices));
voltage_dev_3d = zeros(length(mu_values), length(green_cert_prices));

for i = 1:length(mu_values)
    for j = 1:length(green_cert_prices)
        cert_price_kwh = green_cert_prices(j) / 1000;
        results = Generate_Results_With_Saturation(T, demand, pv, wind, peak_hours, valley_hours, ...
                                                   mu_values(i), cert_price_kwh);
        loss_3d(i, j) = mean(results.Grid.actual_loss);
        voltage_dev_3d(i, j) = mean(abs(results.Grid.actual_voltage - 10.0));
    end
    fprintf('  进度: %d/%d\n', i, length(mu_values));
end
fprintf('  完成！\n\n');

%% 导出3D数据到Excel
fprintf('【额外】导出3D曲面数据到Excel...\n');

% 生成网格坐标（用于XYZ数据）
[X_mesh, Y_mesh] = meshgrid(green_cert_prices, mu_values);

% --- Sheet 4: 3D网损数据（矩阵形式） ---
headers_3d_loss = [{'μ \ 绿证价格'}, num2cell(green_cert_prices)];
data_3d_loss = [mu_values', loss_3d];

xlswrite(excel_file, headers_3d_loss, 4, 'A1');
xlswrite(excel_file, data_3d_loss, 4, 'A2');
xlswrite(excel_file, {'说明: Z轴为平均网损(kW) - 矩阵形式'}, 4, sprintf('A%d', size(data_3d_loss,1)+3));

fprintf('  ? Sheet 4: 3D网损曲面数据（矩阵）\n');

% --- Sheet 5: 3D电压偏差数据（矩阵形式） ---
headers_3d_voltage = [{'μ \ 绿证价格'}, num2cell(green_cert_prices)];
data_3d_voltage = [mu_values', voltage_dev_3d];

xlswrite(excel_file, headers_3d_voltage, 5, 'A1');
xlswrite(excel_file, data_3d_voltage, 5, 'A2');
xlswrite(excel_file, {'说明: Z轴为平均电压偏差(kV) - 矩阵形式'}, 5, sprintf('A%d', size(data_3d_voltage,1)+3));

fprintf('  ? Sheet 5: 3D电压偏差曲面数据（矩阵）\n');

% --- Sheet 6: 3D网损XYZ坐标数据 ---
X_flat = X_mesh(:);
Y_flat = Y_mesh(:);
Z_loss_flat = loss_3d(:);

headers_xyz_loss = {'X轴-绿证价格(元/张)', 'Y轴-转化系数μ', 'Z轴-平均网损(kW)'};
data_xyz_loss = [X_flat, Y_flat, Z_loss_flat];

xlswrite(excel_file, headers_xyz_loss, 6, 'A1');
xlswrite(excel_file, data_xyz_loss, 6, 'A2');
xlswrite(excel_file, {sprintf('说明: 共%d个数据点 - 图1网损3D曲面的XYZ坐标', length(X_flat))}, 6, sprintf('A%d', size(data_xyz_loss,1)+3));

fprintf('  ? Sheet 6: 3D网损XYZ坐标数据 (%d个点)\n', length(X_flat));

% --- Sheet 7: 3D电压偏差XYZ坐标数据 ---
Z_voltage_flat = voltage_dev_3d(:);

headers_xyz_voltage = {'X轴-绿证价格(元/张)', 'Y轴-转化系数μ', 'Z轴-平均电压偏差(kV)'};
data_xyz_voltage = [X_flat, Y_flat, Z_voltage_flat];

xlswrite(excel_file, headers_xyz_voltage, 7, 'A1');
xlswrite(excel_file, data_xyz_voltage, 7, 'A2');
xlswrite(excel_file, {sprintf('说明: 共%d个数据点 - 图2电压偏差3D曲面的XYZ坐标', length(X_flat))}, 7, sprintf('A%d', size(data_xyz_voltage,1)+3));

fprintf('  ? Sheet 7: 3D电压偏差XYZ坐标数据 (%d个点)\n', length(X_flat));

fprintf('\n? Excel文件已保存: %s\n', excel_file);
fprintf('  - Sheet 1-3: 基础敏感性分析数据\n');
fprintf('  - Sheet 4-5: 3D曲面数据（矩阵形式，可用于热力图）\n');
fprintf('  - Sheet 6-7: 3D曲面XYZ坐标（%d个点，可直接绘制3D图）\n\n', length(X_flat));

%% 绘制图表
fprintf('【5/5】绘制分析图表...\n');

% 图1: 网损对比
figure('Position', [100, 100, 1600, 700]);
subplot(1,2,1);
plot(green_cert_prices, loss_vs_price, 'b-o', 'LineWidth', 3, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
grid on; xlabel('绿证价格 (元/张)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('平均网损 (kW)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('绿证价格对网损的影响 (固定μ=%.2f)', fixed_mu), 'FontSize', 13, 'FontWeight', 'bold');

subplot(1,2,2);
plot(mu_values, loss_vs_mu, 'g-d', 'LineWidth', 3, 'MarkerSize', 8, 'MarkerFaceColor', 'g');
grid on; xlabel('转化系数 μ', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('平均网损 (kW)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('转化系数μ对网损的影响 (固定价格=%d元/张)', fixed_price), 'FontSize', 13, 'FontWeight', 'bold');
saveas(gcf, 'Figure_网损敏感性分析.png');

% 图2: 电压偏差对比
figure('Position', [150, 150, 1600, 700]);
subplot(1,2,1);
plot(green_cert_prices, voltage_dev_vs_price, 'r-s', 'LineWidth', 3, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
grid on; xlabel('绿证价格 (元/张)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('平均电压偏差 (kV)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('绿证价格对电压偏差的影响 (固定μ=%.2f)', fixed_mu), 'FontSize', 13, 'FontWeight', 'bold');

subplot(1,2,2);
plot(mu_values, voltage_dev_vs_mu, 'Color', [1 0.5 0], 'Marker', '^', 'LineWidth', 3, 'MarkerSize', 8, 'MarkerFaceColor', [1 0.5 0]);
grid on; xlabel('转化系数 μ', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('平均电压偏差 (kV)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('转化系数μ对电压偏差的影响 (固定价格=%d元/张)', fixed_price), 'FontSize', 13, 'FontWeight', 'bold');
saveas(gcf, 'Figure_电压偏差敏感性分析.png');

% 图3: 3D曲面图 - 平均网损
figure('Position', [200, 200, 900, 700]);
[X, Y] = meshgrid(green_cert_prices, mu_values);
surf(X, Y, loss_3d, 'EdgeColor', 'none', 'FaceAlpha', 0.9);
colormap('jet');
colorbar;
xlabel('绿证价格 (元/张)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('转化系数 μ', 'FontSize', 12, 'FontWeight', 'bold');
zlabel('平均网损 (kW)', 'FontSize', 12, 'FontWeight', 'bold');
title('绿证价格与转化系数对平均网损的影响', 'FontSize', 14, 'FontWeight', 'bold');
view(45, 30);
grid on;
lighting gouraud;
shading interp;
saveas(gcf, 'Figure_3D_网损曲面图.png');

% 图4: 3D曲面图 - 平均电压偏差
figure('Position', [250, 250, 900, 700]);
surf(X, Y, voltage_dev_3d, 'EdgeColor', 'none', 'FaceAlpha', 0.9);
colormap('hot');
colorbar;
xlabel('绿证价格 (元/张)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('转化系数 μ', 'FontSize', 12, 'FontWeight', 'bold');
zlabel('平均电压偏差 (kV)', 'FontSize', 12, 'FontWeight', 'bold');
title('绿证价格与转化系数对平均电压偏差的影响', 'FontSize', 14, 'FontWeight', 'bold');
view(45, 30);
grid on;
lighting gouraud;
shading interp;
saveas(gcf, 'Figure_3D_电压偏差曲面图.png');

fprintf('  ? 所有图表已保存\n\n');

%% 生成分析报告
fprintf('========================================\n');
fprintf('【分析报告】\n');
fprintf('========================================\n\n');

fprintf('1. 绿证价格影响（固定μ=%.2f）:\n', fixed_mu);
fprintf('   网损: %.2f → %.2f kW (降低%.1f%%)\n', loss_vs_price(1), loss_vs_price(end), improvement_pct_loss);
fprintf('   电压偏差: %.4f → %.4f kV (改善%.1f%%)\n', voltage_dev_vs_price(1), voltage_dev_vs_price(end), improvement_pct_voltage);
fprintf('   REO收益: %.0f → %.0f 元 (增长%.0f元)\n\n', reo_profit_vs_price(1), reo_profit_vs_price(end), reo_profit_vs_price(end)-reo_profit_vs_price(1));

fprintf('2. 转化系数μ影响（固定价格=%d元/张）:\n', fixed_price);
fprintf('   网损: %.2f → %.2f kW (降低%.1f%%)\n', loss_vs_mu(1), loss_vs_mu(end), improvement_pct_loss_mu);
fprintf('   电压偏差: %.4f → %.4f kV (改善%.1f%%)\n', voltage_dev_vs_mu(1), voltage_dev_vs_mu(end), improvement_pct_voltage_mu);
fprintf('   REO收益: %.0f → %.0f 元 (增长%.0f元)\n', reo_profit_vs_mu(1), reo_profit_vs_mu(end), reo_profit_vs_mu(end)-reo_profit_vs_mu(1));
fprintf('   平均饱和度: %.1f%%\n\n', mean(saturation_ratio_vs_mu)*100);

fprintf('========================================\n');
fprintf('分析完成！所有结果已保存。\n');
fprintf('========================================\n');

%% 核心函数
function results = Generate_Results_With_Saturation(T, demand, pv, wind, peak_hours, valley_hours, mu, cert_price_kwh)
    results = struct();
    base_emo_profit = 25000;
    base_reo_profit = 12000;
    base_grid_cost = -3500;
    
    % 绿证价格影响
    base_cert_price = 0.05;
    price_factor = cert_price_kwh / base_cert_price;
    price_factor = min(max(price_factor, 0.4), 2.0);
    
    dr_intensity = 0.05 + 0.12 * (price_factor - 0.4) / 1.6;
    
    sys_load = demand;
    for t = peak_hours
        sys_load(t) = sys_load(t) * (1 - dr_intensity * 0.60);
    end
    for t = valley_hours
        sys_load(t) = sys_load(t) * (1 + dr_intensity * 0.40);
    end
    
    utilization_boost = 0.08 * (price_factor - 1.0);
    re_pv = pv * (1 + utilization_boost);
    re_wind = wind * (1 + utilization_boost);
    
    % EMO & REO
    price_premium = 8000 * (price_factor - 1.0);
    results.EMO.profit = base_emo_profit + price_premium;
    results.EMO.revenue = 50000;
    results.EMO.cost = 25000;
    results.EMO.sell_price = 0.8 + 0.3 * (1:T) / T;
    results.EMO.buy_price = 0.4 + 0.15 * (1:T) / T;
    
    results.REO.pv_output = re_pv;
    results.REO.wind_output = re_wind;
    results.REO.sell_price = 0.43 * ones(1, T);
    
    % μ影响 + 物理饱和约束
    load_normalized = sys_load / max(demand);
    base_voltage = 10.0 - (load_normalized - 0.5) * 1.0;
    
    results.REO.inverter_output = zeros(1, T);
    results.REO.rectifier_output = zeros(1, T);
    voltage_adjust_inv = zeros(1, T);
    voltage_adjust_rect = zeros(1, T);
    effective_reactive_inv = zeros(1, T);
    effective_reactive_rect = zeros(1, T);
    
    saturation_count = 0;
    
    for t = 1:T
        % 光伏逆变器
        if re_pv(t) > 0
            P_pv = re_pv(t);
            S_pv = P_pv * 1.15;
            Q_pv_max_ideal = sqrt(S_pv^2 - P_pv^2);
            Q_pv_max = min(P_pv * 0.20, Q_pv_max_ideal);
            
            V_dev = base_voltage(t) - 10.0;
            
            if V_dev > 0.05
                Q_target = -Q_pv_max * min(1, V_dev / 0.5);
                V_adjust_direction = -1;
            elseif V_dev < -0.05
                Q_target = Q_pv_max * min(1, abs(V_dev) / 0.5);
                V_adjust_direction = 1;
            else
                Q_target = -Q_pv_max * 0.1;
                V_adjust_direction = -V_dev / (abs(V_dev) + 0.001);
            end
            
            mu_factor = 0.2 + sqrt(mu * 0.8) * 0.8;
            Q_desired = Q_target * mu_factor;
            
            if abs(Q_desired) > Q_pv_max
                results.REO.inverter_output(t) = sign(Q_desired) * Q_pv_max;
                saturation_count = saturation_count + 1;
            else
                results.REO.inverter_output(t) = Q_desired;
            end
            
            k_inv = 0.00045;
            voltage_adjust_inv(t) = k_inv * abs(results.REO.inverter_output(t)) * V_adjust_direction;
            
            if (V_dev > 0 && Q_target < 0) || (V_dev < 0 && Q_target > 0)
                effective_reactive_inv(t) = abs(results.REO.inverter_output(t));
            end
        end
        
        % 风机整流器
        if re_wind(t) > 0
            P_wind = re_wind(t);
            S_wind = P_wind * 1.15;
            Q_wind_max_ideal = sqrt(S_wind^2 - P_wind^2);
            Q_wind_max = min(min(P_wind * 0.25, 150), Q_wind_max_ideal);
            
            V_dev = base_voltage(t) - 10.0;
            
            if V_dev > 0.05
                Q_target = -Q_wind_max * min(1, V_dev / 0.5);
                V_adjust_direction = -1;
            elseif V_dev < -0.05
                Q_target = Q_wind_max * min(1, abs(V_dev) / 0.5);
                V_adjust_direction = 1;
            else
                Q_target = -Q_wind_max * 0.1;
                V_adjust_direction = -V_dev / (abs(V_dev) + 0.001);
            end
            
            mu_factor = 0.2 + sqrt(mu * 0.8) * 0.8;
            Q_desired = Q_target * mu_factor;
            
            if abs(Q_desired) > Q_wind_max
                results.REO.rectifier_output(t) = sign(Q_desired) * Q_wind_max;
                saturation_count = saturation_count + 1;
            else
                results.REO.rectifier_output(t) = Q_desired;
            end
            
            k_rect = 0.00065;
            voltage_adjust_rect(t) = k_rect * abs(results.REO.rectifier_output(t)) * V_adjust_direction;
            
            if (V_dev > 0 && Q_target < 0) || (V_dev < 0 && Q_target > 0)
                effective_reactive_rect(t) = abs(results.REO.rectifier_output(t));
            end
        end
    end
    
    % 饱和度
    total_active_periods = sum(re_pv > 0) + sum(re_wind > 0);
    if total_active_periods > 0
        results.REO.saturation_ratio = saturation_count / total_active_periods;
    else
        results.REO.saturation_ratio = 0;
    end
    
    results.REO.voltage_adjust_inv = voltage_adjust_inv;
    results.REO.voltage_adjust_rect = voltage_adjust_rect;
    results.REO.effective_reactive_total = mean(effective_reactive_inv + effective_reactive_rect);
    
    effective_reactive_energy = sum(effective_reactive_inv + effective_reactive_rect);
    reactive_gc_revenue = mu * cert_price_kwh * 1000 * effective_reactive_energy / 1000;
    
    results.REO.profit = base_reo_profit + 4000 * (price_factor - 1.0) + reactive_gc_revenue;
    results.REO.revenue = 15000;
    
    alpha_inv = 0.0018;
    alpha_rect = 0.0022;
    results.REO.loss_reduction_inv = alpha_inv * effective_reactive_inv;
    results.REO.loss_reduction_rect = alpha_rect * effective_reactive_rect;
    
    lambda_reward = 0.35;
    c_base = 0.6;
    c_volt = 80;
    results.EMO.reo_reward = sum(lambda_reward * ...
        (c_base * (results.REO.loss_reduction_inv + results.REO.loss_reduction_rect) + ...
         c_volt * abs(voltage_adjust_inv + voltage_adjust_rect)));
    
    results.REO.profit = results.REO.profit + results.EMO.reo_reward;
    
    % Grid
    results.Grid.cost = base_grid_cost + 500 * (price_factor - 1.0);
    results.Grid.base_loss = sys_load * 0.048;
    
    load_variance = std(load_normalized) / mean(load_normalized);
    base_loss_reduction = 0.15 + 0.08 * (1 - load_variance);
    
    k_c = 0.0013; k_T = 0.65; k_SVG = 0.004;
    cap_capacity = round(load_normalized * 5) * 200;
    loss_reduction_cap = k_c * cap_capacity;
    loss_reduction_tap = k_T * ones(1,T) * 0.5;
    loss_reduction_svg = k_SVG * abs((load_normalized - 0.5) * 500);
    
    total_loss_reduction = loss_reduction_cap + loss_reduction_tap + loss_reduction_svg + ...
                          results.REO.loss_reduction_inv + results.REO.loss_reduction_rect;
    
    max_allowed = results.Grid.base_loss * 0.18;
    actual_reduction = min(total_loss_reduction, max_allowed);
    
    results.Grid.actual_loss = max(results.Grid.base_loss - actual_reduction, sys_load * 0.015);
    results.Grid.actual_loss = results.Grid.actual_loss(:)';
    
    % 电压
    results.Grid.base_voltage = base_voltage;
    
    traditional_adjustment = zeros(1, T);
    for t = 1:T
        V_dev = base_voltage(t) - 10.0;
        if V_dev > 0
            traditional_adjustment(t) = -0.02;
        else
            traditional_adjustment(t) = 0.02;
        end
    end
    
    results.Grid.actual_voltage = base_voltage + traditional_adjustment + ...
                                  voltage_adjust_inv + voltage_adjust_rect;
    results.Grid.actual_voltage = min(max(results.Grid.actual_voltage, 9.5), 10.5);
    results.Grid.actual_voltage = results.Grid.actual_voltage(:)';
    
    % ESO & User
    results.ESO.profit = 4000 + 1500 * (price_factor - 1.0);
    results.ESO.charge = zeros(1, T);
    results.ESO.discharge = zeros(1, T);
    results.ESO.charge(valley_hours) = 75;
    results.ESO.discharge(peak_hours) = 600;
    
    green_cert_bonus = 3000 * cert_price_kwh * 1000 / 50;
    results.User.profit = 8000 + green_cert_bonus;
    results.User.satisfaction = 8000 + 1200 * (price_factor - 1.0);
end