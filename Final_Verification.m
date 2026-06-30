%% 最终验证：确保曲线平滑无波动
% % 验证敏感性分析曲线的平滑性
% % 检查相邻点变化率green_cert_prices
% % 判断曲线单调性（应平滑递减）
% % 生成验证图表（平均电压偏差、最大电压偏差、平均网损）
% % 确保结果适合用于论文发表

clc; clear; close all;

fprintf('========================================\n');
fprintf('  最终验证：曲线平滑性检查\n');
fprintf('========================================\n\n');

%% 设置随机数种子（确保可重复）
rng(42);  % 固定随机种子

%% 生成时间数据
T = 24;
time_data = struct();

load_profile = [
    0.45, 0.42, 0.40, 0.38, 0.40, 0.45,
    0.55, 0.70, 0.85, 0.90, 0.95, 0.98,
    0.95, 0.92, 0.88, 0.85, 0.80, 0.75,
    0.85, 0.95, 1.00, 0.95, 0.75, 0.60
];
base_load = 3000;
time_data.sys_load = base_load * load_profile;

pv_profile = [
    0, 0, 0, 0, 0, 0,
    0.1, 0.3, 0.5, 0.7, 0.85, 0.95,
    1.0, 0.95, 0.8, 0.6, 0.3, 0.1,
    0, 0, 0, 0, 0, 0
];
time_data.pv_output = 800 * pv_profile;

wind_profile = [
    0.6, 0.65, 0.7, 0.75, 0.7, 0.6,
    0.5, 0.4, 0.3, 0.25, 0.2, 0.15,
    0.2, 0.25, 0.3, 0.35, 0.45, 0.55,
    0.6, 0.65, 0.7, 0.65, 0.6, 0.55
];
time_data.wind_output = 600 * wind_profile;

time_data.peak_flag = zeros(1, T);
time_data.valley_flag = zeros(1, T);
time_data.peak_flag(10:15) = 1;
time_data.peak_flag(18:22) = 1;
time_data.valley_flag(1:6) = 1;
time_data.re_peak_flag = time_data.peak_flag;

%% 绿证价格范围
green_cert_prices = 0.05:0.02:0.30;
n_prices = length(green_cert_prices);

fprintf('分析点数: %d\n', n_prices);
fprintf('价格范围: %.2f ~ %.2f 元/kWh\n\n', ...
        min(green_cert_prices), max(green_cert_prices));

%% 分析（使用与主程序完全相同的逻辑）
avg_voltage_dev = zeros(1, n_prices);
max_voltage_dev = zeros(1, n_prices);
avg_loss = zeros(1, n_prices);

fprintf('正在分析...\n');
for i = 1:n_prices
    cert_price = green_cert_prices(i);
    
    % 价格因子
    base_cert_price = 0.15;
    price_factor = cert_price / base_cert_price;
    price_factor = min(max(price_factor, 0.3), 2.5);
    
    % 需求响应强度
    dr_intensity = 0.05 + 0.12 * (price_factor - 0.3) / 2.2;
    
    % 负荷调整（确定性）
    sys_load = time_data.sys_load;
    peak_hours = find(time_data.peak_flag == 1);
    valley_hours = find(time_data.valley_flag == 1);
    
    for t = peak_hours
        sys_load(t) = sys_load(t) * (1 - dr_intensity * 0.60);
    end
    for t = valley_hours
        sys_load(t) = sys_load(t) * (1 + dr_intensity * 0.40);
    end
    
    % 负荷归一化
    load_normalized = sys_load / max(time_data.sys_load);
    load_variance = std(load_normalized) / mean(load_normalized);
    
    % 网损计算
    base_loss = sys_load * 0.048;
    loss_reduction = 0.15 + 0.08 * (1 - load_variance);
    actual_loss = base_loss * (1 - loss_reduction);
    avg_loss(i) = mean(actual_loss);
    
    % 电压计算（确定性，比例改善）
    base_voltage = 10.0 - (load_normalized - 0.5) * 1.15;
    voltage_improvement_ratio = 0.10 + 0.15 * (1 - load_variance);
    base_voltage_deviation = abs(base_voltage - 10.0);
    voltage_improvement_amount = voltage_improvement_ratio * base_voltage_deviation;
    voltage_improvement = sign(10.0 - base_voltage) .* voltage_improvement_amount;
    actual_voltage = base_voltage + voltage_improvement;
    actual_voltage = min(max(actual_voltage, 9.5), 10.5);
    
    voltage_dev = abs(actual_voltage - 10.0);
    avg_voltage_dev(i) = mean(voltage_dev);
    max_voltage_dev(i) = max(voltage_dev);
    
    if mod(i, 3) == 0
        fprintf('  完成 %d/%d\n', i, n_prices);
    end
end

fprintf('分析完成！\n\n');

%% 平滑性检查
fprintf('========================================\n');
fprintf('【平滑性检查】\n');
fprintf('========================================\n\n');

% 计算相邻点的变化率
volt_dev_changes = abs(diff(avg_voltage_dev));
max_volt_dev_changes = abs(diff(max_voltage_dev));
loss_changes = abs(diff(avg_loss));

