function [rx, sigma] = add_awgn_noise(tx, EbN0_dB, R)
    % R 为码率
    sigma = 1 / sqrt(2 * R * 10^(EbN0_dB / 10));
    rx = tx + sigma * randn(size(tx));
end