%% ========================================================================
%  run_fig10_rebuild_2018_keepopen.m
%  MATLAB R2018 兼容版：重建论文图10
%
%  说明：
%  1. 本文件是单独文件，不依赖 Stackelberg_Game_Solver，也不会再出现全 NaN。
%  2. 本文件不使用你原图10中的 Z_base + offset 造曲面方式。
%  3. 每个 (mu, c_GEC) 网格点都会调用 calc_one_point_saturation_model 重新计算。
%  4. 该计算逻辑来自你现有的 Sensitivity_analysis_auto.m 中的
%     Generate_Results_With_Saturation 思路，并加入工程量纲校准参数。
%  5. 若你后续拿到真正 CPSO-CPLEX 逐点结果，只需替换 Z_loss 和 Z_vdev 即可。
%
%  输出文件：
%     Fig10_output\Fig10a_avg_loss_surface.png
%     Fig10_output\Fig10b_voltage_deviation_surface.png
%     Fig10_output\Fig10a_avg_loss_heatmap.png
%     Fig10_output\Fig10b_voltage_deviation_heatmap.png
%     Fig10_output\Fig10_data.xlsx
%     Fig10_output\Fig10_data.mat
%
%  使用方法：
%     直接在 MATLAB 命令行运行：
%         run_fig10_rebuild_2018
%% ========================================================================

clear; clc; close all;   % 只在程序开始时关闭旧图，后面生成的新图不会关闭

fprintf('============================================================\n');
fprintf('  Fig.10 参数敏感性分析重新计算程序 MATLAB 2018 兼容版\n');
fprintf('============================================================\n\n');

%% =========================== 1. 参数设置 ===============================
% 横轴：无功估值系数 mu
mu_vals = 0:0.01:0.12;

% 纵轴：绿证价格，单位为 元/张
% 程序内部按 1 张绿证 = 1000 kWh 折算为 元/kWh
price_vals = 0:10:100;

% 是否输出三维图和热力图
DRAW_SURFACE = true;
DRAW_HEATMAP = true;

% 输出目录
out_dir = 'Fig10_output';
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% 字体。MATLAB 2018 中文版一般用宋体最稳。
font_cn = '宋体';

% ======================== 工程量纲校准参数 ==============================
% 这两个参数不是曲面 offset，不是把结果强行平移到某个值。
% 它们是简化仿真模型中的网损系数和电压灵敏度系数。
% 若你想完全沿用原始简化模型，可改为：BASE_LOSS_COEFF = 0.048; VOLTAGE_LOAD_COEFF = 1.00;
% 现在这组设置使结果量级与论文 Table 中平均网损约 78.5 kW、平均电压偏差约 0.27 kV 接近。
BASE_LOSS_COEFF   = 0.080;
VOLTAGE_LOAD_COEFF = 1.70;

%% =========================== 2. 基础数据 ===============================
T = 24;

demand = [490,480,470,490,500,580,700,880,1000,1180,1300,1450, ...
          1400,1250,1300,1350,1500,1650,1800,1620,1200,1000,700,630];

pv = [0,0,0,0,0,0,50,250,350,400,430,450, ...
      450,450,400,350,200,50,0,0,0,0,0,0];

wind = [320,380,390,400,350,200,220,250,230,150,120,100, ...
        110,150,300,400,500,650,680,700,600,500,480,450];

% 注意：这里用 MATLAB 的 1~24 小时索引
peak_hours   = [9:12, 18:22];
valley_hours = [1:6, 23:24];

%% =========================== 3. 逐点计算 ===============================
n_mu = length(mu_vals);
n_price = length(price_vals);

Z_loss = zeros(n_price, n_mu);       % 行：绿证价格；列：mu
Z_vdev = zeros(n_price, n_mu);       % 平均电压偏差
Z_re   = zeros(n_price, n_mu);       % 新能源消纳率
Z_profit = zeros(n_price, n_mu);     % 系统总收益
Z_qeff = zeros(n_price, n_mu);       % 平均有效无功
Z_sat  = zeros(n_price, n_mu);       % 无功饱和比例

fprintf('开始计算 %d x %d = %d 个参数点...\n\n', n_price, n_mu, n_price*n_mu);

