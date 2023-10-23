function[ v ] = obj_f_PI( theta ,m, D, pIdx, pol, limit, vOpt)
cost = obj_f(theta, m, D); 

v = pol*theta(pIdx); 

if cost>limit
    v = v + abs(v) + abs(vOpt) * (1 + (cost-limit)); 
end

end
