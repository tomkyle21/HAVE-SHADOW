function [b, tau] = computeCommsExpParamsTwoPoint(cStruct, dStruct, q1, s1, q2, s2, useLog)
% Fit score = 1 + exp(-(x_eff - b)/tau), where x_eff = count or log1p(count).
% Lower counts => higher scores. q1<q2, s1>s2, s in (1,2).

    vals = [];
    vals = [vals; collectComms(cStruct)];
    vals = [vals; collectComms(dStruct)];
    vals = vals(~isnan(vals) & isfinite(vals) & vals >= 0);

    if isempty(vals)
        b = 0; tau = 1;
        warning('Comms fit: no data; using defaults (b=0, tau=1).');
        return;
    end

    % Clamp inputs
    q1 = max(min(q1,1),0); q2 = max(min(q2,1),0);
    if q2 <= q1, q2 = min(q1 + 0.2, 0.99); end
    s1 = min(max(s1, 1+1e-6), 2-1e-6);
    s2 = min(max(s2, 1+1e-6), 2-1e-6);
    if s2 >= s1, s2 = max(s1 - 0.1, 1.05); end

    x = vals;
    if useLog, x = log1p(x); end

    x1 = prctile(x, q1*100);
    x2 = prctile(x, q2*100);
    if ~isfinite(x1) || ~isfinite(x2) || x2 <= x1
        x1 = prctile(x,25); x2 = prctile(x,75);
    end

    % Solve for tau, b so that x1->s1 and x2->s2
    den = log((s1-1)/(s2-1));           % >0 if s1>s2
    if ~isfinite(den) || den <= 0, den = log(2); end
    tau = (x2 - x1) / max(den, eps);
    b   = x1 + tau * log(s1 - 1);
end

function vals = collectComms(S)
    vals = [];
    fns = fieldnames(S);
    for i = 1:numel(fns)
        T = S.(fns{i});
        v = 'Num_Tactical_Comms';
        if ismember(v, T.Properties.VariableNames)
            vals = [vals; toNum(T.(v))]; %#ok<AGROW>
        end
    end
end