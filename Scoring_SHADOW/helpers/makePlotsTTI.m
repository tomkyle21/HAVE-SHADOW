function makePlotsTTI(T, scenarioLabel)
    if isempty(T) || height(T)==0
        warning('No TTI rows for scenario %s', scenarioLabel);
        return;
    end

    cfgOrder = {'HH','HA','AH','AA'};
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration), :);
    if isempty(T)
        warning('%s: All TTI rows had undefined Configuration.', scenarioLabel);
        return;
    end

    yTTI = [1, 2];

    pilots = unique(string(T.Lead_Pilot), 'stable');
    nP = numel(pilots);
    cmap = lines(max(nP,7));
    K = numel(cfgOrder); xcats = 1:K;

    figure('Name', sprintf('%s – TTI Score per Pilot', scenarioLabel), 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p), :);
        xnum = double(tp.Configuration);
        rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;

        subplot(nP,1,p);
        scatter(xnum+jit, tp.TTI_Score, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yTTI);
        xticks(xcats); xticklabels(cfgOrder);
        ylabel('TTI Score'); title(sprintf('%s – %s (TTI)', scenarioLabel, pilots(p)));
    end

    figure('Name', sprintf('%s – All Pilots: TTI Score', scenarioLabel), 'Color','w');
    xnum = double(T.Configuration);
    rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;
    scatter(xnum+jit, T.TTI_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
    grid on; xlim([0.5 K+0.5]); ylim(yTTI);
    xticks(xcats); xticklabels(cfgOrder);
    ylabel('TTI Score'); title([scenarioLabel ' – All Pilots (TTI)']);
end