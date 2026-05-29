% exp3_main_BP.m
% 极化码 BP 译码仿真及多算法性能对比
clear; clc; close all;

if ~exist('data', 'dir')
    mkdir('data');
end

log_file = fullfile('data', 'Exp3_Console_Log.txt');
diary(log_file); 
diary on;
addpath(genpath(pwd)); 

%% ==================== 仿真配置 ====================
Ns = [256, 512];           % 码长测试
R = 1/2;                   % 码率
EbN0_dBs = 1.0:0.5:3.5;    % 信噪比范围 (BP在低信噪比下不易收敛，适当上移起始点)
max_iter = 50;             % BP 最大迭代次数

max_frames = 20000;        % 最大帧数
min_errors = 100;          % 累计错帧早停
batch_size = 500;          % parfor 批处理大小 (发挥 14 核算力)
%% ====================================================

num_N = length(Ns);
num_SNR = length(EbN0_dBs);
BLER_BP = zeros(num_N, num_SNR);
BER_BP = zeros(num_N, num_SNR);
Iter_BP = zeros(num_N, num_SNR);  % 记录平均迭代次数
Time_BP = zeros(num_N, num_SNR);  % 记录平均耗时

fprintf('--- 开始实验三: BP 译码仿真 ---\n');

for n_idx = 1:num_N
    N = Ns(n_idx);
    K = N * R;
    fprintf('\n>>> 正在仿真 BP 译码 码长 N=%d (最大迭代=%d) <<<\n', N, max_iter);
    
    [info_bits_idx, frozen_bits_idx, ~] = construct_polar_GA(N, K, 2.5);
    frozen_bits_flag = zeros(1, N);
    frozen_bits_flag(frozen_bits_idx) = 1;
    
    for snr_idx = 1:num_SNR
        EbN0 = EbN0_dBs(snr_idx);
        total_errors = 0;
        total_bit_errors = 0;
        total_frames = 0;
        total_iters = 0;
        total_time = 0;
        
        max_batches = ceil(max_frames / batch_size);
        
        for b = 1:max_batches
            current_batch_size = min(batch_size, max_frames - total_frames);
            batch_err_frames = 0;
            batch_err_bits = 0;
            batch_iters = 0;
            batch_time = 0;
            
            parfor i = 1:current_batch_size
                msg = randi([0, 1], 1, K);
                u = zeros(1, N);
                u(info_bits_idx) = msg;
                
                x = polar_encode(u);
                tx = bpsk_modulate(x);
                [rx, sigma] = add_awgn_noise(tx, EbN0, R);
                llr = 2 * rx / (sigma^2);
                
                % BP 译码并计时
                t_start = tic;
                [u_hat, act_iter] = polar_decode_BP(llr', frozen_bits_flag', max_iter);
                dec_t = toc(t_start);
                
                batch_time = batch_time + dec_t;
                batch_iters = batch_iters + act_iter;
                
                % 误码统计与无损校验
                msg_hat = u_hat(info_bits_idx);
                if isequal(msg, msg_hat)
                    % 无损校验通过
                else
                    batch_err_frames = batch_err_frames + 1;
                    batch_err_bits = batch_err_bits + sum(msg ~= msg_hat);
                end
            end
            
            total_frames = total_frames + current_batch_size;
            total_errors = total_errors + batch_err_frames;
            total_bit_errors = total_bit_errors + batch_err_bits;
            total_iters = total_iters + batch_iters;
            total_time = total_time + batch_time;
            
            if total_errors >= min_errors
                break;
            end
        end
        
        BLER_BP(n_idx, snr_idx) = total_errors / total_frames;
        BER_BP(n_idx, snr_idx) = total_bit_errors / (total_frames * K);
        Iter_BP(n_idx, snr_idx) = total_iters / total_frames;
        Time_BP(n_idx, snr_idx) = (total_time / total_frames) * 1000;
        
        total_correct = total_frames - total_errors;
        chk_status = 'Failed';
        if total_correct + total_errors == total_frames
            chk_status = 'Success (Passed)';
        end
        
        fprintf('Eb/N0=%4.1fdB | 帧数=%5d | 错帧=%4d | BLER=%1.2e | 均代=%.1f | 均时=%4.1fms | %s\n', ...
            EbN0, total_frames, total_errors, BLER_BP(n_idx, snr_idx), Iter_BP(n_idx, snr_idx), Time_BP(n_idx, snr_idx), chk_status);
    end
end

% 保存 BP 数据
data_file = fullfile('data', 'Exp3_BP_Results.mat');
save(data_file, 'BLER_BP', 'BER_BP', 'Iter_BP', 'Time_BP', 'EbN0_dBs', 'Ns');

%% --- 绘制综合对比大图 ---
fprintf('\n仿真完成，开始读取 Exp1 和 Exp2 数据进行综合画图...\n');

figure('Position', [100, 100, 1200, 450]);

% 子图1：BLER 综合对比 (固定 N=512)
subplot(1,3,1);
% 画 BP 的线
semilogy(EbN0_dBs, BLER_BP(2,:), 'm>-', 'LineWidth', 1.5, 'MarkerSize', 6); hold on;

% 尝试加载 SC 和 SCL 数据进行对比
leg_str = {'BP (N=512)'};
if exist(fullfile('data', 'Exp1_SC_Results.mat'), 'file')
    sc_data = load(fullfile('data', 'Exp1_SC_Results.mat'));
    % SC 数据中 N=512 是第二行
    semilogy(sc_data.EbN0_dBs, sc_data.BLER_results(2,:), 'k.-', 'LineWidth', 1.5, 'MarkerSize', 6);
    leg_str{end+1} = 'SC (N=512)';
end
if exist(fullfile('data', 'Exp2_SCL_Results.mat'), 'file')
    scl_data = load(fullfile('data', 'Exp2_SCL_Results.mat'));
    % 画 CA-SCL L=4 的线 (通常是第3行)
    semilogy(scl_data.EbN0_dBs, scl_data.BLER_results(3,:), 'b^-', 'LineWidth', 1.5, 'MarkerSize', 6);
    leg_str{end+1} = 'CA-SCL L=4 (N=512)';
end

grid on; xlabel('E_b/N_0 (dB)'); ylabel('BLER');
title('Performance Comparison (N=512)');
legend(leg_str, 'Location', 'southwest');

% 子图2：BP 码长性能对比
subplot(1,3,2);
semilogy(EbN0_dBs, BLER_BP(1,:), 'rO-', 'LineWidth', 1.5); hold on;
semilogy(EbN0_dBs, BLER_BP(2,:), 'bS-', 'LineWidth', 1.5);
grid on; xlabel('E_b/N_0 (dB)'); ylabel('BLER');
title('BP Decoding BLER');
legend('BP (N=256)', 'BP (N=512)', 'Location', 'southwest');

% 子图3：BP 早停迭代次数收敛图
subplot(1,3,3);
plot(EbN0_dBs, Iter_BP(1,:), 'rO-', 'LineWidth', 1.5); hold on;
plot(EbN0_dBs, Iter_BP(2,:), 'bS-', 'LineWidth', 1.5);
grid on; xlabel('E_b/N_0 (dB)'); ylabel('Average Iterations');
title('BP Convergence (Max Iter=50)');
legend('N=256', 'N=512');

% 导出图片
exportgraphics(gcf, fullfile('data', 'Exp3_Comparison_Curves.png'), 'Resolution', 300);
saveas(gcf, fullfile('data', 'Exp3_Comparison_Curves.svg'));
diary off;
disp('所有图片已保存至 data 文件夹！');