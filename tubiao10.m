% =========================================================================
% Figure 10(a): Average Grid Loss (Fully Chinese Version)
% =========================================================================
clear; clc; close all;

% --- 1. Data Preparation ---
N = 50;
mu_vals = linspace(0, 0.12, N);        
price_vals = linspace(0, 100, N);      
[X, Y] = meshgrid(mu_vals, price_vals);

% [Simulated Data Z1] -> 请务必替换为你的真实数据矩阵
% (保持与 Table 3 的 78.5 对齐)
Z_base = 79.2 - 0.7 * (1 - exp(-(X .* Y) / 1.5)) + 0.05 * (X - 0.08).^2; 
offset1 = 78.5 - min(Z_base(:));
Z1 = Z_base + offset1; 

dead_zone_val = 0.02;

% --- 2. Plotting ---
figure('Units', 'pixels', 'Position', [100, 100, 800, 650], 'Color', 'w');
ax1 = gca; hold on;

% 底部投影高度
z_min = min(Z1(:)); z_range = range(Z1(:)); z_floor = 77.5; 

% 绘制底部和主体
surf(X, Y, ones(size(Z1)) * z_floor, Z1, 'EdgeColor', 'none', 'FaceColor', 'interp');
hSurf = surf(X, Y, Z1, 'EdgeColor', 'none', 'FaceColor', 'interp', 'FaceAlpha', 1.0);

% --- 3. Annotations ---
[min_val, idx] = min(Z1(:));
[r, c] = ind2sub(size(Z1), idx);
x_opt = X(r, c); y_opt = Y(r, c); z_opt = Z1(r, c);

plot3([x_opt x_opt], [y_opt y_opt], [z_floor z_opt], 'k--', 'LineWidth', 1.5);
scatter3(x_opt, y_opt, z_opt, 100, 'r', 'filled', 'MarkerEdgeColor', 'k');
plot3(x_opt, y_opt, z_floor + 0.01, 'rx', 'MarkerSize', 15, 'LineWidth', 2);

% 修改为全中文，并将字体改为宋体以防止乱码
text(x_opt, y_opt, z_opt + z_range*0.15, sprintf('\\bf 范围内较优\n(%.2f, %.0f)\n数值: 78.5 kW', x_opt, y_opt), ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'FontName', '宋体', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 1);

plot3([dead_zone_val dead_zone_val], [0 100], [z_floor z_floor], 'k-', 'LineWidth', 2.5);
% 死区修改为中文，字体改为宋体
text(0.01, 50, z_floor + z_range*0.05, '\bf 低敏感区', 'Color', 'k', 'FontSize', 12, ...
    'FontName', '宋体', 'HorizontalAlignment', 'center');

% --- 4. Settings & Beautification ---
view(-25, 40); grid on; box on;
xlim([0 0.12]); ylim([0 100]); zlim([z_floor max(Z1(:))]);

% 坐标轴标签设置为宋体，解决方块乱码问题
xlabel('无功估值系数 \mu', 'FontSize', 14, 'FontName', '宋体');
ylabel('绿证价格 (元)', 'FontSize', 14, 'FontName', '宋体');
zlabel('平均有功网损 (kW)', 'FontSize', 14, 'FontName', '宋体');

% 保持配色和侧光
colormap(jet); 
colorbar;
camlight left; 
lighting gouraud; 
material shiny; 

% 提亮表面
all_surfs = findobj(gca, 'Type', 'Surface');
set(all_surfs, 'AmbientStrength', 0.6); 
set(all_surfs, 'DiffuseStrength', 0.8); 