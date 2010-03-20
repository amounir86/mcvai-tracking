function T = kalman_step(T, frame)

% Get the current filter state.
K = T.tracker;

% Don't do anything unless we're initialized.
if isfield(K, 'm_k1k1') && isfield(T.representer, 'Velocity')

  % Get the current measurement out of the representer.
  z_k = T.representer.Velocity';
  
  % Project the state forward m_{k|k-1}.
  m_kk1 = K.F * K.m_k1k1;
  
  % Partial state covariance update.
  P_kk1 = K.Q + K.F * K.P_k1k1 * K.F';
  
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
  K.m_k1k1 = m_kk;
  K.P_k1k1 = P_kk;
else
  if isfield(T.representer, 'Velocity');
    K.m_k1k1 = T.representer.Velocity';
    K.P_k1k1 = eye(6);
  end
end

% Make sure we stuff the filter state back in.
T.tracker = K;

return