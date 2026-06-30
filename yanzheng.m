%% 1. 加载标准 IEEE 33 节点数据
mpc = loadcase('case33bw'); 

%% 2. 设置 14:00 的负荷 (Scaling)
Target_P_Load = 1.25; 
Base_Total_P = sum(mpc.bus(:, 3)); 
Scale_Factor = Target_P_Load / Base_Total_P;

mpc.bus(:, 3) = mpc.bus(:, 3) * Scale_Factor; 
mpc.bus(:, 4) = mpc.bus(:, 4) * Scale_Factor; 

%% 3. 设置 14:00 的发电机和无功补偿 (符合你真实的 SVG@10, OLTC@33 设定)

% Node 10: SVG (提供全局中段无功支撑)
% 假设 SVG 提供 0.5 MVAr 的无功支撑
mpc.bus(10, 4) = mpc.bus(10, 4) - 0.50; 

% Node 20: PV + CB 
% PV有功 0.45 MW，总无功限制在合理的 0.55 MVAr
mpc.bus(20, 3) = mpc.bus(20, 3) - 0.45; 
mpc.bus(20, 4) = mpc.bus(20, 4) - 0.55; 

% Node 33: Wind + REC (末端风电)
% 风电有功 0.15 MW，整流器提供适当无功 0.16 MVAr
mpc.bus(33, 3) = mpc.bus(33, 3) - 0.15; 
mpc.bus(33, 4) = mpc.bus(33, 4) - 0.16; 

%% 4. 设置 OLTC (安装在节点 32-33 之间，专为 33 节点升压)
% IEEE33 中连接节点 32 和 33 的支路索引通常是 32
OLTC_Branch_ID = 32; 
% 为了抵消末端压降，让 OLTC 升压 1.05 倍 (MATPOWER 变比设为倒数)
mpc.branch(OLTC_Branch_ID, 9) = 1 / 1.05; 

%% 5. 运行潮流
opt = mpoption('out.all', 0, 'verbose', 0); 
results = runpf(mpc, opt);

%% 6. 输出结果用于填表
fprintf('\n======================================================\n');
fprintf('14:00 时刻 AC 潮流验证 (SVG@10, OLTC@33 真实设定):\n');
[max_v, max_idx] = max(results.bus(:, 8));
[min_v, min_idx] = min(results.bus(:, 8));
fprintf('最高节点电压: %.4f p.u. (Node %d)\n', max_v, max_idx);
fprintf('最低节点电压: %.4f p.u. (Node %d)\n', min_v, min_idx);
fprintf('系统总网损: %.4f kW\n', sum(real(get_losses(results))) * 1000);
fprintf('======================================================\n');