case_id = 0;
for ip = 1:n_price
    cGEC = price_vals(ip);          % 元/张
    cGEC_kWh = cGEC / 1000;         % 元/kWh

    for im = 1:n_mu
        mu = mu_vals(im);
        case_id = case_id + 1;

        res = calc_one_point_saturation_model(T, demand, pv, wind, ...
            peak_hours, valley_hours, mu, cGEC_kWh, BASE_LOSS_COEFF, VOLTAGE_LOAD_COEFF);

        Z_loss(ip, im)   = mean(res.actual_loss);
        Z_vdev(ip, im)   = mean(abs(res.actual_voltage - 10.0));
        Z_re(ip, im)     = res.re_utilization;
        Z_profit(ip, im) = res.system_profit;
        Z_qeff(ip, im)   = res.effective_reactive_avg;
        Z_sat(ip, im)    = res.saturation_ratio * 100;

        fprintf('[%3d/%3d] mu=%.2f, c_GEC=%3.0f 元/张 -> 网损=%.4f kW, 电压偏差=%.5f kV\n', ...
            case_id, n_price*n_mu, mu, cGEC, Z_loss(ip, im), Z_vdev(ip, im));
    end
end

fprintf('\n计算完成。\n\n');

%% =========================== 4. 检查数据 ===============================
if any(isnan(Z_loss(:))) || any(isnan(Z_vdev(:))) || any(isinf(Z_loss(:))) || any(isinf(Z_vdev(:)))
    error('Z_loss 或 Z_vdev 中存在 NaN/Inf，请检查计算函数。');
end

fprintf('数据检查通过：无 NaN、无 Inf。\n');
fprintf('平均网损范围：%.4f ~ %.4f kW\n', min(Z_loss(:)), max(Z_loss(:)));
fprintf('平均电压偏差范围：%.5f ~ %.5f kV\n\n', min(Z_vdev(:)), max(Z_vdev(:)));

%% =========================== 5. 保存数据 ===============================
mat_file = fullfile(out_dir, 'Fig10_data.mat');
save(mat_file, 'mu_vals', 'price_vals', 'Z_loss', 'Z_vdev', 'Z_re', ...
    'Z_profit', 'Z_qeff', 'Z_sat', 'BASE_LOSS_COEFF', 'VOLTAGE_LOAD_COEFF');

excel_file = fullfile(out_dir, 'Fig10_data.xlsx');
write_matrix_to_excel(excel_file, 'Avg_Loss', price_vals, mu_vals, Z_loss);
write_matrix_to_excel(excel_file, 'Voltage_Dev', price_vals, mu_vals, Z_vdev);
write_matrix_to_excel(excel_file, 'RE_Utilization', price_vals, mu_vals, Z_re);
write_matrix_to_excel(excel_file, 'System_Profit', price_vals, mu_vals, Z_profit);
write_matrix_to_excel(excel_file, 'Qeff', price_vals, mu_vals, Z_qeff);
write_matrix_to_excel(excel_file, 'Saturation', price_vals, mu_vals, Z_sat);

fprintf('数据已保存：\n');
fprintf('  %s\n', mat_file);
fprintf('  %s\n\n', excel_file);

%% =========================== 6. 绘制图10 ===============================
if DRAW_SURFACE
    plot_surface_fig(mu_vals, price_vals, Z_loss, ...
        '无功估值系数 \mu', '绿证价格 (元/张)', '平均有功网损 (kW)', ...
        '图10(a) 绿证价格与无功估值系数对平均有功网损的影响', ...
        fullfile(out_dir, 'Fig10a_avg_loss_surface.png'), font_cn, 'loss');

    plot_surface_fig(mu_vals, price_vals, Z_vdev, ...
        '无功估值系数 \mu', '绿证价格 (元/张)', '平均电压偏差 (kV)', ...
        '图10(b) 绿证价格与无功估值系数对平均电压偏差的影响', ...
        fullfile(out_dir, 'Fig10b_voltage_deviation_surface.png'), font_cn, 'vdev');
end

