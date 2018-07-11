% ResNetSoftMax class implements a Residual Neural Network

classdef ResNetAntiSym < handle
% ResNet class with cross entropy objective function
    properties
        name;   % some str value
        tm;     % testmode, this param is used for testing gradients of the NN
        h;
        hIO;    % h value for W_2 and W_YN, this var is needed for NN that was interpolated
        igamma;
        initScaler;
        numHiddenLayers;    % hiddenLayers are layers 3, 4,...,L-1
        inputLayerSize;
        outputLayerSize;
        hiddenLayersSize;
        W2_lin;
        b2_lin;
        WYN_lin;
        bYN_lin;
        W;
        b;
        totalNumLayers;
        O;      % An array of omegas
        DY;     % An array of derivatives dY^(l)/dY^(l-1)
        Y;      % An array Y stores  layer vectors
        D;      % An arrat that stores Delta vectors. Delta represent the derivative of of the CostFunction w.r.t. y^(l)
        r;      % Regularization parameter
    end

    methods
        function obj = ResNetAntiSym(i_numHiddenLayers, i_inputLayerSize, i_outputLayerSize, i_hiddenLayersSize, i_gamma, h, initScaler, regular, i_testMode)
            % ResNet constructor
            obj.tm = i_testMode;
            obj.numHiddenLayers = i_numHiddenLayers;
            obj.inputLayerSize = i_inputLayerSize;
            obj.outputLayerSize = i_outputLayerSize;
            obj.hiddenLayersSize = i_hiddenLayersSize;
            obj.totalNumLayers = 0;
            obj.initScaler = initScaler;
            obj.igamma = i_gamma;
            obj.h = h;
            obj.hIO = h;
            obj.r = regular;
            % Init arrays
            obj.D{1} = 0;   % Array of gradients dC/dY
            obj.O{1} = 0;   % Array of Omega gradients dY_i^(l)/dW_ij^(l)
            obj.Y{1} = 0;   % Array of forward pass layers Y
            obj.DY{1} = 0;  % Array of dY^(l)/dY^(l-1)
            obj.Y{2} = zeros(obj.hiddenLayersSize, 1);    % init array Y as matrix with all enries 0
            obj.D{2} = zeros(obj.hiddenLayersSize, 1);    % init array D as matrix with all enries 0

            % Build W2, b2 for connections from input layer to first hidden
            W2 = obj.initScaler*normrnd(0,1,[obj.hiddenLayersSize, obj.inputLayerSize]);
            b2 = obj.initScaler*normrnd(0,1,[obj.hiddenLayersSize,1]);

            obj.W2_lin = obj.initScaler*normrnd(0,1,[obj.hiddenLayersSize, obj.inputLayerSize]);
            obj.b2_lin = obj.initScaler*normrnd(0,1,[obj.hiddenLayersSize,1]);

            obj.WYN_lin = obj.initScaler*normrnd(0,1,[obj.outputLayerSize, obj.hiddenLayersSize]);
            obj.bYN_lin = obj.initScaler*normrnd(0,1,[obj.outputLayerSize,1]);

            obj.W{2} = W2;
            obj.b{2} = b2;

            gammaMatrix = obj.igamma * eye(obj.hiddenLayersSize);

            % Build intermediate W and b
            for i = 3:obj.numHiddenLayers + 2   % do not build W and b from last hidden layer to output layer
                K = obj.initScaler*normrnd(0,1,[obj.hiddenLayersSize, obj.hiddenLayersSize]);
                W = 0.5*(K - K' - gammaMatrix);
                b = obj.initScaler*normrnd(0,1,[obj.hiddenLayersSize,1]);
                obj.W{i} = W;
                obj.b{i} = b;
            end

            % Build W and b from last hidden layer to output layer
            WN = obj.initScaler*normrnd(0,1,[obj.outputLayerSize, obj.hiddenLayersSize]);
            bN = obj.initScaler*normrnd(0,1,[obj.outputLayerSize, 1]);
            obj.W{i+1} = WN;
            obj.b{i+1} = bN;
            [~, obj.totalNumLayers] = size(obj.W);

        end


        function result = forwardProp(obj, i_vector)
            % Forward propagation
            YN = obj.totalNumLayers;
            % relu first hidden layer
            obj.Y{2} = obj.W2_lin*i_vector + obj.b2_lin + obj.hIO*relu(obj.W{2},i_vector,obj.b{2}, obj.tm);

            % relu hidden layers
            for i = 3:YN - 1
                obj.Y{i} = obj.Y{i-1} + obj.h*relu(obj.W{i},obj.Y{i-1},obj.b{i}, obj.tm);
            end

            % relu last layer
            obj.Y{YN} = obj.WYN_lin*obj.Y{YN-1} + obj.bYN_lin + obj.hIO*relu(obj.W{YN},obj.Y{YN-1},obj.b{YN}, obj.tm);

            result = obj.Y{end};

        end


        function backresult = backProp(obj, i_vector, label_vector, eta, updateWeights)
            % Back propagation. Inputs: self, training vector, label vector, learning rate eta, updateWeights: true/false
            Y = obj.Y{end};
            YN = obj.totalNumLayers;

            % Build softmax layer
            h_vec = [];
            for i=1:obj.outputLayerSize;
                h_vec(i) = softmax(Y(i),Y);
            end

            % Build dh/dY^(L) matrix, i.e deriv of softmax h w.r.t y^(L)
            dh = [];
            for i =1:obj.outputLayerSize;
                for j=1:obj.outputLayerSize;
                    if i==j
                        dh(i,j) = softmax(Y(i),Y)*(1-softmax(Y(j),Y));
                    else
                        dh(i,j) = -softmax(Y(i),Y)*softmax(Y(j),Y);
                    end
                end
            end

            % Calculate the last layer error gradient dC/dY^(L)
            obj.D{YN} = dh' * (-label_vector ./ h_vec');
            % Calculate the last layer weights gradient dY^(L)/dW^(L)
            obj.O{YN} = (obj.h*obj.D{YN}.*reluD(obj.W{YN},obj.Y{YN-1},obj.b{YN}, obj.tm))*obj.Y{YN-1}';
            % Calculate YN-1 layer gradient
            obj.D{YN-1} = obj.WYN_lin'*obj.D{YN} + obj.W{YN}'*(obj.D{YN}.*reluD(obj.W{YN},obj.Y{YN-1},obj.b{YN}, obj.tm)*obj.h);
            % Calculate the last YN-1 layer weights gradient dY_(L-1)/dW_(L-1)
            obj.O{YN-1} = obj.h * reluD(obj.W{YN-1}, obj.Y{YN-2}, obj.b{YN-1}, obj.tm) * obj.Y{YN-2}';

            % Calculate error gradient for L-2, L-3,..., 2 layers
            for i = YN-2:-1:2
                % Compute delta
                obj.D{i} = obj.D{i+1} + obj.W{i+1}'*( obj.D{i+1} .* (obj.h*reluD(obj.W{i+1},obj.Y{i},obj.b{i+1}, obj.tm)) );
                % Compute omega
                obj.O{i} = obj.h * reluD(obj.W{i},obj.Y{i-1}, obj.b{i}, obj.tm) * obj.Y{i-1}';
            end

            % Compute gradient dC/dX
            obj.D{1} = obj.W2_lin' * obj.D{2} + obj.h*obj.W{2}' * (obj.D{2} .* reluD(obj.W{2}, i_vector, obj.b{2}, obj.tm));
            backresult = obj.D{1};  % return dC/dX

            if updateWeights == true
                % Gradient step. Update weights and biases

                % First update dim reduction weights and biases
                obj.W2_lin = obj.W2_lin - eta*obj.D{2} *i_vector';
                obj.b2_lin = obj.b2_lin - eta*obj.D{2};

                obj.WYN_lin = obj.WYN_lin - eta*obj.D{YN} * obj.Y{YN-1}';
                obj.bYN_lin = obj.bYN_lin - eta*obj.D{YN};

                % Update ReLu weights and biases for layer 2 and YN
                obj.W{2} = obj.W{2} - eta * (obj.h*obj.D{2}.* reluD(obj.W{2}, i_vector, obj.b{2}, obj.tm))* i_vector';
                obj.b{2} = obj.b{2} - eta* obj.h* obj.D{2} .* reluD(obj.W{2}, i_vector,obj.b{2}, obj.tm);

                obj.W{YN} = obj.W{YN} - eta * obj.O{YN};
                obj.b{YN} = obj.b{YN} - eta* obj.h* obj.D{YN} .* reluD(obj.W{YN}, obj.Y{YN-1}, obj.b{YN}, obj.tm);

                % Update intermediate layers
                for i = 3:YN-1
                    obj.W{i} = obj.W{i} - eta * 0.5*(diag(obj.D{i})*obj.O{i} - (diag(obj.D{i})*obj.O{i})') - obj.r*(obj.W{i} - obj.W{i}');
                    obj.b{i} = obj.b{i} - eta* obj.h* obj.D{i} .* reluD(obj.W{i}, obj.Y{i-1}, obj.b{i}, obj.tm);
                    % obj.W{i} = obj.W{i} - eta * 0.5*(diag(obj.D{i})*obj.O{i} - (diag(obj.D{i})*obj.O{i})');
                    % obj.b{i} = obj.b{i} - eta* obj.h* obj.D{i} .* reluD(obj.W{i}, obj.Y{i-1}, obj.b{i}, obj.tm);
                end
            end
        end


        %  Compute derivate dY^(L)/dX
        function dYdX = computedYdX(obj, i_vector)
            % TODO need to change this cause y^(L) and y^(l2) are changed
            disp('this method needs to be changed cause y^(2) and y^(L) were modified');
            YN = obj.totalNumLayers;

            % Calculate the last layer gradient dY_i^(l)/dY_j^(l-1)
            obj.DY{YN-1} = obj.W{YN} .* (ones(obj.outputLayerSize,1) + obj.h*reluD(obj.W{YN}, obj.Y{YN-1}, obj.b{YN}, obj.tm));

            % Calculate the L-1, L-2, ... , 2 layer gradients
            for i = YN-2:-1:2
                obj.DY{i} = obj.DY{i+1} + obj.DY{i+1} * (obj.W{i+1}.*obj.h*reluD(obj.W{i+1}, obj.Y{i}, obj.b{i+1}, obj.tm));
            end

            obj.DY{1} = obj.DY{2} * obj.W{2} + obj.DY{2} * (obj.W{2} .* ( obj.h*reluD(obj.W{2}, i_vector, obj.b{2}, obj.tm)) );
            dYdX = obj.DY{1};
        end

        % Adversarial back prop
        function perturbedVector = adversBackProp(obj, i_vector,label_vector,eta)
            % Gradient w.r.t the i_vector
            backProp(obj, i_vector, label_vector, eta, false);
            perturbator = eta*obj.D{1};
            perturbedVector = i_vector + perturbator;
        end


        % Training
        function trainingRes = train(obj, trainData, trainLabel, cycles, eta)
            [vecSize, numVecs] = size(trainData);
            costAvg = 0;
            numSamples = 3000;

            for i = 1:cycles


                randInd = randi(numVecs);
                x = trainData(:, randInd);
                c = trainLabel(:, randInd);

                y = forwardProp(obj, x);

                softY = [];
                for j=1:obj.outputLayerSize
                    softY(j) = softmax(y(j),y);
                end


                backProp(obj, x, c, eta, true);

                costAvg = costAvg + norm(c - softY')^2;

                if mod(i, numSamples) == 0
                    progress = 100*i / cycles;
                    [softY',c]
                    costAvg = costAvg / double(numSamples);
                    disp(['average cost over ', num2str(numSamples, '%0d'),' samples: ', num2str(costAvg, '%0.3f'),' progress: ', num2str(progress)]);
                    gradNorms = obj.gradientNorms()
                    costAvg = 0;
                end

            end

        end


        function delta = getDelta(obj, id)
            delta = obj.D{id};
        end


        function weights = getWeights(obj, id)
            weights = obj.W(id);
            weights = weights{1};
        end


        function bias = getBias(obj, id)
            bias = obj.b(id);
            bias = bias{1};
        end


        function normsVec = gradientNorms(obj)

            for i = obj.totalNumLayers:-1:1
                normsVec(i) = norm(obj.D{i});
            end
        end
    end
end

function y = activf(W,x,b,activ,testmode)
    if activ == 'relu'
        y = relu(W,x,b,testmode);
    elseif activ == 'sigmoid'
        y = sigm(W,x,b);
    elseif activ == 'powerlog'
        y = powerlog(W,x,b);
    end
end

function y = relu(W, x, b, testmode)
% vector ReLu activation fucntion
    [~,n] = size(W);

    if testmode == true
        y = W*x+b;    % this is for testing without max() operator
    else
        y = max(0, W*x+b);
    end
end


function d = reluD(W, x, b, testmode)
    % vector ReluD derivative of the ReLu function
    leak = 0;

    if testmode == true
        d = 1;    % this is for testing without max() operator
    else
        d = W*x + b >= 0;
        d(d==0) = leak;
    end
end


function y = sigm(W,x,b)
    % vector sigmoid activation function.
    y = 1./(1+exp(-(W*x+b)));
end


function d = sigmD(W,x,b)
    % vector sigmD is a derivative of the sigmoid function
    d = sigm(W*x+b) .* (1 - sigm(W*x+b));
end

% function y = sigm(z)
%     % scalar sigmoid activation function.
%     y = 1./(1+exp(-z));
% end
%
%
% function d = sigmD(x)
%     % scalar sigmD is a derivative of the sigmoid function
%     d = sigm(x) .* (1 - sigm(x));
% end


function resSoft = softmax(y, y_args)
    % scalar This function computes softmax
    y_argsSum = 0;
    inputSize = max(size(y_args));

    for i = 1:inputSize
        y_argsSum = y_argsSum + exp(y_args(i));
    end

    resSoft = exp(y) / y_argsSum;
end
