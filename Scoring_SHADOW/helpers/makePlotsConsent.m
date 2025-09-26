function makePlotsConsent(T, scenarioLabel)
    if isempty(T) || height(T)==0
        warning('No TTC rows for scenario %s', scenarioLabel);
        return;
    end

    cfgOrder = {'HH','HA','AH','AA'};
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration), :);
    if isempty(T)
        warning('%s: All TTC rows had undefined Configuration.', scenarioLabel);
        return;
    end

    yLims = [1, 2];   % scores are in [1, ~2)

    pilots = unique(string(T.Lead_Pilot), 'stable');
    nP = numel(pilots);
    cmap = lines(max(nP,7));
    K = numel(cfgOrder); xcats = 1:K;

    % (1) Per-pilot scatter
    figure('Name', sprintf('%s – Consent Score per Pilot', scenarioLabel), 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p), :);
        xnum = double(tp.Configuration);
        rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;

        subplot(nP,1,p);
        scatter(xnum+jit, tp.Consent_Score, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yLims);
        xticks(xcats); xticklabels(cfgOrder);
        ylabel('Consent Score'); title(sprintf('%s – %s (Time-to-Consent)', scenarioLabel, pilots(p)));
    end

    % (2) All-pilots scatter
    figure('Name', sprintf('%s – All Pilots: Consent Score', scenarioLabel), 'Color','w');
    xnum = double(T.Configuration);
    rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;
    scatter(xnum+jit, T.Consent_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
    grid on; xlim([0.5 K+0.5]); ylim(yLims);
    xticks(xcats); xticklabels(cfgOrder);
    ylabel('Consent Score'); title([scenarioLabel ' – All Pilots (Consent)']);
end