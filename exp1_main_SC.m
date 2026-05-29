% exp1_main_SC.m
% 极化码 SC 译码基础仿真主脚本
clear; clc; close all;

% 1. 检查是否存在 data 文件夹，如果没有则自动创建
if ~exist('data', 'dir')
    mkdir('data');
end

% 2. 开启控制台日志，并使用 fullfile 将其放入 data 文件夹
% fullfile 的好处是会自动处理 Windows(\) 和 Linux(/) 的路径斜杠差异
log_file = fullfile('data', 'Exp1_Console_Log.txt');
diary(log_file); 
diary on;

addpath(genpath(pwd));

%% ==================== 仿真配置口 ====================
Ns = [256, 512];           % 仿真的码长集合 (可扩展1024)
R = 1/2;                   % 码率
EbN0_dBs = 0:0.5:3.0;      % 信噪比范围
% EbN0_dBs = 1.5:0.5:2.5;   % 初始测试用，后续不用

% 【算力调节区】: 如果跑得太慢，可以降低 max_frames 或调大 batch_size
max_frames = 100000;       % 每个信噪比点的最大仿真帧数
% max_frames = 2000;       % 初始测试用，后续不用
min_errors = 100;          % 提速核心：累计到多少个错误帧即刻跳出（早停）
batch_size = 2000;         % parfor 批处理大小 (利用你的14核)
%% ====================================================

% 数据记录矩阵
num_N = length(Ns);
num_SNR = length(EbN0_dBs);
BLER_results = zeros(num_N, num_SNR);
BER_results = zeros(num_N, num_SNR);
Time_results = zeros(num_N, num_SNR);

fprintf('--- 开始实验一: SC译码仿真 ---\n');
fprintf('CPU核心已准备，启动 parfor 加速...\n');

for n_idx = 1:num_N
    N = Ns(n_idx);
    K = N * R;
    
    % 1. 高斯近似(GA)构造极化码
    fprintf('\n正在构造码长 N=%d 的极化码 (设计 Eb/N0 = 2.5 dB)...\n', N);
    [info_bits_idx, frozen_bits_idx, ~] = construct_polar_GA(N, K, 2.5);
    
    % 准备冻结比特标志向量 (1表示冻结，0表示信息位)
    frozen_bits_flag = zeros(1, N);
    frozen_bits_flag(frozen_bits_idx) = 1;
    
    % 打印构造结果供实验报告使用
    fprintf('【要求核对项】 N=%d 信息位集合 (前10个): %s...\n', N, num2str(info_bits_idx(1:min(10,K))'));
    
    % 开始遍历信噪比
    for snr_idx = 1:num_SNR
        EbN0 = EbN0_dBs(snr_idx);
        
        total_errors = 0;
        total_bit_errors = 0;
        total_frames = 0;
        total_dec_time = 0;
        
        max_batches = ceil(max_frames / batch_size);
        
        % 外层用普通循环控制早停，内层用 parfor 并行加速
        for b = 1:max_batches
            current_batch_size = min(batch_size, max_frames - total_frames);
            
            % 临时变量供 parfor 使用
            batch_err_frames = 0;
            batch_err_bits = 0;
            batch_time = 0;
            
            parfor i = 1:current_batch_size
                % (1) 生成信源比特
                msg = randi([0, 1], 1, K);
                u = zeros(1, N);
                u(info_bits_idx) = msg; % 冻结位置保持为0
                
                % (2) 编码
                x = polar_encode(u);
                
                % (3) 调制与信道
                tx = bpsk_modulate(x);
                [rx, sigma] = add_awgn_noise(tx, EbN0, R);
                
                % (4) 接收端LLR计算
                % LLR = 2 * rx / sigma^2;
                llr = 2 * rx / (sigma^2);
                
                % (5) SC 译码并计时
                t_start = tic;
                u_hat = polar_decode_SC(llr, frozen_bits_flag);
                dec_t = toc(t_start);
                
                % (6) 误码统计与无损校验
                msg_hat = u_hat(info_bits_idx);
                
                % 记录本帧数据
                batch_time = batch_time + dec_t;
                bit_err = sum(msg ~= msg_hat);
                if bit_err > 0
                    batch_err_frames = batch_err_frames + 1;
                    batch_err_bits = batch_err_bits + bit_err;
                end
            end
            
            % 汇总本 Batch 数据
            total_frames = total_frames + current_batch_size;
            total_errors = total_errors + batch_err_frames;
            total_bit_errors = total_bit_errors + batch_err_bits;
            total_dec_time = total_dec_time + batch_time;
            
            % 满足早停条件则退出当前 SNR 的循环
            if total_errors >= min_errors
                break;
            end
        end
        
        % 计算评价指标
        BLER_results(n_idx, snr_idx) = total_errors / total_frames;
        BER_results(n_idx, snr_idx) = total_bit_errors / (total_frames * K);
        avg_time = (total_dec_time / total_frames) * 1000; % 转为毫秒
        Time_results(n_idx, snr_idx) = avg_time;
        
        fprintf('Eb/N0 = %4.1f dB | 发送帧数 = %6d | 误块数 = %4d | BLER = %1.2e | BER = %1.2e | 单帧耗时 = %.2f ms\n', ...
            EbN0, total_frames, total_errors, BLER_results(n_idx, snr_idx), BER_results(n_idx, snr_idx), avg_time);
    end
end

% 绘制结果
plot_result(EbN0_dBs, BLER_results, BER_results, Ns, R);
fprintf('\n仿真完成，已生成 BLER/BER 图表！\n');

% 将所有核心变量自动保存到 data 文件夹
data_file = fullfile('data', 'Exp1_SC_Results.mat');
save(data_file, 'BLER_results', 'BER_results', 'Time_results', 'EbN0_dBs', 'Ns', 'R');

% 将当前的图表导出为高质量无损的 SVG 格式
svg_file = fullfile('data', 'Exp1_SC_Curves.svg');
saveas(gcf, svg_file);

% 自动将当前绘制的图表保存为高清 PNG 图片放入 data 文件夹
fig_file = fullfile('data', 'Exp1_SC_Curves.png');
exportgraphics(gcf, fig_file, 'Resolution', 300); % 300 dpi 高清输出

diary off; % 最后关闭日志