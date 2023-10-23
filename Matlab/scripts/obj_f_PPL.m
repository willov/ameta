function[ v, cost] = obj_f_PPL( theta ,m, D, experiment, var, t, pol, limit, vOpt)

[cost, PPL_obj] = obj_f(theta, m, D, 0, experiment, var, t); 

v = pol*PPL_obj; 

if cost>limit
    v = v + abs(v) + abs(vOpt) *(1 + (cost-limit)); 
end

end
