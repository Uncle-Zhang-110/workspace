%% ???????????????????
% % ?????????????????
% % ?????????????rand/randn?
% % ??????????????
% % ??????

clc; clear; close all;

fprintf('========================================\n');
fprintf('  ?????\n');
fprintf('  ?????????????\n');
fprintf('========================================\n\n');

% ????
T = 24;
time_data = struct();
time_data.sys_load = 3000 * [0.45, 0.42, 0.40, 0.38, 0.40, 0.45, ...
    0.55, 0.70, 0.85, 0.90, 0.95, 0.98, ...
    0.95, 0.92, 0.88, 0.85, 0.80, 0.75, ...
    0.85, 0.95, 1.00, 0.95, 0.75, 0.60];
time_data.pv_output = 800 * [0, 0, 0, 0, 0, 0, 0.1, 0.3, 0.5, 0.7, 0.85, 0.95, ...
    1.0, 0.95, 0.8, 0.6, 0.3, 0.1, 0, 0, 0, 0, 0, 0];
time_data.wind_output = 600 * [0.6, 0.65, 0.7, 0.75, 0.7, 0.6, ...
    0.5, 0.4, 0.3, 0.25, 0.2, 0.15, ...
    0.2, 0.25, 0.3, 0.35, 0.45, 0.55, ...
    0.6, 0.65, 0.7, 0.65, 0.6, 0.55];
time_data.peak_flag = zeros(1, T);
time_data.valley_flag = zeros(1, T);
time_data.peak_flag(10:15) = 1;
time_data.peak_flag(18:22) = 1;
time_data.valley_flag(1:6) = 1;

% ????
test_prices = [0.05, 0.15, 0.30];

fprintf('????: ');
fprintf('%.2f ', test_prices);
fprintf('?/kWh\n\n');

% ?????
fprintf('???????\n');
results1 = zeros(length(test_prices), 3);  % [price, loss, volt_dev]
for i = 1:length(test_prices)
    cert_price = test_prices(i);
    
    % ?????????????
    base_cert_price = 0.15;
    price_factor = cert_price / base_cert_price;
    price_factor = min(max(price_factor, 0.3), 2.5);
    dr_intensity = 0.05 + 0.12 * (price_factor - 0.3) / 2.2;
    
    % ????
    sys_load = time_data.sys_load;
    peak_hours = find(time_data.peak_flag == 1);
    valley_hours = find(time_data.valley_flag == 1);
    for t = peak_hours
        sys_load(t) = sys_load(t) * (1 - dr_intensity * 0.60);
    end
    for t = valley_hours
        sys_load(t) = sys_load(t) * (1 + dr_intensity * 0.40);
    end
    
    % ?????
    load_normalized = sys_load / max(time_data.sys_load);
    load_variance = std(load_normalized) / mean(load_normalized);
    base_loss = sys_load * 0.048;
    loss_reduction = 0.15 + 0.08 * (1 - load_variance);
    actual_loss = base_loss * (1 - loss_reduction);
    
    base_voltage = 10.0 - (load_normalized - 0.5) * 1.15;
    voltage_improvement_base = 0.10 + 0.10 * (1 - load_variance);
    base_voltage_deviation = abs(base_voltage - 10.0);
    voltage_improvement = voltage_improvement_base * base_voltage_deviation;
    actual_voltage = base_voltage + voltage_improvement;
    actual_voltage = min(max(actual_voltage, 9.5), 10.5);
    voltage_dev = abs(actual_voltage - 10.0);
    
    results1(i, :) = [cert_price, mean(actual_loss), mean(voltage_dev)];
    fprintf('  ??%.2f: ??=%.4f kW, ????=%.6f kV\n', ...
            cert_price, mean(actual_loss), mean(voltage_dev));
end

% ?????
fprintf('\n???????\n');
results2 = zeros(length(test_prices), 3);
for i = 1:length(test_prices)
    cert_price = test_prices(i);
    
    base_cert_price = 0.15;
    price_factor = cert_price / base_cert_price;
    price_factor = min(max(price_factor, 0.3), 2.5);
    dr_intensity = 0.05 + 0.12 * (price_factor - 0.3) / 2.2;
    
    sys_load = time_data.sys_load;
    peak_hours = find(time_data.peak_flag == 1);
    valley_hours = find(time_data.valley_flag == 1);
    for t = peak_hours
        sys_load(t) = sys_load(t) * (1 - dr_intensity * 0.60);
    end
    for t = valley_hours
        sys_load(t) = sys_load(t) * (1 + dr_intensity * 0.40);
    end
    
    load_normalized = sys_load / max(time_data.sys_load);
    load_variance = std(load_normalized) / mean(load_normalized);
    base_loss = sys_load * 0.048;
    loss_reduction = 0.15 + 0.08 * (1 - load_variance);
    actual_loss = base_loss * (1 - loss_reduction);
    
    base_voltage = 10.0 - (load_normalized - 0.5) * 1.15;
    voltage_improvement_base = 0.10 + 0.10 * (1 - load_variance);
    base_voltage_deviation = abs(base_voltage - 10.0);
    voltage_improvement = voltage_improvement_base * base_voltage_deviation;
    actual_voltage = base_voltage + voltage_improvement;
    actual_voltage = min(max(actual_voltage, 9.5), 10.5);
    voltage_dev = abs(actual_voltage - 10.0);
    
    results2(i, :) = [cert_price, mean(actual_loss), mean(voltage_dev)];
    fprintf('  ??%.2f: ??=%.4f kW, ????=%.6f kV\n', ...
            cert_price, mean(actual_loss), mean(voltage_dev));
end

% ????
fprintf('\n========================================\n');
fprintf('??????\n');
fprintf('========================================\n\n');

diff_matrix = abs(results1 - results2);
max_diff = max(diff_matrix(:));

if max_diff < 1e-10
    fprintf('? ????????????????<1e-10?\n');
    fprintf('? ??100%%???\n');
    fprintf('? ???????\n');
    fprintf('\n? ?????????????\n');
else
    fprintf('??  ???????????\n');
    fprintf('??  ????: %.10f\n', max_diff);
    fprintf('??  ??????????\n');
end

fprintf('\n========================================\n');