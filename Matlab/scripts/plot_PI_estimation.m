function [] = plot_PI_estimation(m, FolderName )

    [pNames, ~] = IQMparameters(m);
    
    %%
    files = dir(fullfile( FolderName ,'parameters.mat' )) ;
    %%
    num_p = find(strcmp('EtOH_conc', pNames)) - 1 + 2; % remove EtOH_conc from num_opt and add 2 IC for PetH
    pNames = [pNames(1:num_p-2); 'PEth_IC_L'; 'PEth_IC_H' ];
    for jj = 1: num_p
        T = [];
        load(files.name);
        T = [ log10(parameters.S.par(jj,:)')  ( -1*parameters.S.logPost )  ];
        AllSamples.(cell2mat(pNames(jj))) = T ;
    end

    f = figure(jj) ;
    f.Position = [0 0 1000 1000] ;
    
    dgf = 175;
    figcol = 4;
    figrow = ceil(num_p/4);
    
    for jj = 1: num_p
        subplot(figrow,figcol,jj)
        
        hold on
        
        tmp = AllSamples.(cell2mat(pNames(jj))) ;
        
        tmp = unique ( round(tmp , 3) , "rows" );
            
        [ ~ , idx] = sort( tmp(:,1) ) ;   
        
        [G , val ] = findgroups(tmp(:,1));
        
        Y = splitapply(@min,tmp(idx,2),G) ;
        
        scatter(val,Y , 5 , 'MarkerEdgeColor',  [0 0 0]) ;
        
        [M, idxmin ] = min(Y);
        scatter(val(idxmin), M, 'MarkerEdgeColor',  [0 1 0] )
        
        xmin = min(val)-0.2;
        xmax = max(val)+0.2;

        plot([ xmin , xmax], repmat(chi2inv(0.95, dgf ),1,2), 'r')
        plot([ xmin , xmax], repmat(chi2inv(0.95, dgf-num_p ),1,2), 'g')
        plot([ xmin, xmax], repmat( ( M + chi2inv(0.95, 1 )),1,2), 'b')
        
        
        xlim([ xmin, xmax]) ;
        
        ylabel(' V(\theta)'); xlabel([cell2mat(pNames(jj))],'Interpreter','none')
        
        set(gcf,'color' ,'w')
        set(gca, 'Fontsize' , 14) ;
    end
    
    %%
    exportgraphics(f, [ FolderName '/Sampling_PP_small_bounds.png' ],'Resolution',600)
    exportgraphics(f, [ FolderName '/Sampling_PP_small_bounds.pdf' ],'Resolution',600)

end