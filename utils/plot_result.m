function plot_result(EbN0_dBs, BLER_results, BER_results, Ns, R)
    % 绘制 BLER
    figure('Position', [100, 100, 800, 500]);
    
    subplot(1,2,1);
    markers = {'bo-', 'rs-', 'g^-', 'md-'};
    for i = 1:length(Ns)
        semilogy(EbN0_dBs, BLER_results(i,:), markers{mod(i-1,4)+1}, 'LineWidth', 1.5, 'MarkerSize', 6);
        hold on;
    end
    
    % 添加 BPSK R=1/2 的香农限参考线 (约为 0.187 dB)
    if R == 0.5
        xline(0.187, 'k--', 'BPSK Shannon Limit', 'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
    end
    
    grid on;
    xlabel('E_b/N_0 (dB)');
    ylabel('BLER');
    title('Polar SC Decoding BLER');
    legend(strcat('N = ', string(Ns)), 'Location', 'southwest');
    
    % 绘制 BER
    subplot(1,2,2);
    for i = 1:length(Ns)
        semilogy(EbN0_dBs, BER_results(i,:), markers{mod(i-1,4)+1}, 'LineWidth', 1.5, 'MarkerSize', 6);
        hold on;
    end
    if R == 0.5
        xline(0.187, 'k--', 'LineWidth', 1.5);
    end
    grid on;
    xlabel('E_b/N_0 (dB)');
    ylabel('BER');
    title('Polar SC Decoding BER');
    legend(strcat('N = ', string(Ns)), 'Location', 'southwest');
end