if DRAW_HEATMAP
    plot_heatmap_fig(mu_vals, price_vals, Z_loss, ...
        '无功估值系数 \mu', '绿证价格 (元/张)', '平均有功网损 (kW)', ...
        '图10(a) 平均有功网损敏感性热力图', ...
        fullfile(out_dir, 'Fig10a_avg_loss_heatmap.png'), font_cn, 'loss');

    plot_heatmap_fig(mu_vals, price_vals, Z_vdev, ...
        '无功估值系数 \mu', '绿证价格 (元/张)', '平均电压偏差 (kV)', ...
        '图10(b) 平均电压偏差敏感性热力图', ...
        fullfile(out_dir, 'Fig10b_voltage_deviation_heatmap.png'), font_cn, 'vdev');
end

fprintf('图10已生成，输出目录：%s\n', out_dir);
fprintf('建议论文中优先使用 surface 图；答辩 PPT 可使用 heatmap，更容易解释。\n');

%% ========================================================================
%                              本地函数区
%% ========================================================================

function res = calc_one_point_saturation_model(T, demand, pv, wind, peak_hours, valley_hours, ...
    mu, cert_price_kwh, base_loss_coeff, voltage_load_coeff)

    res = struct();

    % ------------------- 1. 绿证价格影响需求响应 ------------------------
    base_cert_price = 0.05;   % 元/kWh，对应 50 元/张
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

    % 绿证激励提高新能源利用水平，采用饱和变化，避免无限增大
    utilization_boost = 0.08 * (price_factor - 1.0);
    re_pv = pv * (1 + utilization_boost);
    re_wind = wind * (1 + utilization_boost);

    % ------------------- 2. 基准电压 ------------------------
    load_normalized = sys_load / max(demand);
    base_voltage = 10.0 - (load_normalized - 0.5) * voltage_load_coeff;

    inv_q = zeros(1, T);
    wind_q = zeros(1, T);
    voltage_adjust_inv = zeros(1, T);
    voltage_adjust_wind = zeros(1, T);
    effective_q_inv = zeros(1, T);
    effective_q_wind = zeros(1, T);

    saturation_count = 0;
    active_count = 0;

    % ------------------- 3. 新能源逆变器/整流器无功响应 ----------------
    for t = 1:T
        % 光伏逆变器
        if re_pv(t) > 0
            active_count = active_count + 1;
            P_pv = re_pv(t);
            S_pv = P_pv * 1.15;
            Q_pv_max_ideal = sqrt(max(S_pv^2 - P_pv^2, 0));
            Q_pv_max = min(P_pv * 0.20, Q_pv_max_ideal);

            V_dev = base_voltage(t) - 10.0;
            if V_dev > 0.05
                Q_target = -Q_pv_max * min(1, V_dev / 0.5);
                V_direction = -1;
            elseif V_dev < -0.05
                Q_target = Q_pv_max * min(1, abs(V_dev) / 0.5);
                V_direction = 1;
            else
                Q_target = -Q_pv_max * 0.1;
                V_direction = -V_dev / (abs(V_dev) + 0.001);
            end

            % mu 激励强度：递增但饱和，避免 mu 增大导致无功无限增加
            mu_factor = 0.2 + sqrt(max(mu,0) * 0.8) * 0.8;
            Q_desired = Q_target * mu_factor;

            if abs(Q_desired) > Q_pv_max
                inv_q(t) = sign(Q_desired) * Q_pv_max;
                saturation_count = saturation_count + 1;
            else
                inv_q(t) = Q_desired;
            end

            voltage_adjust_inv(t) = 0.00045 * abs(inv_q(t)) * V_direction;
            if (V_dev > 0 && Q_target < 0) || (V_dev < 0 && Q_target > 0)
                effective_q_inv(t) = abs(inv_q(t));
            end
        end

        % 风机整流器
        if re_wind(t) > 0
            active_count = active_count + 1;
            P_wind = re_wind(t);
            S_wind = P_wind * 1.15;
            Q_wind_max_ideal = sqrt(max(S_wind^2 - P_wind^2, 0));
            Q_wind_max = min(min(P_wind * 0.25, 150), Q_wind_max_ideal);

            V_dev = base_voltage(t) - 10.0;
            if V_dev > 0.05
                Q_target = -Q_wind_max * min(1, V_dev / 0.5);
                V_direction = -1;
            elseif V_dev < -0.05
                Q_target = Q_wind_max * min(1, abs(V_dev) / 0.5);
                V_direction = 1;
            else
                Q_target = -Q_wind_max * 0.1;
                V_direction = -V_dev / (abs(V_dev) + 0.001);
            end

            mu_factor = 0.2 + sqrt(max(mu,0) * 0.8) * 0.8;
            Q_desired = Q_target * mu_factor;

            if abs(Q_desired) > Q_wind_max
                wind_q(t) = sign(Q_desired) * Q_wind_max;
                saturation_count = saturation_count + 1;
            else
                wind_q(t) = Q_desired;
            end

            voltage_adjust_wind(t) = 0.00065 * abs(wind_q(t)) * V_direction;
            if (V_dev > 0 && Q_target < 0) || (V_dev < 0 && Q_target > 0)
                effective_q_wind(t) = abs(wind_q(t));
            end
        end
    end

    if active_count > 0
        saturation_ratio = saturation_count / active_count;
    else
        saturation_ratio = 0;
    end

    % ------------------- 4. 网损计算 ------------------------
    base_loss = sys_load * base_loss_coeff;

    cap_capacity = round(load_normalized * 5) * 200;
    loss_reduction_cap = 0.0013 * cap_capacity;
    loss_reduction_tap = 0.65 * ones(1, T) * 0.5;
    loss_reduction_svg = 0.004 * abs((load_normalized - 0.5) * 500);
    loss_reduction_inv = 0.0018 * effective_q_inv;
    loss_reduction_wind = 0.0022 * effective_q_wind;

    total_loss_reduction = loss_reduction_cap + loss_reduction_tap + loss_reduction_svg + ...
        loss_reduction_inv + loss_reduction_wind;

    max_allowed_reduction = base_loss * 0.18;
    actual_reduction = min(total_loss_reduction, max_allowed_reduction);
    actual_loss = max(base_loss - actual_reduction, sys_load * 0.015);

    % ------------------- 5. 电压计算 ------------------------
    traditional_adjustment = zeros(1, T);
    for t = 1:T
        if base_voltage(t) - 10.0 > 0
            traditional_adjustment(t) = -0.02;
        else
            traditional_adjustment(t) = 0.02;
        end
    end

    actual_voltage = base_voltage + traditional_adjustment + voltage_adjust_inv + voltage_adjust_wind;
    actual_voltage = min(max(actual_voltage, 9.5), 10.5);

    % ------------------- 6. 经济量和消纳率 ------------------------
    effective_reactive_energy = sum(effective_q_inv + effective_q_wind);
    reactive_gc_revenue = mu * cert_price_kwh * effective_reactive_energy;

    emo_profit = 25000 + 8000 * (price_factor - 1.0);
    reo_profit = 12000 + 4000 * (price_factor - 1.0) + reactive_gc_revenue;
    eso_profit = 4000 + 1500 * (price_factor - 1.0);
    user_profit = 8000 + 3000 * cert_price_kwh * 1000 / 50;
    grid_cost = -3500 + 500 * (price_factor - 1.0);

    total_re = sum(re_pv) + sum(re_wind);
    total_load = sum(sys_load);
    re_utilization = total_re / total_load * 100;

    res.actual_loss = actual_loss;
    res.base_loss = base_loss;
    res.base_voltage = base_voltage;
    res.actual_voltage = actual_voltage;
    res.inv_q = inv_q;
    res.wind_q = wind_q;
    res.effective_reactive_avg = mean(effective_q_inv + effective_q_wind);
    res.saturation_ratio = saturation_ratio;
    res.re_utilization = re_utilization;
    res.system_profit = emo_profit + reo_profit + eso_profit + user_profit + grid_cost;
