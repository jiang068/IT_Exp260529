function tx = bpsk_modulate(x)
    % BPSK 映射: 0 -> +1, 1 -> -1
    tx = 1 - 2 * x;
end