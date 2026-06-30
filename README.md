# 主动配电网主从博弈仿真代码

本仓库用于保存论文“主动配电网中基于主从博弈的无功优化与绿证补偿激励机制”的 MATLAB 仿真代码。

## 环境要求

- MATLAB R2018a
- YALMIP
- CPLEX
- MATPOWER

## 主要运行入口

- `Green_cert_sensitivity_analysis_real.m`：图 10 绿证价格与无功补偿系数敏感性真实仿真。
- `Figure5_Real_IDR_Comparison.m`：IDR 前后负荷、网损和电压偏差对比。
- `Figure8_DeviceCoordination_Real.m`：设备级协调与无功支撑真实仿真。
- `reviewer2.1/generate_reviewer2_1_main_figure.m`：Reviewer 2.1 局部 Stackelberg 均衡验证正文主图。

运行前请在 MATLAB 中切换到本目录：

```matlab
cd('E:\1000块资料\主动配电网中基于主从博弈的无功优化与绿证补偿激励机制\实验2\workspace')
```

示例：

```matlab
Green_cert_sensitivity_analysis_real
```

## 版本管理说明

仓库优先保存可复现实验的源码、基础数据表和必要配置。生成的图片、日志、Word 原稿、MATLAB `.mat` 结果快照默认由 `.gitignore` 排除，避免仓库体积过大。
