function T = kalman_step(T, frame)
% This method performs the tracking for the object in the scene.
% Currently, it tracks both the bounding box of an object and its velocity

%% Initialize the tracker
% Get the current filter state.
K = T.tracker;

%% Track the BoundingBox
% Don't do anything unless we're initialized.
if isfield(K, 'BBm_k1k1') && isfield(T.representer, 'BoundingBox')

  % Get the current measurement out of the representer.
  z_k = T.representer.BoundingBox';
  
  % Project the state forward m_{k|k-1}.
  m_kk1 = K.BBF * K.BBm_k1k1; % EQ (11)
  
  % Partial state covariance update.
  P_kk1 = K.BBQ + K.BBF * K.BBP_k1k1 * K.BBF'; % EQ (12)
  
  % Innovation is disparity in actual versus predicted measurement.
  innovation = z_k - K.BBH * m_kk1;
  
  % The new state covariance.
  S_k = K.BBH * P_kk1 * K.BBH' + K.BBR;  % EQ (15)
  
  % The Kalman gain.
  K_k = P_kk1 * K.BBH' * inv(S_k); % EQ (16)
  
  % The new state prediction.
  m_kk = m_kk1 + K_k * innovation; % EQ (13)
  
  % And the new state covariance.
  P_kk = P_kk1 - K_k * K.BBH * P_kk1; % EQ (14)
  
  % Innovation covariance.
  K.BBinnovation = 0.2 * sqrt(innovation' * innovation) + (0.8) ...
      * K.BBinnovation;
  
  % And store the current filter state for next iteration.
  K.BBm_k1k1 = m_kk; % This is how the state is saved
  K.BBP_k1k1 = P_kk; % This is how the state is saved
elseif isfield(T.representer, 'BoundingBox');
  % Initialization of states variables
  K.BBm_k1k1 = T.representer.BoundingBox';
  K.BBP_k1k1 = eye(4);
end

%% Now track the velocity
% Don't do anything unless we're initialized.
if isfield(K, 'Vm_k1k1') && isfield(T.representer, 'Velocity')

  % Get the current measurement out of the representer.
  z_k = T.representer.Velocity';
  
  % Project the state forward m_{k|k-1}.
  m_kk1 = K.VF * K.Vm_k1k1; % EQ (11)
  
  % Partial state covariance update.
  P_kk1 = K.VQ + K.VF * K.VP_k1k1 * K.VF'; % EQ (12)
  
  % Innovation is disparity in actual versus predicted measurement.
  innovation = z_k - K.VH * m_kk1;
  
  % The new state covariance.
  S_k = K.VH * P_kk1 * K.VH' + K.VR;  % EQ (15)
  
  % The Kalman gain.
  K_k = P_kk1 * K.VH' * inv(S_k); % EQ (16)
  
  % The new state prediction.
  m_kk = m_kk1 + K_k * innovation; % EQ (13)
  
  % And the new state covariance.
  P_kk = P_kk1 - K_k * K.VH * P_kk1; % EQ (14)
  
  % Innovation covariance.
  K.Vinnovation = 0.2 * sqrt(innovation' * innovation) + (0.8) ...
      * K.Vinnovation;
  
  % And store the current filter state for next iteration.
  K.Vm_k1k1 = m_kk; % This is how the state is saved
  K.VP_k1k1 = P_kk; % This is how the state is saved
elseif isfield(T.representer, 'Velocity');
  % Initialization of states variables
  K.Vm_k1k1 = T.representer.Velocity'; 
  K.VP_k1k1 = eye(4);
end

%% Reassign the tracker
% Make sure we stuff the filter state back in.
T.tracker = K;
return