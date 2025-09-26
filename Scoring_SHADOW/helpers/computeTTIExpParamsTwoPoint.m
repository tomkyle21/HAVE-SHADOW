function [b, tau] = computeTTIExpParamsTwoPoint(cStruct, dStruct, intsC, intsD, ...
                                                q1, s1, q2, s2, useLog)
% Fit exponential score = 1 + exp(-(TTI - b)/tau)
% using two anchors: percentile q1 -> score s1, percentile q2 -> score s2.
% q1,q2 in [0,1], s1,s2 in (1,2). Typically q1<q2 and s1>s2.
%
% Set useLog=true to compute percentiles on log1p(TTI) for robustness.

    vals = [];
    vals = [vals; collectAllTTI(cStruct, intsC)];
    vals = [vals; collectAllTTI(dStruct, intsD)];
    vals = vals(~isnan(vals) & isfinite(vals) & vals >= 0);

    if isempty(vals)
        b = 0; tau = 1;
        warning('TTI two-point fit: no data; using defaults.');
        return;
    end

    q1 = max(min(q1,1),0); q2 = max(min(q2,1),0);
    if q2 <= q1, q2 = min(q1 + 0.2, 0.99); end  % ensure separation

    s1 = min(max(s1, 1+1e-6), 2-1e-6);
    s2 = min(max(s2, 1+1e-6), 2-1e-6);
    if s2 >= s1, s2 = s1 - 0.1; s2 = max(s2, 1.05); end

    t = vals;
    if useLog, t = log1p(t); end

    x1 = prctile(t, q1*100);
    x2 = prctile(t, q2*100);
    if ~isfinite(x1) || ~isfinite(x2) || x2 <= x1
        % fallback: use interquantile span
        x1 = prctile(t, 25);
        x2 = prctile(t, 75);
    end

    % Solve for tau and b in transformed space t
    num = (x2 - x1);
    den = log((s1-1)/(s2-1));    % >0 if s1>s2
    if den <= 0 || ~isfinite(den)
        den = log(2);  % fallback
    end
    tau_t = num / max(den, eps);
    b_t   = x1 + tau_t * log(s1 - 1);

    % Map back baseline if we used log (tau is in transformed units, but we
    % still apply score = 1 + exp(-(TTI_eff)/tau_eff) with TTI_eff built the same way)
    % We'll implement scoring over the same transformed axis inside the builder.

    % Pack results as a struct via base workspace? Simpler: return both and reuse.
    b = b_t;
    tau = tau_t;
end

function vals = collectAllTTI(S, ints)
    vals = [];
    fns = fieldnames(S);
    for i = 1:numel(fns)
        T = S.(fns{i});
        for k = ints
            v = sprintf('CM%d_MOP_Time_to_Intercept_s', k);
            if ismember(v, T.Properties.VariableNames)
                vals = [vals; toNum(T.(v))]; %#ok<AGROW>
            end
        end
    end
end