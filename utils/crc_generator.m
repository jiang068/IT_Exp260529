function u_crc = crc_generator(msg)
    % msg: 原始信息比特 (长度为 K-8)
    % u_crc: 附加了 8位 CRC 后的信息比特 (长度为 K)
    % 采用 CRC-8 多项式: x^8 + x^2 + x + 1 -> [1 0 0 0 0 0 1 1 1]
    poly = [1 0 0 0 0 0 1 1 1];
    crc_len = length(poly) - 1;
    
    msg_padded = [msg, zeros(1, crc_len)];
    rem = msg_padded;
    
    % 模2长除法求余数
    for i = 1:length(msg)
        if rem(i) == 1
            rem(i:i+crc_len) = bitxor(rem(i:i+crc_len), poly);
        end
    end
    
    crc_bits = rem(end-crc_len+1:end);
    u_crc = [msg, crc_bits];
end