% exp2_main_SCL.m
% 极化码 CA-SCL 译码仿真
clear; clc; close all;

% 1. 检查是否存在 data 文件夹，如果没有则自动创建
if ~exist('data', 'dir')
    mkdir('data');
end

% 2. 开启控制台日志，并使用 fullfile 将其放入 data 文件夹
% fullfile 的好处是会自动处理 Windows(\) 和 Linux(/) 的路径斜杠差异
log_file = fullfile('data', 'Exp2_Console_Log_NoCRC.txt');
diary(log_file); 
diary on;

addpath(genpath(pwd));

N = 512;                   % 固定码长
R = 1/2;                   % 码率
K = N * R;                 % 总信息位长度 (包含CRC)
crc_len = 8;               % CRC 长度
K_real = K - crc_len;      % 真实信息位长度

%% ==================== 测试配置 ====================
% EbN0_dBs = 1.5:0.5:2.5;    % 测试配置：选取几个有区分度的信噪比
% L_vec = [1, 2, 4];         % 测试配置：对比 L=1(SC), L=2, L=4
% use_crc = true;            % 开启 CA-SCL

% 【快速测试参数】正式实验时请调大 max_frames
% max_frames = 500;          
% min_errors = 30;          
% batch_size = 100;          
%% ====================================================

%% ==================== 正式配置 ====================
EbN0_dBs = 0.5:0.5:3.0;    % 拉宽信噪比范围，看完整的瀑布曲线
L_vec = [1, 2, 4, 8];      % 加入 L=8，观察性能是否饱和 (L=16暂时不加，防止太耗时)
% use_crc = true;            % 保持开启 CA-SCL
use_crc = false;            % 关掉 CA-SCL 跑第二轮

% 【正式实验参数】
max_frames = 50000;        % 提高最大帧数以获得可靠数据
min_errors = 100;          % 累计 100 错早停
batch_size = 500;          % 发挥 14 核 CPU 威力
%% ====================================================

num_SNR = length(EbN0_dBs);
num_L = length(L_vec);
BLER_results = zeros(num_L, num_SNR);
Time_results = zeros(num_L, 1); % 记录平均译码耗时

fprintf('--- 开始实验二: 纯SCL译码测试仿真 (No CRC) ---\n');
fprintf('正在构造码长 N=%d (无 CRC 辅助)...\n', N);
[info_bits_idx, frozen_bits_idx, ~] = construct_polar_GA(N, K, 2.5);

frozen_bits_flag = zeros(1, N);
frozen_bits_flag(frozen_bits_idx) = 1;

for l_idx = 1:num_L
    L = L_vec(l_idx);
    fprintf('\n>>> 开始仿真列表大小 L = %d (纯SCL) <<<\n', L);
    
    total_time_L = 0; 
    total_frames_L = 0;
    
    for snr_idx = 1:num_SNR
        EbN0 = EbN0_dBs(snr_idx);
        total_errors = 0;
        total_frames = 0;
        
        max_batches = ceil(max_frames / batch_size);
        
        for b = 1:max_batches
            current_batch_size = min(batch_size, max_frames - total_frames);
            batch_err_frames = 0;
            batch_time = 0;
            
            parfor i = 1:current_batch_size
                % (1) 生成真实信息比特
                msg_real = randi([0, 1], 1, K_real);
                
                % (2) 附加 CRC
                if use_crc
                    msg_with_crc = crc_generator(msg_real);
                else
                    msg_with_crc = [msg_real, zeros(1, crc_len)]; % 占位，确保长度同为 K
                end
                
                % (3) 映射到 Polar 序列 u
                u = zeros(1, N);
                u(info_bits_idx) = msg_with_crc;
                
                % (4) 编码与信道
                x = polar_encode(u);
                tx = bpsk_modulate(x);
                [rx, sigma] = add_awgn_noise(tx, EbN0, R);
                llr = 2 * rx / (sigma^2);
                
                % (5) CA-SCL 译码并计时
                t_start = tic;
                u_hat = polar_decode_SCL(llr, frozen_bits_flag, L, use_crc);
                dec_t = toc(t_start);
                batch_time = batch_time + dec_t;
                
                % (6) 误码统计与无损校验核心判断
                msg_hat_with_crc = u_hat(info_bits_idx);
                msg_hat_real = msg_hat_with_crc(1:K_real);
                
                % 【无损校验】：译码信息比特与发送信息比特逐位相等
                if isequal(msg_real, msg_hat_real)
                    % 校验成功：不增加错误数
                else
                    batch_err_frames = batch_err_frames + 1;
                end
            end
            
            total_frames = total_frames + current_batch_size;
            total_errors = total_errors + batch_err_frames;
            total_time_L = total_time_L + batch_time;
            total_frames_L = total_frames_L + current_batch_size;
            
            if total_errors >= min_errors
                break;
            end
        end
        
        BLER_results(l_idx, snr_idx) = total_errors / total_frames;
        
        % 确定当前信噪比点整轮仿真的无损校验状态
        total_correct = total_frames - total_errors;
        if total_correct + total_errors == total_frames
            chk_status = 'Success (Passed)';
        else
            chk_status = 'Failed';
        end
        
        fprintf('Eb/N0 = %4.1f dB | 总帧数 = %5d | 错帧 = %4d | BLER = %1.2e | 无损校验: %s\n', ...
            EbN0, total_frames, total_errors, BLER_results(l_idx, snr_idx), chk_status);
    end
    
    Time_results(l_idx) = (total_time_L / total_frames_L) * 1000; 
    fprintf('=> L=%d 单帧平均译码耗时: %.2f ms\n', L, Time_results(l_idx));
end

%% --- 绘制结果 ---
figure('Position', [100, 100, 800, 400]);

% 图1: BLER 曲线
subplot(1,2,1);
markers = {'bo-', 'rs-', 'g^-', 'md-', 'k*-'};
for i = 1:num_L
    semilogy(EbN0_dBs, BLER_results(i,:), markers{mod(i-1,5)+1}, 'LineWidth', 1.5, 'MarkerSize', 6);
    hold on;
end
grid on;
xlabel('E_b/N_0 (dB)');
ylabel('BLER');
title('SCL Decoding (N=512, R=1/2, No CRC)');
legend(strcat('L = ', string(L_vec)), 'Location', 'southwest');

% 图2: 译码时间柱状图
subplot(1,2,2);
bar(categorical(L_vec), Time_results, 'FaceColor', [0.2 0.6 0.8]);
grid on;
xlabel('List Size (L)');
ylabel('Average Time per Frame (ms)');
title('Decoding Time vs List Size');
for i = 1:num_L
    text(i, Time_results(i), sprintf('%.1f', Time_results(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

fprintf('\n实验二测试完毕！请检查曲线与时间数据。\n');

% 将所有核心变量自动保存到 data 文件夹
data_file = fullfile('data', 'Exp2_SCL_Results_NoCRC.mat');
save(data_file, 'BLER_results', 'Time_results', 'EbN0_dBs', 'L_vec', 'N', 'K');

% 将当前的图表导出为高质量无损的 SVG 格式
svg_file = fullfile('data', 'Exp2_SCL_Curves_NoCRC.svg');
saveas(gcf, svg_file);

% 自动将当前绘制的图表保存为高清 PNG 图片放入 data 文件夹
fig_file = fullfile('data', 'Exp2_SCL_Curves_NoCRC.png');
exportgraphics(gcf, fig_file, 'Resolution', 300); % 300 dpi 高清输出

diary off; % 最后关闭日志