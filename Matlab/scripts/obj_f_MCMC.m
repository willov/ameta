function [cost] = obj_f_MCMC(theta,m,D,dgf,FID)
    
    if any(theta<0)
        theta = exp(theta);
    end

    cost = obj_f(theta, m, D); 

    if nargin == 5 && cost < chi2inv(0.95,dgf) 
        fprintf(FID,'%4.10f %10.10f ',[cost, theta']); fprintf(FID,'\n');
    end
end