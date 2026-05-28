项目结构构思：
```
IT_Exp260529/
│
├── core/                      % 核心算法层 (类似 Python 的 core 模块)
│   ├── construct_polar_GA.m   % GA 极化码构造函数
│   ├── polar_encode.m         % 极化码编码函数
│   ├── polar_decode_SC.m      % SC 译码器
│   └── polar_decode_SCL.m     % SCL 译码器
│
├── channel/                   % 信道与调制
│   ├── bpsk_modulate.m        % BPSK 调制 (0->1, 1->-1)
│   └── add_awgn_noise.m       % 添加高斯白噪声
│
├── utils/                     % 工具与辅助函数
│   ├── check_crc.m            % CRC 校验提取 (实验二用)
│   └── plot_result.m          % 统一个画图函数
│
├── exp1_main_SC.m             % 实验一的主程序 (类似 main.py)
└── exp2_main_SCL.m            % 实验二的主程序
```

环境：
windows + Matlab 2024a

硬件条件：
i9-13900H
