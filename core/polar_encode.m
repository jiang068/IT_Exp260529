function x = polar_encode(u)
    % 输入 u: 长度为N的源序列 (含信息位和冻结位)
    N = length(u);
    n = log2(N);
    
    % 取消了比特倒序置换，直接让 x=u 进入蝶形运算
    % 这样可以与 GA 构造和 SC 译码树的自然顺序完美对齐
    x = u; 
    
    % 应用 F^n 递归蝶形运算
    for stage = 1:n
        step = 2^(stage-1);
        for i = 1:2*step:N
            for j = 0:step-1
                % F = [1 0; 1 1] 运算
                x(i+j) = mod(x(i+j) + x(i+j+step), 2);
            end
        end
    end
end