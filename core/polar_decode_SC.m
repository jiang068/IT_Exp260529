function u_hat = polar_decode_SC(llr, frozen_bits_flag)
    % 输入 llr: 接收端的初始LLR序列
    % 输入 frozen_bits_flag: 长度为N的向量，1代表冻结位，0代表信息位
    N = length(llr);
    [u_hat, ~] = decode_node(llr, frozen_bits_flag, 1, N);
end

function [u_hat, beta] = decode_node(llr, frozen_bits_flag, node_start, node_end)
    N = node_end - node_start + 1;
    
    % 叶子节点判决
    if N == 1
        if frozen_bits_flag(node_start) == 1
            u_hat = 0; % 冻结位直接判0
        else
            u_hat = llr < 0; % LLR < 0 判决为 1
        end
        beta = u_hat;
        return;
    end
    
    half = N / 2;
    llr_a = llr(1:half);
    llr_b = llr(half+1:end);
    
    % --- 左节点 (f 运算) ---
    % f(La, Lb) ≈ sign(La) * sign(Lb) * min(|La|, |Lb|)
    llr_L = sign(llr_a) .* sign(llr_b) .* min(abs(llr_a), abs(llr_b));
    [u_hat_L, beta_L] = decode_node(llr_L, frozen_bits_flag, node_start, node_start + half - 1);
    
    % --- 右节点 (g 运算) ---
    % g(La, Lb, u_hat) = (1 - 2*u_hat)*La + Lb
    llr_R = llr_b + (1 - 2*beta_L) .* llr_a;
    [u_hat_R, beta_R] = decode_node(llr_R, frozen_bits_flag, node_start + half, node_end);
    
    % 返回组合结果
    u_hat = [u_hat_L, u_hat_R];
    beta = [mod(beta_L + beta_R, 2), beta_R];
end