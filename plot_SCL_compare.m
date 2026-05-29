% plot_SCL_compare.m
% 画 CA-SCL vs 纯 SCL 直接对比图（同一 SNR 下，L=4 / L=8 两条对比线）
% 运行前确保 data/ 下有 Exp2_SCL_Results.mat (CA-SCL) 和 Exp2_SCL_Results_NoCRC.mat (纯 SCL)

clear; clc; close all;

scl_ca   = load(fullfile('data', 'Exp2_SCL_Results.mat'));        % CA-SCL
scl_nocrc = load(fullfile('data', 'Exp2_SCL_Results_NoCRC.mat')); % 纯 SCL

EbN0 = scl_ca.EbN0_dBs;  % 0.5:0.5:3.0

figure('Position', [100, 100, 1000, 750]);

% ===== 左图：L=4 对比 =====
subplot(2,2,1);
semilogy(EbN0, scl_ca.BLER_results(3,:), 'b^-', 'LineWidth', 1.5, 'MarkerSize', 7); hold on;
semilogy(EbN0, scl_nocrc.BLER_results(3,:), 'rs-', 'LineWidth', 1.5, 'MarkerSize', 7);
grid on; xlabel('E_b/N_0 (dB)'); ylabel('BLER');
title('L = 4: CA-SCL vs 纯 SCL (N=512)');
legend('CA-SCL (8-bit CRC)', '纯 SCL (No CRC)', 'Location', 'southwest');
set(gca, 'YScale', 'log');

% ===== 右图：L=8 对比 =====
subplot(2,2,2);
semilogy(EbN0, scl_ca.BLER_results(4,:), 'b^-', 'LineWidth', 1.5, 'MarkerSize', 7); hold on;
semilogy(EbN0, scl_nocrc.BLER_results(4,:), 'rs-', 'LineWidth', 1.5, 'MarkerSize', 7);
grid on; xlabel('E_b/N_0 (dB)'); ylabel('BLER');
title('L = 8: CA-SCL vs 纯 SCL (N=512)');
legend('CA-SCL (8-bit CRC)', '纯 SCL (No CRC)', 'Location', 'southwest');
set(gca, 'YScale', 'log');

% ===== 下半幅：四线总览（L=4 CA, L=4 纯, L=8 CA, L=8 纯）=====
subplot(2,2,[3 4]);
semilogy(EbN0, scl_ca.BLER_results(3,:),     'b^-', 'LineWidth', 1.5, 'MarkerSize', 7); hold on;
semilogy(EbN0, scl_nocrc.BLER_results(3,:),   'b^--','LineWidth', 1.5, 'MarkerSize', 7);
semilogy(EbN0, scl_ca.BLER_results(4,:),     'rs-', 'LineWidth', 1.5, 'MarkerSize', 7);
semilogy(EbN0, scl_nocrc.BLER_results(4,:),   'rs--','LineWidth', 1.5, 'MarkerSize', 7);
grid on; xlabel('E_b/N_0 (dB)'); ylabel('BLER');
title('CA-SCL vs 纯 SCL 全览 (N=512)');
legend('L=4 CA-SCL', 'L=4 纯 SCL', 'L=8 CA-SCL', 'L=8 纯 SCL', 'Location', 'southwest');
set(gca, 'YScale', 'log');

% 保存图片
saveas(gcf, fullfile('data', 'Exp2_SCL_Compare.png'));
exportgraphics(gcf, fullfile('data', 'Exp2_SCL_Compare.png'), 'Resolution', 300);
fprintf('图片已保存至 data/Exp2_SCL_Compare.png\n');
