clear;clc;close all;
% load('resources/ODE_tan_h_net_l15_h0.3_n3_p1_s1_r0.0001_gamma0.0001.mat');
load('/home/user1/Documents/ML/matlab/AntiSymResNet/resources/ResNet_relu_net_l5_h0.9_n10_p1_s1_r0_3d-test.mat')

a = 0; b = 0; c = 1; d = -1; resolution = 80;

[X,Y,Z,V] = slicePlane(a,b,c,d,net, resolution);
surfPlot = surf(X,Y,Z,V,'FaceAlpha',0.3);
surfPlot.EdgeColor = 'none';
xlim([-1 1])
ylim([-1 1])
zlim([-1 1])


for i=1:10
    [X,Y,Z,V] = slicePlane(a,b,c,d,net, resolution);
    surfPlot = surf(X,Y,Z,V,'FaceAlpha',0.3);
    surfPlot.EdgeColor = 'none';
    d = d + 0.2;
    hold on;
end

hold off;

function [X,Y,Z,V] = slicePlane(a, b, c,d, net, resolution)
    normalVec = [a b c];
    grid_1D = linspace(-1,1,resolution);
    % grid_1D = linspace(-5,5,resolution);

    if c~= 0
        [X Y] = meshgrid(grid_1D,grid_1D); % Generate x and y data
        Z = -1/c*(a*X + b*Y + d);
        x_plane = X(:);
        y_plane = Y(:);
        z_plane = Z(:);
    else
        disp('c can''t be zero.')
    end

    for i_point = 1:length(x_plane)
        inputVector = [x_plane(i_point); y_plane(i_point); z_plane(i_point)];
        outputVector = softmax(net.forwardProp(inputVector));
        if outputVector(1) > outputVector(2)
            values_vector(i_point) = 1;
        else
            values_vector(i_point) = 0;
        end
    end

    V = reshape(values_vector,resolution,resolution);
end
