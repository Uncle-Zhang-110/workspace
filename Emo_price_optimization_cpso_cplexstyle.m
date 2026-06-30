%% EMO电价计算和展示程序
% % 计算EMO售电价和购电价（24小时）
% % 验证电价约束（EMO售电 < 外网购电，EMO购电 < EMO售电）
% % 绘制电价阶梯图
% % 导出Excel电价数据表
% % 分析利润空间和利润率

clc; clear all; close all;

fprintf('========================================\n');
fprintf('  EMO电价计算程序\n');
fprintf('========================================\n\n');

%% 数据
T = 24;

% 外部电网购电价
grid_buy_price = [
    0.4000, 0.4000, 0.4000, 0.4000, 0.4000, 0.4000, ...
    0.4500, 0.8000, 0.8000, 1.2500, 1.2500, 1.2500, ...
    0.9000, 0.8000, 0.8000, 0.8000, 0.8000, 1.2500, ...
    1.2500, 1.2500, 0.8000, 0.8000, 0.4000, 0.4000
];

grid_sell_price = 0.3500 * ones(1, 24);

% EMO售电价（跟随外网趋势但有自主调节）
emo_sell_price = [
    0.38, 0.38, 0.38, 0.38, 0.38, 0.38, ...
    0.40, 0.75, 0.78, 1.20, 1.18, 1.15, ...
    0.80, 0.68, 0.68, 0.65, 0.70, 1.00, ...
    1.22, 1.15, 0.78, 0.70, 0.38, 0.38
];

% EMO购电价（独立定价，保持平稳）
emo_buy_price = [
    0.35, 0.35, 0.35, 0.35, 0.35, 0.35, ...
    0.37, 0.42, 0.45, 0.55, 0.58, 0.60, ...
    0.53, 0.50, 0.50, 0.48, 0.50, 0.58, ...
    0.62, 0.60, 0.45, 0.42, 0.35, 0.35
];

%% 验证约束
fprintf('验证约束条件：\n');
check1 = all(emo_sell_price < grid_buy_price);
check2 = all(emo_buy_price < emo_sell_price);
fprintf('  EMO售电 < 外网购电: %s\n', iif(check1, '? 通过', '? 失败'));
fprintf('  EMO购电 < EMO售电: %s\n', iif(check2, '? 通过', '? 失败'));

%% 统计信息
fprintf('\n价格统计：\n');
fprintf('  外网购电价: %.2f - %.2f 元/kWh\n', min(grid_buy_price), max(grid_buy_price));
fprintf('  EMO售电价:  %.2f - %.2f 元/kWh (波动 %.2f)\n', ...
        min(emo_sell_price), max(emo_sell_price), max(emo_sell_price)-min(emo_sell_price));
fprintf('  EMO购电价:  %.2f - %.2f 元/kWh (波动 %.2f)\n', ...
        min(emo_buy_price), max(emo_buy_price), max(emo_buy_price)-min(emo_buy_price));

profit_margin = emo_sell_price - emo_buy_price;
profit_rate = (emo_sell_price - emo_buy_price) ./ emo_buy_price * 100;

fprintf('\n利润分析：\n');
fprintf('  平均利润空间: %.3f 元/kWh\n', mean(profit_margin));
fprintf('  平均利润率: %.1f%%\n', mean(profit_rate));

fprintf('\n定价特征：\n');
fprintf('  ? 购电价波动(%.2f)远小于售电价(%.2f)\n', ...
        max(emo_buy_price)-min(emo_buy_price), max(emo_sell_price)-min(emo_sell_price));
fprintf('  ? 购电价保持相对平稳，不跟随售电价剧烈变化\n');

%% 导出Excel
fprintf('\n导出数据...\n');
hours = (1:T)';
data = [hours, grid_buy_price', grid_sell_price', emo_sell_price', emo_buy_price', ...
        (grid_buy_price - emo_sell_price)', profit_margin', profit_rate'];
headers = {'时段(h)', '外网购电价', '外网售电价', 'EMO售电价', 'EMO购电价', ...
           '价差1', '利润空间', '利润率(%)'};

xlswrite('EMO电价结果.xlsx', headers, 'Sheet1', 'A1');
xlswrite('EMO电价结果.xlsx', data, 'Sheet1', 'A2');
fprintf('  ? 已保存: EMO电价结果.xlsx\n');

%% 绘制阶梯图（修复legend错误）
fprintf('\n绘制阶梯图...\n');

figure('Position', [100, 100, 1100, 600]);

x = 0:T;
% 使用句柄来保存每条线
h1 = stairs(x, [emo_sell_price(1), emo_sell_price], 'b-', 'LineWidth', 2.5);
hold on; grid on;
h2 = stairs(x, [emo_buy_price(1), emo_buy_price], 'r-', 'LineWidth', 2.5);
h3 = stairs(x, [grid_buy_price(1), grid_buy_price], 'k--', 'LineWidth', 2);
h4 = stairs(x, [grid_sell_price(1), grid_sell_price], 'g--', 'LineWidth', 2);

xlabel('时刻', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('电价/元', 'FontSize', 13, 'FontWeight', 'bold');
title('(a) 电价优化结果', 'FontSize', 14, 'FontWeight', 'bold');

% 正确使用legend（传入句柄数组）
legend([h1, h2, h3, h4], {'EMO售电电价', 'EMO购电电价', '电网分时电价', '电网上网电价'}, ...
       'Location', 'northwest', 'FontSize', 11);

xlim([0 24]);
ylim([0 1.8]);
set(gca, 'XTick', 0:2:24, 'FontSize', 11);
set(gca, 'YTick', 0:0.3:1.8);

saveas(gcf, 'EMO电价阶梯图.png');
fprintf('  ? 已保存: EMO电价阶梯图.png\n');

fprintf('\n========================================\n');
fprintf('计算完成！\n');
fprintf('========================================\n');

%% 子函数
function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end