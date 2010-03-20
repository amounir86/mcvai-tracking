function T = multiple_kalman_step2(T, frame)


% Get the current filter state.
if (~isfield(T.tracker, 'TObjs'))
    T.tracker.TObjs = [];
end

K = T.tracker;
TObjs = [];

for i = 1 : length(T.representer.all)

    
    % Don't do anything unless we're initialized.
    if length(T.tracker.TObjs) >= i && isfield(T.representer.all(i), 'Velocity')
        
      TObj = T.tracker.TObjs(i);

      % Get the current measurement out of the representer.
      z_k = T.representer.all(i).Velocity';

      % Project the state forward m_{k|k-1}.
      m_kk1 = K.F * TObj.m_k1k1;

      % Partial state covariance update.
      P_kk1 = K.Q + K.F * TObj.P_k1k1 * K.F';

      % Innovation is disparity in actual versus predicted measurement.
      innovation = z_k - K.H * m_kk1;

      % The new state covariance.
      S_k = K.H * P_kk1 * K.H' + K.R;

      % The Kalman gain.
      K_k = P_kk1 * K.H' * inv(S_k);

      % The new state prediction.
      m_kk = m_kk1 + K_k * innovation;

      % And the new state covariance.
      P_kk = P_kk1 - K_k * K.H * P_kk1;

      % Innovation covariance.
      K.innovation = 0.2 * sqrt(innovation' * innovation) + (0.8) ...
          * K.innovation;

      % And store the current filter state for next iteration.
      TObj.m_k1k1 = m_kk;
      TObj.P_k1k1 = P_kk;
      TObj.m_BB = [m_kk(1) - (m_kk1(5)/2) m_kk(2) - (m_kk1(6)/2) ...
          m_kk1(5) m_kk(6)];
    else
      if (length(T.representer.all)>=1);
        TObj.m_k1k1 = T.representer.all(i).Velocity';
        TObj.P_k1k1 = eye(6);
        TObj.m_BB = T.representer.all(i).BoundingBox;
      end
    end

    TObjs = [TObjs TObj];
end

T.tracker.TObjs = TObjs;
return