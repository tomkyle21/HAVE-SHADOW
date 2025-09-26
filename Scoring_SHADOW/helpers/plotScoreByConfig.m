function plotScoreByConfig(Tin, scenarioLabel, scoreCol, titleText, yLims, yTicks, yTickLabels)
% Standard jittered-scatter by Configuration, one figure per scenario.
% - Tin must have Scenario, Configuration, the score column, and Lead_Pilot.

    if nargin < 5 || isempty(yLims), yLims = []; end
    if nargin < 6, yTicks = []; end
    if nargin < 7, yTickLabels = []; end

    T = Tin(string(Tin.Scenario) == string(scenarioLabel), :);
    if isempty(T), warning('No rows for scenario %s', scenarioLabel); return; end

    % Enforce config order
    cfgOrder = {'HH','HA','AH','AA'};
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration), :);
    if isempty(T)
        warning('%s: all rows had undefined Configuration.', scenarioLabel);
        return;
    end

    figure('Color','w'); hold on; grid on;
    title(sprintf('%s – %s', string(scenarioLabel), titleText));
    xlabel('Configuration'); ylabel(titleText);

    xnum = double(T.Configuration);
    rng(1); jit = (rand(size(xnum)) - 0.5) * 0.20;
    scatter(xnum + jit, T.(scoreCol), 32, 'k', 'filled', ...
        'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor','k','LineWidth',0.25);

    xlim([0.5, numel(cfgOrder)+0.5]);
    xticks(1:numel(cfgOrder)); xticklabels(cfgOrder);
    if ~isempty(yLims), ylim(yLims); end
    if ~isempty(yTicks), yticks(yTicks); end
    if ~isempty(yTickLabels), yticklabels(yTickLabels); end
end