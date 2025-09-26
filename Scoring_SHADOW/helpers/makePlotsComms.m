function makePlotsComms(T, scenarioLabel)
    if isempty(T) || height(T)==0
        warning('No Comms rows for scenario %s', scenarioLabel); return;
    end

    cfgOrder = {'HH','HA','AH','AA'};
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration), :);
    if isempty(T), warning('%s: All rows had undefined Configuration.', scenarioLabel); return; end

    yLims = [1, 2];
    pilots = unique(string(T.Lead_Pilot),'stable');
    nP = numel(pilots);
    cmap = lines(max(nP,7));
    K = numel(cfgOrder);

    % (1) Per-pilot – Comms_Density_Score
    figure('Name', sprintf('%s – Comms Density Score per Pilot', scenarioLabel), 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration);
        rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;

        subplot(nP,1,p);
        scatter(xnum+jit, tp.Comms_Density_Score, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yLims);
        xticks(1:K); xticklabels(cfgOrder);
        ylabel('Comms Score'); title(sprintf('%s – %s', scenarioLabel, pilots(p)));
    end

    % (2) All pilots – Comms_Density_Score
    figure('Name', sprintf('%s – All Pilots: Comms Density Score', scenarioLabel), 'Color','w');
    xnum = double(T.Configuration);
    rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;
    scatter(xnum+jit, T.Comms_Density_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
    grid on; xlim([0.5 K+0.5]); ylim(yLims);
    xticks(1:K); xticklabels(cfgOrder);
    ylabel('Comms Score'); title([scenarioLabel ' – All Pilots (Comms)']);
end