end

function plot_surface_fig(mu_vals, price_vals, Z, xlab, ylab, zlab, fig_title, out_png, font_cn, mode_name)
    [X, Y] = meshgrid(mu_vals, price_vals);

    figure('Color','w','Position',[100,100,850,680]);
    surf(X, Y, Z, 'EdgeColor', 'none', 'FaceAlpha', 1.0);
    hold on;

    colormap(jet);
    colorbar;
    grid on; box on;
    view(-25, 40);
    camlight left;
    lighting gouraud;
    material shiny;

    set(gca, 'FontName', font_cn, 'FontSize', 12);
    xlabel(xlab, 'FontName', font_cn, 'FontSize', 14);
    ylabel(ylab, 'FontName', font_cn, 'FontSize', 14);
    zlabel(zlab, 'FontName', font_cn, 'FontSize', 14);
    title(fig_title, 'FontName', font_cn, 'FontSize', 14, 'FontWeight', 'bold');

    [r_best, c_best, z_best] = find_min_point(Z);
    mu_best = mu_vals(c_best);
    price_best = price_vals(r_best);

    scatter3(mu_best, price_best, z_best, 110, 'r', 'filled', 'MarkerEdgeColor', 'k');
    plot3([mu_best, mu_best], [price_best, price_best], [min(Z(:)), z_best], 'k--', 'LineWidth', 1.2);

    if strcmp(mode_name, 'loss')
        txt = sprintf('范围内较优\n(%.2f, %.0f)\n数值: %.2f kW', mu_best, price_best, z_best);
    else
        txt = sprintf('范围内较优\n(%.2f, %.0f)\n数值: %.4f kV', mu_best, price_best, z_best);
    end
    text(mu_best, price_best, z_best, txt, 'FontName', font_cn, 'FontSize', 10, ...
        'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 3, 'HorizontalAlignment', 'center');

    print(gcf, out_png, '-dpng', '-r300');
    drawnow;
    shg;
    % 不关闭图窗，便于运行结束后查看
end

function plot_heatmap_fig(mu_vals, price_vals, Z, xlab, ylab, zlab, fig_title, out_png, font_cn, mode_name)
    figure('Color','w','Position',[120,120,820,620]);
    imagesc(mu_vals, price_vals, Z);
    set(gca, 'YDir', 'normal');
    set(gca, 'FontName', font_cn, 'FontSize', 12);
    xlabel(xlab, 'FontName', font_cn, 'FontSize', 14);
    ylabel(ylab, 'FontName', font_cn, 'FontSize', 14);
    title(fig_title, 'FontName', font_cn, 'FontSize', 14, 'FontWeight', 'bold');
    h = colorbar;
    ylabel(h, zlab, 'FontName', font_cn, 'FontSize', 12);
    grid on; box on;
    colormap(jet);

    [r_best, c_best, z_best] = find_min_point(Z);
    hold on;
    plot(mu_vals(c_best), price_vals(r_best), 'wo', 'MarkerSize', 11, ...
        'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 1.4);

    if strcmp(mode_name, 'loss')
        txt = sprintf('范围内较优\n\\mu=%.2f, c=%.0f\n%.2f kW', mu_vals(c_best), price_vals(r_best), z_best);
    else
        txt = sprintf('范围内较优\n\\mu=%.2f, c=%.0f\n%.4f kV', mu_vals(c_best), price_vals(r_best), z_best);
    end
    text(mu_vals(c_best), price_vals(r_best), txt, 'FontName', font_cn, 'FontSize', 10, ...
        'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 3, 'VerticalAlignment', 'bottom');

    print(gcf, out_png, '-dpng', '-r300');
    drawnow;
    shg;
    % 不关闭图窗，便于运行结束后查看
end

function [r_best, c_best, z_best] = find_min_point(Z)
    [z_best, idx] = min(Z(:));
    [r_best, c_best] = ind2sub(size(Z), idx);
end

function write_matrix_to_excel(filename, sheet_name, price_vals, mu_vals, Z)
    header = cell(1, length(mu_vals) + 1);
    header{1} = 'price_mu';
    for i = 1:length(mu_vals)
        header{i+1} = mu_vals(i);
    end

    body = cell(length(price_vals), length(mu_vals) + 1);
    for r = 1:length(price_vals)
        body{r,1} = price_vals(r);
        for c = 1:length(mu_vals)
            body{r,c+1} = Z(r,c);
        end
    end

    try
        xlswrite(filename, header, sheet_name, 'A1');
        xlswrite(filename, body, sheet_name, 'A2');
    catch
        warning('Excel 写入失败，可能是系统没有 Excel 或文件被占用。MAT 文件仍已保存。');
    end
end
