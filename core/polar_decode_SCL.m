function u_hat = polar_decode_SCL(llr, frozen_bits_flag, L, use_crc)
    % llr: 接收端LLR
    % frozen_bits_flag: 冻结位标识
    % L: 列表大小
    % use_crc: 是否启用 CRC 辅助
    
    N = length(llr);
    n = log2(N);
    
    % --- 初始化第一条路径 ---
    % P 矩阵存储各层的 LLR
    paths(1).P = zeros(n+1, N);
    % C 矩阵存储各层的部分和 (比特)
    paths(1).C = zeros(n+1, N);
    
    paths(1).P(1, :) = llr;
    paths(1).u_hat = zeros(1, N);
    paths(1).PM = 0;
    active_paths = 1;
    
    % 串行遍历每一个叶子节点
    for phi = 1:N
        % 1. LLR 向下传播 (从根节点到叶子节点)
        if phi == 1
            start_layer = 1;
        else
            diff = bitxor(phi-1, phi-2);
            start_layer = n - floor(log2(diff));
        end
        
        bin_phi = dec2bin(phi-1, n) - '0'; % 二进制路径指引
        
        for l = 1:active_paths
            for layer = start_layer:n
                step = 2^(n - layer);
                % 计算当前节点在 P 矩阵中的索引范围
                node_idx = floor((phi-1) / (2*step));
                idx_start = node_idx * (2*step) + 1;
                idx_mid = idx_start + step - 1;
                idx_end = idx_start + 2*step - 1;
                
                llr_a = paths(l).P(layer, idx_start:idx_mid);
                llr_b = paths(l).P(layer, idx_mid+1:idx_end);
                
                if bin_phi(layer) == 0
                    % 左分支：执行 f 运算
                    paths(l).P(layer+1, idx_start:idx_mid) = ...
                        sign(llr_a) .* sign(llr_b) .* min(abs(llr_a), abs(llr_b));
                else
                    % 右分支：执行 g 运算
                    % 从 C 矩阵中提取左分支已经算好的部分和
                    beta_L = paths(l).C(layer+1, idx_start:idx_mid);
                    paths(l).P(layer+1, idx_mid+1:idx_end) = ...
                        llr_b + (1 - 2*beta_L) .* llr_a;
                end
            end
        end
        
        % 获取当前所有活跃路径到达叶子节点 (第 n+1 层) 的 LLR
        current_llrs = zeros(1, active_paths);
        for l = 1:active_paths
            current_llrs(l) = paths(l).P(n+1, phi);
        end
        
        % 2. 节点判决与路径分裂
        if frozen_bits_flag(phi) == 1
            % 冻结位：不分裂，直接判 0
            for l = 1:active_paths
                paths(l).u_hat(phi) = 0;
                paths(l).C(n+1, phi) = 0; % 存入叶子节点 C 矩阵
                if current_llrs(l) < 0
                    paths(l).PM = paths(l).PM + abs(current_llrs(l));
                end
            end
        else
            % 信息位：分裂成 0 和 1
            new_active = active_paths * 2;
            new_paths = repmat(paths(1), 1, new_active);
            
            for l = 1:active_paths
                % 分支 0
                new_paths(2*l - 1) = paths(l);
                new_paths(2*l - 1).u_hat(phi) = 0;
                new_paths(2*l - 1).C(n+1, phi) = 0;
                if current_llrs(l) < 0
                    new_paths(2*l - 1).PM = new_paths(2*l - 1).PM + abs(current_llrs(l));
                end
                
                % 分支 1
                new_paths(2*l) = paths(l);
                new_paths(2*l).u_hat(phi) = 1;
                new_paths(2*l).C(n+1, phi) = 1;
                if current_llrs(l) > 0
                    new_paths(2*l).PM = new_paths(2*l).PM + abs(current_llrs(l));
                end
            end
            
            % 裁剪 (Pruning)：保留 PM 最小的 L 条
            if new_active > L
                pms = [new_paths.PM];
                [~, sort_idx] = sort(pms, 'ascend');
                paths = new_paths(sort_idx(1:L));
                active_paths = L;
            else
                paths = new_paths;
                active_paths = new_active;
            end
        end
        
        % 3. 比特向上反馈 (计算并存储部分和)
        for l = 1:active_paths
            for layer = n:-1:1
                step = 2^(n-layer);
                % 判断当前是否刚刚完成了一个右分支的计算
                is_right = bitand(phi-1, step) == step;
                
                if is_right
                    left_idx = phi - step;
                    % 提取左右子节点的部分和
                    beta_L = paths(l).C(layer+1, left_idx - step + 1 : left_idx);
                    beta_R = paths(l).C(layer+1, phi - step + 1 : phi);
                    
                    % 异或运算向上合并，存入 C 矩阵
                    paths(l).C(layer, left_idx - step + 1 : left_idx) = mod(beta_L + beta_R, 2);
                    paths(l).C(layer, phi - step + 1 : phi)           = beta_R;
                else
                    % 如果是左分支，反馈中止，等待右分支计算完毕
                    break;
                end
            end
        end
    end
    
    % 4. 译码结束，选择最终输出路径
    best_path_idx = 1;
    if use_crc
        % CA-SCL: 首先找出通过 CRC 的路径
        pass_crc_idx = [];
        for l = 1:active_paths
            info_bits_with_crc = paths(l).u_hat(frozen_bits_flag == 0);
            if crc_detector(info_bits_with_crc)
                pass_crc_idx = [pass_crc_idx, l];
            end
        end
        
        % 在通过 CRC 的路径中找 PM 最小的
        if ~isempty(pass_crc_idx)
            best_pm = inf;
            for idx = pass_crc_idx
                if paths(idx).PM < best_pm
                    best_pm = paths(idx).PM;
                    best_path_idx = idx;
                end
            end
        else
            % 若无一通过，退化为普通选 PM 最小
            [~, best_path_idx] = min([paths.PM]);
        end
    else
        [~, best_path_idx] = min([paths.PM]);
    end
    
    u_hat = paths(best_path_idx).u_hat;
end