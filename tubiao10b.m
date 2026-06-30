% =========================================================================
% Figure 10(b): Average Voltage Deviation (Fully Chinese Version)
% =========================================================================
clear; clc; close all;

% --- 1. Data Preparation ---
N = 50;
mu_vals = linspace(0, 0.12, N);        
price_vals = linspace(0, 100, N);      
[X, Y] = meshgrid(mu_vals, price_vals);

% [Simulated Data Z2] -> 请务必替换为你的真实电压数据矩阵
% (逻辑：强制将最低点对齐到 Table 3 的 0.2713 kV)
Z_base2 = 0.31 - 0.035 * (1 - exp(-(X .* Y) / 2.0)) + 0.002 * (X - 0.08).^2;
offset2 = 0.2713 - min(Z_base2(:));
Z2 = Z_base2 + offset2; 

dead_zone_val = 0.02;

% --- 2. Plotting ---
figure('Units', 'pixels', 'Position', [150, 150, 800, 650], 'Color', 'w');
ax2 = gca; hold on;

% 底部投影高度 (根据数据范围调整，设在 0.265 左右比较合适)
z_min2 = min(Z2(:)); z_range2 = range(Z2(:)); z_floor2 = 0.268;

% 绘制底部和主体
surf(X, Y, ones(size(Z2)) * z_floor2, Z2, 'EdgeColor', 'none', 'FaceColor', 'interp');
hSurf2 = surf(X, Y, Z2, 'EdgeColor', 'none', 'FaceColor', 'interp', 'FaceAlpha', 1.0);

% --- 3. Annotations ---
[min_val2, idx2] = min(Z2(:));
[r2, c2] = ind2sub(size(Z2), idx2);
x_opt2 = X(r2, c2); y_opt2 = Y(r2, c2); z_opt2 = Z2(r2, c2);

plot3([x_opt2 x_opt2], [y_opt2 y_opt2], [z_floor2 z_opt2], 'k--', 'LineWidth', 1.5);
scatter3(x_opt2, y_opt2, z_opt2, 100, 'r', 'filled', 'MarkerEdgeColor', 'k');
plot3(x_opt2, y_opt2, z_floor2 + 0.001, 'rx', 'MarkerSize', 15, 'LineWidth', 2);

% 修改为全中文，并将字体改为宋体以防止乱码
text(x_opt2, y_opt2, z_opt2 + z_range2*0.15, sprintf('\\bf 范围内较优\n(%.2f, %.0f)\n数值: 0.2713 kV', x_opt2, y_opt2), ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'FontName', '宋体', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 1);

% 死区文字修改为中文，字体改为宋体
plot3([dead_zone_val dead_zone_val], [0 100], [z_floor2 z_floor2], 'k-', 'LineWidth', 2.5); 
text(0.01, 50, z_floor2 + z_range2*0.05, '\bf 低敏感区', 'Color', 'k', 'FontSize', 12, ...
    'FontName', '宋体', 'HorizontalAlignment', 'center');

% --- 4. Settings & Beautification ---
view(-25, 40); grid on; box on;
xlim([0 0.12]); ylim([0 100]); zlim([z_floor2 max(Z2(:))]);

% 坐标轴标签设置为宋体，解决方块乱码问题
xlabel('无功估值系数 \mu', 'FontSize', 14, 'FontName', '宋体');
ylabel('绿证价格 (元)', 'FontSize', 14, 'FontName', '宋体');
zlabel('平均电压偏差 (kV)', 'FontSize', 14, 'FontName', '宋体');

% 保持原有配色和材质
colormap(jet); 
colorbar;
camlight left; 
lighting gouraud; 
material shiny; 

% 统一提亮
all_surfs = findobj(gca, 'Type', 'Surface');
set(all_surfs, 'AmbientStrength', 0.6); 
set(all_surfs, 'DiffuseStrength', 0.8);