clear all

load('/home/user1/Documents/ML/matlab/AntiSymResNet/resources/ODE-END_segSig_net_l20_h0.6_n10_p1_s1_r0.7_r1_0.001_r2_0.mat')

% Super-resolution factor:
% the new grid will have resolution 1/super_res_factor (old grid has step 1)
super_res_factor = 3;

% Extract Anti-Symmetric ResNet Weights Matrices from the network
L_old = net.totalNumLayers;
for l = 3 : L_old - 1
    W_old(:,:,l) = net.getWeights(l);
    b_old(:,l) = net.getBias(l);
end

dim_W = size(W_old,1);

%% Interpolate weights and biases using Spline interpolation
grid_old = 3 : L_old -1;
grid_new = 3 : 1/super_res_factor : L_old - 1;
for i = 1 : dim_W
    % Interpolate biases
    b_values = squeeze(b_old(i,3 : L_old - 1));
    b_new(i,:) = interp1(grid_old, b_values, grid_new ,'spline');

    % Interpolate weights
    for j = 1 : i-1
        % interpolate lower traingular part using spline interpolation
        W_values = squeeze(W_old(i,j,3 : L_old - 1));
        W_new(i,j,:) = interp1(grid_old, W_values, grid_new, 'spline');

        % fill upper triangular part
        W_new(j,i,:) = - W_new(i,j,:);
    end
end

% Fill main diagonal of weight matrices
for i = 1 : dim_W
    W_new(i,i,:) = W_old(i,i,3); % diagonal entry is constant
end

size_new_W = size(W_new);
depth = size_new_W(3);

%% Build the interpolated network (interp_net)
%%%
%%% The h should be the old one for the first and last layers
%%%

h = net.h / super_res_factor;
interp_net = ResNetAntiSym_ODE_END(depth, 784, net.outputLayerSize, net.hiddenLayersSize, 0.01, h, net.initScaler, false, net.activFunc,net.p, net.s, net.r, net.r1, net.r2);
interp_net.hIO = net.h;
L_new = interp_net.totalNumLayers;

interp_net.W{2} = net.W{2};
interp_net.W2_lin = net.W2_lin;
interp_net.b{2}  = net.b{2};
interp_net.b2_lin  = net.b2_lin;

for i = 1 : depth
    interp_net.W{2+i} = W_new(:,:,i);
    interp_net.b{2+i}  = b_new(:,i);
end
interp_net.W{L_new} = net.W{L_old};
interp_net.b{L_new}  = net.b{L_old};
interp_net.WYN_lin = net.WYN_lin;
interp_net.bYN_lin  = net.bYN_lin;
net = interp_net;
save('resources/interpolated', 'net')


valuesNew(:) = W_new(2,5,:);
valuesOld(:) = W_old(2,5,3:L_old-1);
length(grid_old)
length(valuesOld)

figure;
plot(grid_old,valuesOld);
hold on;
semilogy(grid_new,valuesNew);
legend({'original weight', 'interpolated weight'})
title('Weight interpolation through layers')
