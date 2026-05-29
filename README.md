# 信息论实验：极化码编译码仿真与性能分析

## 项目结构

```
IT_Exp260529/
│
├── core/                          % 核心算法层
│   ├── construct_polar_GA.m       % 高斯近似（GA）极化码构造
│   ├── polar_encode.m             % 极化码编码
│   ├── polar_decode_SC.m          % SC 译码器
│   ├── polar_decode_SCL.m         % SCL / CA-SCL 译码器
│   └── polar_decode_BP.m          % BP 译码器（Min-Sum，含早停）
│
├── channel/                       % 信道与调制
│   ├── bpsk_modulate.m            % BPSK 调制 (0 → +1, 1 → −1)
│   └── add_awgn_noise.m           % AWGN 噪声叠加
│
├── utils/                         % 工具与辅助函数
│   ├── crc_generator.m            % CRC-8 编码 (x⁸ + x² + x + 1)
│   ├── crc_detector.m             % CRC-8 校验
│   └── plot_result.m              % SC 译码结果画图（实验一用）
│
├── exp1_main_SC.m                 % 实验一：SC 译码基础仿真
├── exp2_main_SCL.m                % 实验二：CA-SCL 译码仿真
├── exp2_main_SCL_NoCRC.m          % 实验二补充：纯 SCL 译码仿真（无 CRC）
├── exp3_main_BP.m                 % 实验三：BP 译码仿真 + 多算法对比
├── plot_SCL_compare.m             % 辅助：画 CA-SCL vs 纯 SCL 对比图
│
├── data/                          % 仿真输出（自动生成）
│   ├── Exp1_SC_Results.mat        % 实验一数据
│   ├── Exp1_SC_Curves.png/.svg    % 实验一图表
│   ├── Exp2_SCL_Results.mat       % 实验二 CA-SCL 数据
│   ├── Exp2_SCL_Curves.png/.svg   % 实验二 CA-SCL 图表
│   ├── Exp2_SCL_Results_NoCRC.mat % 实验二纯 SCL 数据
│   ├── Exp2_SCL_Curves_NoCRC.png/.svg
│   ├── Exp3_BP_Results.mat        % 实验三数据
│   ├── Exp3_Comparison_Curves.png/.svg
│   └── Exp*_Console_Log.txt       % 各次仿真控制台日志
└── README.md                      % 本文件
```

## 环境配置

| 项目 | 说明 |
|------|------|
| 操作系统 | Windows 11 |
| MATLAB | R2024a（需 Parallel Computing Toolbox 以使用 `parfor`） |
| 硬件 | Intel i9-13900H（14 核 20 线程） |
| LaTeX 编译 | 本地 XeLaTeX / MiKTeX，或在线 [ustclatex](https://latex.ustc.edu.cn/) |

## 如何运行实验

### 前置步骤

在项目根目录打开 MATLAB，确保所有子文件夹在搜索路径中——脚本会自动执行 `addpath(genpath(pwd))`。

### 实验一：SC 译码基础仿真

```matlab
exp1_main_SC
```

- 码长 $N = 256, 512$，码率 $R = 1/2$
- 信噪比范围 $0.0 \sim 3.0 \text{ dB}$，步长 $0.5 \text{ dB}$
- 每点最多 100 000 帧，累积 100 个错误帧提前停止（早停）
- 输出 `data/Exp1_SC_Results.mat`、`Exp1_SC_Curves.png/.svg`、`Exp1_Console_Log.txt`

### 实验二：SCL / CA-SCL 译码仿真

```matlab
exp2_main_SCL         % CA-SCL（8 位 CRC 辅助）
exp2_main_SCL_NoCRC   % 纯 SCL（无 CRC）
```

- 固定 $N = 512, R = 1/2$
- 列表大小 $L = 1, 2, 4, 8$
- 每点最多 50 000 帧，100 错误早停
- 输出 `data/Exp2_SCL_Results.mat` 和 `Exp2_SCL_Results_NoCRC.mat`

### 实验三：BP 译码仿真 + 多算法对比

```matlab
exp3_main_BP
```

- $N = 256, 512$，最大迭代 50 次（含早停机制）
- 自动加载实验一/二数据，画综合对比图
- 输出 `data/Exp3_BP_Results.mat`、`Exp3_Comparison_Curves.png/.svg`

### 辅助：画 CRC vs 无 CRC 对比图

```matlab
plot_SCL_compare
```

生成 `data/Exp2_SCL_Compare.png`，在同一张图上对比 CA-SCL 和纯 SCL 的 BLER。

> **注意**：实验二的两个脚本需要**分别运行**，因为 CA-SCL 和纯 SCL 分别保存到两个不同的 `.mat` 文件。`plot_SCL_compare` 需要这两个 `.mat` 都存在才能运行。

## 如何用数据写报告

1. **数据文件**都在 `data/` 下。双击 `.mat` 文件即可在 MATLAB 工作区加载，查看 `BLER_results`、`BER_results` 等变量。
2. **控制台日志**（`*_Console_Log.txt`）记录了每次仿真的帧数、错帧数、BLER、单帧耗时、无损校验状态，可直接复制到报告中制表。
3. **图片**为 300 dpi 高清 PNG，适合直接插入 Word/LaTeX 报告。SVG 矢量格式适合论文排版。
4. 报告：Markdown 版适合快速浏览，LaTeX 版适合正式排版。将 `.tex` 文件和 `data/` 下的图片一起上传到 [ustclatex](https://latex.ustc.edu.cn/) 即可在线编译 PDF。

## 仿真参数速查

| 参数 | 取值 |
|------|------|
| 码率 $R$ | $1/2$ |
| 构造信噪比 | $E_b/N_0 = 2.5\text{ dB}$ |
| 调制 / 信道 | BPSK + AWGN |
| CRC 多项式 | $x^8 + x^2 + x + 1$（8 位） |
| 早停阈值 | 100 个错误帧 |
| 并行批次大小 | batch_size = 500（SCL）/ 2000（SC）/ 500（BP） |

## 生成式 AI 使用披露

本项目（代码、报告）的编写使用了以下 AI 辅助工具：

| 工具 | 用途 |
|------|------|
| **Gemini 3.1 Pro** | 初步生成核心算法代码（`core/`、`channel/`、`utils/`）以及实验主脚本框架 |
| **DeepSeek V4 Pro** | 代码润色、bug 修复、性能优化 |
| **Claude Code CLI** | 实验报告撰写（LaTeX 格式排版、内容润色）、README 编写、辅助调试 |
| **VS Code** + **Claude Code CLI** | 集成开发环境与 AI 编程助手 |

所有代码和报告内容均经过人工审核、验证和修改。仿真数据由 MATLAB R2024a 实际运行产生，非 AI 虚构。