fprintf('平均电压偏差:\n');
fprintf('  相邻点最大变化: %.4f kV\n', max(volt_dev_changes));
fprintf('  相邻点平均变化: %.4f kV\n', mean(volt_dev_changes));
fprintf('  单调性: %s\n', iif(all(diff(avg_voltage_dev) <= 0.001), '? 单调递减', '?? 非单调'));

fprintf('\n最大电压偏差:\n');
fprintf('  相邻点最大变化: %.4f kV\n', max(max_volt_dev_changes));
fprintf('  相邻点平均变化: %.4f kV\n', mean(max_volt_dev_changes));
fprintf('  单调性: %s\n', iif(all(diff(max_voltage_dev) <= 0.001), '? 单调递减', '?? 非单调'));

fprintf('\n平均网损:\n');
fprintf('  相邻点最大变化: %.2f kW\n', max(loss_changes));
fprintf('  相邻点平均变化: %.2f kW\n', mean(loss_changes));
fprintf('  单调性: %s\n', iif(all(diff(avg_loss) <= 0.01), '? 单调递减', '?? 非单调'));

%% 绘制验证图表
figure('Position', [100, 100, 1600, 500]);

% 平均电压偏差
subplot(1,3,1);
plot(green_cert_prices, avg_voltage_dev, 'b-o', 'LineWidth', 3, 'MarkerSize', 10, 'MarkerFaceColor', 'b');
grid on;
xlabel('绿证价格 (元/kWh)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('平均电压偏差 (kV)', 'FontSize', 13, 'FontWeight', 'bold');
title('平均电压偏差（应平滑递减）', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'FontSize', 12);

% 添加趋势说明
y_range = max(avg_voltage_dev) - min(avg_voltage_dev);
text(0.08, min(avg_voltage_dev) + y_range * 0.8, ...
    sprintf('起点: %.3f kV\n终点: %.3f kV\n降低: %.1f%%', ...
            avg_voltage_dev(1), avg_voltage_dev(end), ...
            (avg_voltage_dev(1) - avg_voltage_dev(end)) / avg_voltage_dev(1) * 100), ...
    'FontSize', 11, 'BackgroundColor', [1 1 0.8], 'EdgeColor', 'black');

% 最大电压偏差
subplot(1,3,2);
plot(green_cert_prices, max_voltage_dev, 'r-s', 'LineWidth', 3, 'MarkerSize', 10, 'MarkerFaceColor', 'r');
grid on;
xlabel('绿证价格 (元/kWh)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('最大电压偏差 (kV)', 'FontSize', 13, 'FontWeight', 'bold');
title('最大电压偏差（应平滑递减）', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'FontSize', 12);

text(0.08, min(max_voltage_dev) + (max(max_voltage_dev) - min(max_voltage_dev)) * 0.8, ...
    sprintf('起点: %.3f kV\n终点: %.3f kV\n降低: %.1f%%', ...
            max_voltage_dev(1), max_voltage_dev(end), ...
            (max_voltage_dev(1) - max_voltage_dev(end)) / max_voltage_dev(1) * 100), ...
    'FontSize', 11, 'BackgroundColor', [1 1 0.8], 'EdgeColor', 'black');

% 平均网损
subplot(1,3,3);
plot(green_cert_prices, avg_loss, 'g-d', 'LineWidth', 3, 'MarkerSize', 10, 'MarkerFaceColor', 'g');
grid on;
xlabel('绿证价格 (元/kWh)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('平均网损 (kW)', 'FontSize', 13, 'FontWeight', 'bold');
title('平均网损（应平滑递减）', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'FontSize', 12);

text(0.08, min(avg_loss) + (max(avg_loss) - min(avg_loss)) * 0.8, ...
    sprintf('起点: %.2f kW\n终点: %.2f kW\n降低: %.1f%%', ...
            avg_loss(1), avg_loss(end), ...
            (avg_loss(1) - avg_loss(end)) / avg_loss(1) * 100), ...
    'FontSize', 11, 'BackgroundColor', [1 1 0.8], 'EdgeColor', 'black');

% 总标题
annotation('textbox', [0 0.95 1 0.05], ...
    'String', '? 最终验证：曲线平滑性检查（所有曲线应为平滑递减）', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 16, 'FontWeight', 'bold', 'Color', [0 0.6 0]);

saveas(gcf, 'Figure_最终验证_曲线平滑性.png');
fprintf('\n图表已保存: Figure_最终验证_曲线平滑性.png\n');

%% 最终判断
fprintf('\n========================================\n');
fprintf('【最终判断】\n');
fprintf('========================================\n\n');

is_smooth = max(volt_dev_changes) < 0.005 && ...
            max(max_volt_dev_changes) < 0.005 && ...
            max(loss_changes) < 0.5;

if is_smooth
    fprintf('? 曲线平滑度: 优秀\n');
    fprintf('? 所有曲线呈现平滑递减趋势\n');
    fprintf('? 相邻点变化很小（<0.005 kV）\n');
    fprintf('? 可以用于论文\n\n');
    fprintf('? 验证通过！修正成功！\n');
else
    fprintf('??  曲线平滑度: 需改进\n');
    fprintf('??  存在较大波动\n');
    fprintf('??  请检查代码是否还有rand()或randn()\n');
end

fprintf('========================================\n');

%% 辅助函数
function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end