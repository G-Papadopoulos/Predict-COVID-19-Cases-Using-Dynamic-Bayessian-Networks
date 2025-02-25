function f = forward(t_forward,D_forward,T_forward)

    if t_forward <= 0
        f = [0; 0; 1];
    else
        temp = squeeze(D_forward(t_forward,:,:))*transpose(T_forward);
        temp_sum = sum(sum(temp));
        temp = temp./temp_sum;
        f = temp*forward(t_forward-1,D_forward,T_forward);
        %f = squeeze(D_forward(t_forward,:,:))*transpose(T_forward)*forward(t_forward-1,D_forward,T_forward);
    end
    
end