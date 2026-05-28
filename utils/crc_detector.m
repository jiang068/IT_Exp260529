function is_pass = crc_detector(msg_with_crc)
    % msg_with_crc: 长度为 K 的序列 (含8位CRC)
    poly = [1 0 0 0 0 0 1 1 1];
    crc_len = length(poly) - 1;
    
    rem = msg_with_crc;
    for i = 1:(length(msg_with_crc) - crc_len)
        if rem(i) == 1
            rem(i:i+crc_len) = bitxor(rem(i:i+crc_len), poly);
        end
    end
    
    % 如果余数全为0，则通过校验
    is_pass = all(rem(end-crc_len+1:end) == 0);
end