function [u_hat, iter] = polar_decode_BP(llr, frozen_bits_flag, max_iter)
    % 输入:
    % llr - 接收端的通道 LLR (N x 1)
    % frozen_bits_flag - 冻结位标识 (N x 1)，1表示冻结，0表示信息位
    % max_iter - 最大迭代次数 (通常取 50)
    % 输出:
    % u_hat - 译码出的比特序列 (1 x N)
    % iter - 触发早停时的实际迭代次数

    N = length(llr);
    n = log2(N);
    
    % Min-Sum 算法的修正因子 (工业界常用经验值)
    alpha = 0.9375;
    
    % 初始化 L 矩阵(向左传递) 和 R 矩阵(向右传递)，尺寸为 N x (n+1)
    L = zeros(N, n+1);
    R = zeros(N, n+1);
    
    % --- 初始化边界条件 ---
    % 1. L 矩阵的最右侧 (第 n+1 列) 接入信道接收到的 LLR
    L(:, n+1) = llr(:);
    
    % 2. R 矩阵的最左侧 (第 1 列) 接入先验信息
    % 冻结位确信为 0，先验 LLR 设为正无穷大 (用 1e4 代替)；信息位未知，设为 0
    R(frozen_bits_flag == 1, 1) = 1e4;
    R(frozen_bits_flag == 0, 1) = 0;
    
    % 预计算每一层的交叉索引 (Top 和 Bottom) 以避免在循环内重复计算
    idx_T = zeros(N/2, n);
    idx_B = zeros(N/2, n);
    for stage = 1:n
        step = 2^(stage-1);
        idx = 1;
        for i = 1 : 2*step : N
            idx_T(idx : idx+step-1, stage) = i : i+step-1;
            idx_B(idx : idx+step-1, stage) = i+step : i+2*step-1;
            idx = idx + step;
        end
    end
    
    % === 迭代解码开始 ===
    for iter = 1:max_iter
        
        % 1. 向左传播 (Right-to-Left pass)，更新 L 矩阵
        for stage = n:-1:1
            t = idx_T(:, stage);
            b = idx_B(:, stage);
            
            % 读取输入消息
            L_in_T = L(t, stage+1);
            L_in_B = L(b, stage+1);
            R_in_T = R(t, stage);
            R_in_B = R(b, stage);
            
            % PE 节点更新公式 (Min-Sum)
            L(t, stage) = min_sum(R_in_B + L_in_B, L_in_T, alpha);
            L(b, stage) = min_sum(R_in_T, L_in_T, alpha) + L_in_B;
        end
        
        % 2. 向右传播 (Left-to-Right pass)，更新 R 矩阵
        for stage = 1:n
            t = idx_T(:, stage);
            b = idx_B(:, stage);
            
            % 读取输入消息
            L_in_T = L(t, stage+1);
            L_in_B = L(b, stage+1);
            R_in_T = R(t, stage);
            R_in_B = R(b, stage);
            
            % PE 节点更新公式 (Min-Sum)
            R(t, stage+1) = min_sum(R_in_B + L_in_B, R_in_T, alpha);
            R(b, stage+1) = min_sum(R_in_T, L_in_T, alpha) + R_in_B;
        end
        
        % 3. 早停机制 (Early Stopping Check)
        % 提取最左侧软信息并硬判决
        u_LLR = L(:, 1) + R(:, 1);
        u_hat_temp = (u_LLR < 0)';
        u_hat_temp(frozen_bits_flag == 1) = 0; % 强制冻结位为 0
        
        % 提取最右侧软信息并硬判决
        x_LLR = L(:, n+1) + R(:, n+1);
        x_hat_temp = (x_LLR < 0)';
        
        % 将判决出的 u_hat 进行极化码编码
        x_encoded = polar_encode(u_hat_temp);
        
        % 检查 u_hat 编码后是否与当前因子图收敛的 x_hat 一致
        if isequal(x_encoded, x_hat_temp)
            break; % 如果一致，说明已收敛到一个合法码字，立即终止迭代
        end
    end
    
    % 输出最终判决
    u_LLR = L(:, 1) + R(:, 1);
    u_hat = (u_LLR < 0)';
    u_hat(frozen_bits_flag == 1) = 0;
end

% 内部辅助函数：衰减最小和近似
function out = min_sum(x, y, alpha)
    out = alpha .* sign(x) .* sign(y) .* min(abs(x), abs(y));
end