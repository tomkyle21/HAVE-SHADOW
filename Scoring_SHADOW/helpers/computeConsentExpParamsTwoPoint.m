function [b, tau] = computeConsentExpParamsTwoPoint(cStruct, dStruct, intsC, intsD, ...
                                                    q1, s1, q2, s2, useLog)
% Fit score = 1 + exp(-(t_eff - b)/tau) where t_eff = TTC or log1p(TTC).
% q1,q2 in [0,1] (q1<q2), s1,s2 in (1,2) with s1>s2.

    vals = [];
    vals = [vals; collectAllTTC(cStruct, intsC)];
    vals = [vals; collectAllTTC(dStruct, intsD)];
    vals = vals(~isnan(vals) & isfinite(vals) & vals>=0);

    if isempty(vals)
        b = 0; tau = 1; warning('TTC two-point fit: no data; using defaults.'); return;
    end

    q1 = max(min(q1,1),0); q2 = max(min(q2,1),0);
    if q2 <= q1, q2 = min(q1 + 0.2, 0.99); end
    s1 = min(max(s1, 1+1e-6), 2-1e-6);
    s2 = min(max(s2, 1+1e-6), 2-1e-6);
    if s2 >= s1, s2 = max(s1 - 0.1, 1.05); end

    t = vals;
    if useLog, t = log1p(t); end

    x1 = prctile(t, q1*100);
    x2 = prctile(t, q2*100);
    if ~isfinite(x1) || ~isfinite(x2) || x2 <= x1
        x1 = prctile(t, 25); x2 = prctile(t, 75);
    end

    den   = log((s1-1)/(s2-1));          % >0 if s1>s2
    if ~isfinite(den) || den<=0, den = log(2); end

    tau = (x2 - x1) / max(den, eps);
    b   = x1 + tau * log(s1 - 1);
end

function vals = collectAllTTC(S, ints)
    vals = [];
    fns = fieldnames(S);
    for i = 1:numel(fns)
        T = S.(fns{i});
        for k = ints
            v = sprintf('CM%d_MOP_Time_to_Consent_s', k);   % <-- exact header pattern
            if ismember(v, T.Properties.VariableNames)
                vals = [vals; toNum(T.(v))]; %#ok<AGROW>
            end
        end
    end
end