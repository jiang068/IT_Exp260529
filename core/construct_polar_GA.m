function [info_bits_idx, frozen_bits_idx, LLR_means] = construct_polar_GA(N, K, EbN0_dB)
    % N: 码长, K: 信息位长度, EbN0_dB: 构造信噪比
    R = K / N;
    sigma = 1 / sqrt(2 * R * 10^(EbN0_dB / 10));
    m0 = 2 / (sigma^2);
    
    m = zeros(N, 1);
    m(1) = m0;
    
    % GA 递归更新公式
    n = log2(N);
    for stage = 1:n
        step = 2^(stage-1);
        m_new = zeros(2*step, 1);
        for i = 1:step
            m_new(2*i - 1) = phi_inv(1 - (1 - phi(m(i)))^2);
            m_new(2*i)     = 2 * m(i);
        end
        m(1:2*step) = m_new;
    end
    
    LLR_means = m;
    
    % 可靠度从大到小排序，选取前K个作为信息位
    [~, sorted_idx] = sort(LLR_means, 'descend');
    info_bits_idx = sort(sorted_idx(1:K));
    frozen_bits_idx = sort(sorted_idx(K+1:N));
end

% 实验手册提供的 phi(x) 近似公式
function y = phi(x)
    y = zeros(size(x));
    idx1 = (x > 0 & x < 10);
    idx2 = (x >= 10);
    
    y(idx1) = exp(-0.4527 .* x(idx1).^0.86 + 0.0218);
    y(idx2) = sqrt(pi ./ x(idx2)) .* exp(-x(idx2)/4) .* (1 - 10 ./ (7 .* x(idx2)));
    y(x <= 0) = 1; 
end

% 利用二分法求解 phi(x) 的反函数
function x = phi_inv(y)
    x = zeros(size(y));
    for i = 1:length(y)
        if y(i) >= 1
            x(i) = 0;
        elseif y(i) <= 0
            x(i) = 100; % 设一个截断上限
        else
            low = 0; high = 100;
            while high - low > 1e-4
                mid = (low + high) / 2;
                % phi(x)是单调递减函数
                if phi(mid) < y(i)
                    high = mid; 
                else
                    low = mid;
                end
            end
            x(i) = (low + high) / 2;
        end
    end
end