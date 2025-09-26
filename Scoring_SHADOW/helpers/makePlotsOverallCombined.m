function makePlotsOverallCombined(G, scenarioLabel)
% makePlotsOverallCombined
%   Scatter plot of overall intercept product across configurations for all pilots
%   G = table with Scenario, Configuration, Lead_Pilot, Overall_Intercept_Product
%   scenarioLabel = 'C' or 'D'

    if isempty(G) || height(G)==0
        warning('No Overall Intercept rows to plot for %s', scenarioLabel);
        return;
    end

    % Filter scenario
    G = G(G.Scenario==scenarioLabel, :);
    if isempty(G), return; end

    % Enforce config order
    cfgOrder = {'HH','HA','AH','AA'};
    G.Configuration = categorical(string(G.Configuration), cfgOrder, 'Ordinal', true);
    G = G(~isundefined(G.Configuration), :);
    if isempty(G), return; end

    % Jitter for readability
    xnum = double(G.Configuration);
    rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;

    % Plot
    figure('Name', sprintf('%s – Overall Intercept Product (All Pilots)', scenarioLabel), 'Color','w');
    scatter(xnum+jit, G.Overall_Intercept_Product, 32, 'k', ...
        'filled','MarkerFaceAlpha',0.6,'MarkerEdgeColor','k','LineWidth',0.25);
    grid on;
    xlim([0.5 4.5]);
    xticks(1:4); xticklabels(cfgOrder);
    ylabel('Overall Intercept Product (across intercepts)');
    title(sprintf('%s – All Pilots (Overall Intercept Product)', scenarioLabel));
end