function [adhoc] = calculateAdhoc(sim)

adhoc = 0;
if any( contains(sim.variables, "vCYP2E1") )
    idx_vCYP2E1 = ismember(sim.variables, "vCYP2E1" );
    idx_vADH    = ismember(sim.variables, "vADH" ) ;

    CYP2E1 = trapz( sim.variablevalues(:,idx_vCYP2E1) );
    ADH    = trapz( sim.variablevalues(:,idx_vADH) );

    Total = CYP2E1 + ADH;
    
    % check the distribution of ADH and CYP2E1
    if Total*0.85 >= ADH && Total>0

        penalty3 = max(0, Total*0.85 - ADH) + 100 ;
        adhoc = adhoc  +  penalty3;
    end

    if Total*0.10 <= CYP2E1 && Total>0
        penalty1 = max(0, CYP2E1 - Total*0.10  ) + 100 ;
        adhoc = adhoc  +  penalty1;

    elseif Total*0.001 >= CYP2E1 && Total>0
        penalty1 = max(0, Total*0.001 - CYP2E1) + 100 ;
        adhoc = adhoc  +  penalty1;
    end

%     % check that the liquid kcal is emptied
%     idx_kcal_liquid = ismember(sim.states, ["Kcal_Liquid", "Kcal_EtOH"]);
%     id_max = find(max(sim.statevalues(:, idx_kcal_liquid)) == sim.statevalues(:, idx_kcal_liquid), 1);
% 
%     if sum(sim.statevalues(end, idx_kcal_liquid)) > 0.4*sum(sim.statevalues(id_max, idx_kcal_liquid))
%         penalty2 = max(0, sum(sim.statevalues(end, idx_kcal_liquid) - 0.4*sim.statevalues(id_max, idx_kcal_liquid)) ) + 100;
%         adhoc = adhoc  +  penalty2;
%     end
    
    % check that the solid kcal is emptied
    idx_kcal_solid = ismember(sim.states, "Kcal_Solid");
    idx_max_kcal_solid = ismember(sim.states, "max_Kcal_Solid");

    if sim.statevalues(end, idx_kcal_solid) > 0.7*sim.statevalues(1, idx_kcal_solid) && sim.statevalues(1, idx_max_kcal_solid) > 0
        penalty3 = max(0, sim.statevalues(end, idx_kcal_solid) - 0.7*sim.statevalues(1, idx_kcal_solid)) + 100;
        adhoc = adhoc  +  penalty3;
    end
end