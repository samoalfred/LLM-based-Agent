%% LLM-based Agent for Hall-Petch Fitting - PORTABLE VERSION
% This version will work on any computer as long as the data file is in the
% same folder as this MATLAB script.
%
% To use:
% 1. Place this script and your data CSV file in the same folder
% 2. Update the filename variable below to match your CSV file name
% 3. Run the script

clc; clear; close all; 

%% CONFIGURATION - CHANGE THIS IF NEEDED
% Data file name (should be in the same folder as this script)
DATA_FILENAME = 'HP_Dataset.csv';  % <-- CHANGE THIS to your file name

%% Get the current script's directory and build full path
% This works on any computer - finds where this script is located
script_dir = fileparts(which(mfilename('fullpath')));
full_data_path = fullfile(script_dir, DATA_FILENAME);

fprintf('Script directory: %s\n', script_dir);
fprintf('Looking for data file: %s\n', full_data_path);

%% Initialize AI Model for ReAct Reasoning
ai_model = openAIChat(['You are an agent helping fit grain size and yield strength data using the Hall-Petch equation. ' ...
    'At each step: 1) Think about what to do next, 2) Choose an action, 3) Observe results. ' ...
    'Be concise and specific.'], ModelName="gpt-4");

%% Initialize Tool Registry
tools = struct();

% Tool 1: Load Data
tools.load_data = struct();
tools.load_data.description = 'Load Hall-Petch data from CSV file';
tools.load_data.input_schema = {'filename'};
tools.load_data.execute = @action_load_data;

% Tool 2: Generate Function 
tools.generate_function = struct();
tools.generate_function.description = 'Generate Hall-Petch function using LLM (MUST come from LLM )';
tools.generate_function.input_schema = {};  % No inputs needed
tools.generate_function.execute = @(input, agent_state) action_generate_function(input, agent_state);

% Tool 3: Test Function
tools.test_function = struct();
tools.test_function.description = 'Test the generated function with sample values';
tools.test_function.input_schema = {'test_d', 'test_sigma0', 'test_k'};
tools.test_function.execute = @action_test_function;

% Tool 4: Fit Model
tools.fit_model = struct();
tools.fit_model.description = 'Fit Hall-Petch model to data using lsqcurvefit';
tools.fit_model.input_schema = {'initial_sigma0', 'initial_k'};
tools.fit_model.execute = @action_fit_model;

% Tool 5: Validate Fit
tools.validate_fit = struct();
tools.validate_fit.description = 'Calculate R-squared and fit quality metrics';
tools.validate_fit.input_schema = {};
tools.validate_fit.execute = @action_validate_fit;

% Tool 6: Create Plots
tools.create_plots = struct();
tools.create_plots.description = 'Create comprehensive visualization plots';
tools.create_plots.input_schema = {};  % No required inputs - saves plots automatically
tools.create_plots.execute = @action_create_plots;

% Tool 7: Debug Environment
tools.debug_env = struct();
tools.debug_env.description = 'Debug workspace environment for plotting';
tools.debug_env.input_schema = {'force_recreate'};
tools.debug_env.execute = @action_debug_env;

% Tool 8: Export Results
tools.export_results = struct();
tools.export_results.description = 'Export fitted parameters and metrics';
tools.export_results.input_schema = {'format', 'filename'};
tools.export_results.execute = @action_export_results;

% Tool 9: Finalize
tools.finalize = struct();
tools.finalize.description = 'Complete the task and show final results';
tools.finalize.input_schema = {};
tools.finalize.execute = @action_finalize;

%% Initialize Agent State
agent_state = struct();
agent_state.complete = false;
agent_state.iteration = 0;
agent_state.max_iterations = 15;
agent_state.filename = full_data_path;  % Now uses the dynamic path
agent_state.context = 'Task: Load Hall-Petch data and fit the model to the Hall-Petch equation';

% Data state
agent_state.data = struct('loaded', false, 'd', [], 'sigy', [], 'shape', [], 'filename', '');

% Function state (MUST come from LLM)
agent_state.function = struct('ready', false, 'source', 'none', 'func_str', '', 'test_passed', false);

% Model state
agent_state.model = struct('fitted', false, 'sigma0', NaN, 'k', NaN, 'resnorm', NaN, 'exitflag', NaN);

% Validation state
agent_state.validation = struct('rsquared', NaN, 'rmse', NaN, 'residuals', []);

% History
agent_state.history = {};

fprintf('\n=== Autonomous Fitting Agent ===\n');
fprintf('Task: Fit Hall-Petch model to data\n');
fprintf('Data file: %s\n', agent_state.filename);
fprintf('Available tools: %s\n\n', strjoin(fieldnames(tools)', ', '));

%% Check if data file exists
if ~exist(agent_state.filename, 'file')
    fprintf('\n!!! WARNING: Data file not found at: %s\n', agent_state.filename);
    fprintf('Please ensure the file "%s" is in the same folder as this script.\n', DATA_FILENAME);
    fprintf('Current script location: %s\n', script_dir);
    fprintf('Looking for file: %s\n', full_data_path);
    fprintf('\nPress any key to continue with simulation (will fail)...\n');
    pause;
end

%% Main ReAct Loop
while ~agent_state.complete && agent_state.iteration < agent_state.max_iterations
    agent_state.iteration = agent_state.iteration + 1;
    
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('ITERATION %d\n', agent_state.iteration);
    fprintf('%s\n', repmat('=', 1, 60));
    
    %% Step 1: LLM THINKS and chooses ACTION
    thought_action = get_llm_decision(ai_model, agent_state);
    
    % Parse the response
    [thought, action_json] = parse_react_response(thought_action);
    
    fprintf('\nTHOUGHT: %s\n', thought);
    fprintf('ACTION: %s\n', action_json);
    
    %% Step 2: Parse the structured action
    try
        action = jsondecode(action_json);
        tool_name = action.tool;
        tool_input = action.input;
        
        % Validate tool exists
        if ~isfield(tools, tool_name)
            error('Unknown tool: %s', tool_name);
        end
        
        fprintf('Executing tool: %s\n', tool_name);
        
    catch ME
        observation = sprintf('Failed to parse action: %s. Action must be valid JSON with "tool" and "input" fields.', ME.message);
        fprintf('\nOBSERVATION: %s\n', observation);
        
        % Record in history
        agent_state = record_history(agent_state, thought, action_json, observation, false);
        continue;
    end
    
    %% Step 3: Execute the tool
    try
        [result, agent_state] = tools.(tool_name).execute(tool_input, agent_state);
        observation = result.message;
        success = true;
        
        fprintf('\nOBSERVATION: %s\n', observation);
        
        % Update agent state based on tool results
        agent_state = update_state_from_result(agent_state, tool_name, result);
        
    catch ME
        observation = sprintf('ERROR: %s', ME.message);
        fprintf('\nOBSERVATION: %s\n', observation);
        success = false;
        
        % If function generation fails, agent will halt (no fallback)
        if strcmp(tool_name, 'generate_function')
            fprintf('\n*** CRITICAL ERROR: LLM failed to generate Hall-Petch equation. ***\n');
            fprintf('*** No fallback provided - agent cannot continue. ***\n');
            error('Hall-Petch equation generation failed - no fallback available');
        end
    end
    
    %% Step 4: Record in history
    agent_state = record_history(agent_state, thought, action_json, observation, success);
    
    %% Step 5: Check if complete
    if strcmp(tool_name, 'finalize') && success
        agent_state.complete = true;
        fprintf('\n*** Task Complete! ***\n');
    end
end

%% Final Summary
fprintf('\n%s\n', repmat('=', 1, 60));
fprintf('AGENT COMPLETED\n');
fprintf('%s\n', repmat('=', 1, 60));
fprintf('Total iterations: %d\n', agent_state.iteration);

if agent_state.model.fitted
    fprintf('\n=== FINAL RESULTS ===\n');
    fprintf('σ₀ = %.4f MPa\n', agent_state.model.sigma0);
    fprintf('k = %.4f MPa·μm^0.5\n', agent_state.model.k);
    fprintf('R² = %.4f\n', agent_state.validation.rsquared);
    fprintf('RMSE = %.4f MPa\n', agent_state.validation.rmse);
    fprintf('Equation source: %s\n', agent_state.function.source);
    fprintf('Equation: σ = %.4f + %.4f * d^(-0.5)\n', ...
        agent_state.model.sigma0, agent_state.model.k);
else
    fprintf('\nWARNING: Model fitting was not completed.\n');
end

fprintf('\n=== REASONING TRACE (%d steps) ===\n', length(agent_state.history));
for i = 1:length(agent_state.history)
    fprintf('\n--- Step %d ---\n', i);
    fprintf('THOUGHT: %s\n', agent_state.history{i}.thought);
    fprintf('ACTION: %s\n', agent_state.history{i}.action);
    fprintf('RESULT: %s\n', agent_state.history{i}.observation);
end

%% ==================== Core ReAct Functions ====================

function response = get_llm_decision(model, agent_state)
    % Build prompt with current state and history
    prompt = build_react_prompt(agent_state);
    
    % Get LLM response
    response = generate(model, prompt);
    response = strtrim(string(response));
end

function prompt = build_react_prompt(agent_state)
    % Build prompt with explicit filename
    prompt = [ ...
        'You are a ReAct agent for Hall-Petch data fitting.\n\n' ...
        'TASK: ' agent_state.context '\n\n' ...
        'The data file is located at: ' agent_state.filename '\n' ...
        'IMPORTANT: Use this EXACT filename when calling load_data.\n\n' ...
        'AVAILABLE TOOLS:\n' ...
        '- load_data: Load CSV file (input: {"filename": "path"})\n' ...
        '- generate_function: Generate Hall-Petch equation via LLM (input: {})\n' ...
        '  *** CRITICAL: This MUST generate a valid Hall-Petch equation. No fallback exists. ***\n' ...
        '- test_function: Test generated function (input: {"test_d": [values], "test_sigma0": val, "test_k": val})\n' ...
        '- fit_model: Fit model to data (input: {"initial_sigma0": val, "initial_k": val})\n' ...
        '- validate_fit: Calculate fit metrics (input: {})\n' ...
        '- create_plots: Create comprehensive visualization (3 plots: original, linearized, residuals) (input: {} - no inputs needed)\n' ...
        '- debug_env: Debug workspace (input: {"force_recreate": true/false})\n' ...
        '- export_results: Export results (input: {"format": "table/struct/text", "filename": "name"})\n' ...
        '- finalize: Complete task (input: {})\n\n' ...
        'CURRENT STATE:\n'];
    
    if agent_state.data.loaded
        prompt = [prompt sprintf('- Data loaded: %d points\n', length(agent_state.data.d))];
        prompt = [prompt sprintf('  d range: [%.2f, %.2f] μm\n', min(agent_state.data.d), max(agent_state.data.d))];
        prompt = [prompt sprintf('  σ range: [%.2f, %.2f] MPa\n', min(agent_state.data.sigy), max(agent_state.data.sigy))];
    else
        prompt = [prompt '- Data not loaded yet\n'];
        prompt = [prompt sprintf('  Please load data from: %s\n', agent_state.filename)];
    end
    
    if agent_state.function.ready
        prompt = [prompt sprintf('- Function ready (from %s)\n', agent_state.function.source)];
        if agent_state.function.test_passed
            prompt = [prompt '  Function test: PASSED\n'];
        end
    else
        prompt = [prompt '- Function not generated yet\n'];
        prompt = [prompt '  *** MUST generate function from LLM - no default provided ***\n'];
    end
    
    if agent_state.model.fitted
        prompt = [prompt sprintf('- Model fitted: σ₀=%.2f, k=%.2f\n', ...
            agent_state.model.sigma0, agent_state.model.k)];
    end
    
    if ~isnan(agent_state.validation.rsquared)
        prompt = [prompt sprintf('- Validated: R²=%.4f, RMSE=%.2f\n', ...
            agent_state.validation.rsquared, agent_state.validation.rmse)];
    end
    
    % Recent history
    if ~isempty(agent_state.history)
        prompt = [prompt '\nRECENT HISTORY (last 3 steps):\n'];
        start_idx = max(1, length(agent_state.history) - 2);
        for i = start_idx:length(agent_state.history)
            h = agent_state.history{i};
            prompt = [prompt sprintf('Step %d: %s -> %s\n', i, h.action_preview, h.result_preview)];
        end
    end
    
    % Instruction
    prompt = [prompt ...
        '\nBased on current state and history, what should you do next?\n' ...
        'Remember: Use the EXACT filename provided above when calling load_data.\n' ...
        'IMPORTANT: generate_function MUST produce a valid Hall-Petch equation. No fallback exists.\n' ...
        'Respond in EXACT format:\n' ...
        'THOUGHT: <your reasoning>\n' ...
        'ACTION: {"tool": "<tool_name>", "input": <json_object>}\n'];
end

function [thought, action_json] = parse_react_response(response)
    % Parse the LLM response into thought and action JSON
    response = char(response);
    
    % Extract THOUGHT
    thought_pattern = 'THOUGHT:\s*(.*?)(?=ACTION:|$)';
    thought_tokens = regexp(response, thought_pattern, 'tokens', 'once');
    if ~isempty(thought_tokens)
        thought = strtrim(thought_tokens{1});
    else
        thought = "No thought provided";
    end
    
    % Extract ACTION JSON
    action_pattern = 'ACTION:\s*(\{.*\})';
    action_tokens = regexp(response, action_pattern, 'tokens', 'once');
    if ~isempty(action_tokens)
        action_json = strtrim(action_tokens{1});
    else
        % Try to find any JSON object
        json_pattern = '\{.*"tool".*\}';
        action_tokens = regexp(response, json_pattern, 'match', 'once');
        if ~isempty(action_tokens)
            action_json = action_tokens;
        else
            % Default to load_data if nothing found
            action_json = '{"tool": "load_data", "input": {}}';
        end
    end
    
    % Clean up the JSON
    action_json = regexprep(action_json, '\s+', ' ');
end

function agent_state = record_history(agent_state, thought, action, observation, success)
    % Create preview versions for context
    if length(action) > 50
        action_preview = [action(1:47), '...'];
    else
        action_preview = action;
    end
    
    if length(observation) > 50
        result_preview = [observation(1:47), '...'];
    else
        result_preview = observation;
    end
    
    % Create history entry
    history_entry = struct();
    history_entry.thought = char(thought);
    history_entry.action = char(action);
    history_entry.observation = char(observation);
    history_entry.action_preview = char(action_preview);
    history_entry.result_preview = char(result_preview);
    history_entry.success = success;
    history_entry.timestamp = datestr(now);
    
    % Append to history
    if isempty(agent_state.history)
        agent_state.history = {history_entry};
    else
        agent_state.history{end+1} = history_entry;
    end
end

function agent_state = update_state_from_result(agent_state, tool_name, result)
    % Update agent state based on tool execution results
    if result.success
        switch tool_name
            case 'load_data'
                agent_state.data.loaded = true;
                if isfield(result.metadata, 'd')
                    agent_state.data.d = result.metadata.d;
                    agent_state.data.sigy = result.metadata.sigy;
                end
            
            case 'generate_function'
                agent_state.function.ready = result.metadata.test_passed;
                agent_state.function.source = result.metadata.source;
                agent_state.function.func_str = result.metadata.func_str;
                agent_state.function.test_passed = result.metadata.test_passed;
            
            case 'fit_model'
                agent_state.model.fitted = true;
                agent_state.model.sigma0 = result.metadata.sigma0;
                agent_state.model.k = result.metadata.k;
                agent_state.model.resnorm = result.metadata.resnorm;
            
            case 'validate_fit'
                agent_state.validation.rsquared = result.metadata.rsquared;
                agent_state.validation.rmse = result.metadata.rmse;
        end
    end
end

%% ==================== Tool Implementation Functions ====================

function [result, agent_state] = action_load_data(input, agent_state)
    result = struct();
    
    try
        % Get filename from input or agent_state
        if isstruct(input) && isfield(input, 'filename')
            filename = input.filename;
        else
            filename = agent_state.filename;
        end
        
        fprintf('Attempting to load data from: %s\n', filename);
        
        % Load data
        data = readmatrix(filename);
        data = rmmissing(data); % Remove NaN rows
        
        d = data(:, 1);
        sigy = data(:, 2);
        
        % Update agent state
        agent_state.data.loaded = true;
        agent_state.data.d = d;
        agent_state.data.sigy = sigy;
        agent_state.data.shape = size(data);
        agent_state.data.filename = filename;
        
        % Store in base workspace
        assignin('base', 'agent_d', d);
        assignin('base', 'agent_sigy', sigy);
        
        % Result
        result.success = true;
        result.message = sprintf('Loaded %d data points. d range: [%.2f, %.2f] μm, σ range: [%.2f, %.2f] MPa', ...
            length(d), min(d), max(d), min(sigy), max(sigy));
        result.metadata = struct('d', d, 'sigy', sigy, 'n_points', length(d));
        
    catch ME
        result.success = false;
        result.message = sprintf('Failed to load data: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

%% REDESIGNED: Function generation with proper context 
function [result, agent_state] = action_generate_function(~, agent_state)
    result = struct();
    
    try
        % Create a model instance for equation generation
        equation_model = openAIChat( ...
            'You are a materials science expert who knows the Hall-Petch relationship.', ...
            ModelName="gpt-4", ...
            Temperature=0.1);
        
        % Get data range for context if available
        if agent_state.data.loaded
            d_min = min(agent_state.data.d);
            d_max = max(agent_state.data.d);
            sigy_min = min(agent_state.data.sigy);
            sigy_max = max(agent_state.data.sigy);
            data_context = sprintf('The data shows yield strength σ ranging from %.1f to %.1f MPa for grain sizes d from %.3f to %.3f μm.', ...
                sigy_min, sigy_max, d_min, d_max);
        else
            data_context = 'The data will be loaded separately.';
        end
        
        %% STEP 1: Ask LLM for the Hall-Petch equation form
        equation_prompt = [ ...
            'What is the Hall-Petch equation that relates yield strength (σ) to grain size (d)?\n\n' ...
            'Provide the equation in this format:\n' ...
            'σ = [expression with parameters]\n\n' ...
            'Include:\n' ...
            '- The physical meaning of each parameter\n' ...
            '- The units (MPa for σ, μm for d)\n' ...
            '- The typical exponent for d\n\n' ...
            'Output ONLY the equation and parameter definitions, no other text.'];
        
        fprintf('Asking LLM for Hall-Petch equation form...\n');
        equation_form = generate(equation_model, equation_prompt);
        equation_form = strtrim(string(equation_form));
        
        fprintf('✓ Received equation form:\n%s\n', equation_form);
        
        %% STEP 2: Create a code generator model
        code_model = openAIChat( ...
            'You are a MATLAB code generator. You output ONLY valid MATLAB code.', ...
            ModelName="gpt-4", ...
            Temperature=0.1);
        
        %% STEP 3: Ask LLM to convert to MATLAB function
        code_prompt = [ ...
            'Based on this Hall-Petch equation:\n\n' ...
            char(equation_form) '\n\n' ...
            'Create a MATLAB anonymous function that implements this equation.\n\n' ...
            'Context from data:\n' ...
            data_context '\n\n' ...
            'REQUIREMENTS:\n' ...
            '1. Function name must be: yield_strength\n' ...
            '2. Input parameters must be: (d, sigma_0, k) where:\n' ...
            '   - d = grain diameter (μm)\n' ...
            '   - sigma_0 = friction stress (MPa)\n' ...
            '   - k = Hall-Petch constant (MPa·μm^0.5)\n' ...
            '3. Use element-wise operations (.*, ./, .^)\n' ...
            '4. Convert the mathematical form you provided into valid MATLAB syntax\n' ...
            '   Remember: In MATLAB, exponents use .^ for element-wise power\n' ...
            '5. Output EXACTLY ONE LINE of MATLAB code:\n' ...
            'yield_strength = @(d, sigma_0, k) ...\n\n' ...
            'No explanations, no markdown, no backticks, no comments - just the code line.'];
        
        fprintf('Converting to MATLAB function...\n');
        response = generate(code_model, code_prompt);
        response = strtrim(string(response));
        
        % Clean response with improved function
        func_str = clean_matlab_response(response);
        
        % Verify we got valid MATLAB
        if isempty(func_str) || ~contains(func_str, 'yield_strength') || ~contains(func_str, '@(')
            fprintf('\n=== LLM DEBUG OUTPUT ===\n');
            fprintf('Raw response:\n%s\n', response);
            fprintf('Cleaned to: "%s"\n', func_str);
            fprintf('========================\n\n');
            error('LLM failed to output valid MATLAB function');
        end
        
        % Ensure semicolon
        if ~endsWith(strtrim(func_str), ';')
            func_str = [strtrim(func_str), ';'];
        end
        
        %% STEP 4: Test the function with comprehensive validation
        try
            eval(func_str);
            
            % Test with multiple d values
            test_d = [0.01, 0.05, 0.1, 0.2];
            test_sigma0 = 200;
            test_k = 100;
            test_result = yield_strength(test_d, test_sigma0, test_k);
            
            % Validate results
            if isempty(test_result) || any(isnan(test_result)) || any(~isfinite(test_result))
                error('Function returned invalid values');
            end
            
            % Check that the function has the correct Hall-Petch form
            % Should be decreasing with increasing d
            if ~all(diff(test_result) < 0)
                fprintf('Warning: Function does not monotonically decrease with d\n');
            end
            
            % Check if exponent is approximately -0.5 by comparing ratio
            if length(test_d) >= 2
                ratio1 = (test_result(1) - test_sigma0) / (test_result(2) - test_sigma0);
                ratio2 = (test_d(1)/test_d(2))^(-0.5);
                if abs(ratio1 - ratio2) > 0.1
                    fprintf('Warning: Exponent may not be -0.5 (ratio: %.3f vs expected %.3f)\n', ratio1, ratio2);
                end
            end
            
            fprintf('✓ Function test passed\n');
            test_passed = true;
            
        catch test_err
            error('Function test failed: %s\nFunction was: %s', test_err.message, func_str);
        end
        
        % Store in workspace
        evalin('base', func_str);
        assignin('base', 'agent_func_str', func_str);
        assignin('base', 'agent_equation_form', equation_form);
        
        % Update state
        agent_state.function.ready = true;
        agent_state.function.source = 'LLM generated from knowledge';
        agent_state.function.func_str = func_str;
        agent_state.function.test_passed = test_passed;
        
        result.success = true;
        result.message = sprintf('LLM generated: %s\nBased on equation: %s', func_str, equation_form);
        result.metadata = struct('func_str', func_str, 'test_passed', test_passed, ...
            'source', 'LLM knowledge', 'equation_form', equation_form);
        
    catch ME
        result.success = false;
        result.message = sprintf('FAILED: %s', ME.message);
        result.metadata = struct();
        
        fprintf('\n*** AGENT HALTED: LLM failed to generate Hall-Petch equation ***\n');
        fprintf('Error: %s\n', ME.message);
        fprintf('This is a pure test - no fallback provided.\n\n');
        rethrow(ME);
    end
end

%% Clean response helper - FIXED VERSION
function clean = clean_matlab_response(raw)
    raw = char(raw);
    
    % Remove everything before the first 'yield_strength' if it exists
    idx = strfind(raw, 'yield_strength');
    if ~isempty(idx)
        raw = raw(idx(1):end);
    end
    
    % Split into lines - using proper MATLAB string splitting
    lines = strsplit(raw, newline_char());
    
    % Find the first line that looks like our function
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if contains(line, 'yield_strength') && contains(line, '@(') && ...
           contains(line, 'd') && contains(line, 'sigma_0') && contains(line, 'k')
            clean = line;
            % Remove any trailing comments or extra text
            comment_idx = strfind(clean, '%');
            if ~isempty(comment_idx)
                clean = clean(1:comment_idx(1)-1);
            end
            % Ensure it ends with semicolon
            if ~endsWith(strtrim(clean), ';')
                clean = [strtrim(clean), ';'];
            end
            return;
        end
    end
    
    % Try to extract any anonymous function
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if contains(line, '@(') && (contains(line, 'd') || contains(line, 'sigma') || contains(line, 'k'))
            % Check if it has the Hall-Petch form (should have exponent/division)
            if contains(line, '^') || contains(line, './') || contains(line, '.^') || contains(line, 'sqrt')
                clean = sprintf('yield_strength = %s;', line);
                % Remove any trailing comments
                comment_idx = strfind(clean, '%');
                if ~isempty(comment_idx)
                    clean = clean(1:comment_idx(1)-1);
                end
                return;
            end
        end
    end
    
    % If we still haven't found it, try a more aggressive approach
    % Look for any line with mathematical operations that might be the function
    for i = 1:length(lines)
        line = strtrim(lines{i});
        % Check if it contains typical Hall-Petch elements (d, sigma, k, operations)
        if (contains(line, 'd') || contains(line, 'sigma')) && ...
           (contains(line, '+') || contains(line, '-')) && ...
           (contains(line, '^') || contains(line, './') || contains(line, '.^') || contains(line, 'sqrt'))
            % Extract just the mathematical expression
            clean = sprintf('yield_strength = @(d, sigma_0, k) %s;', line);
            return;
        end
    end
    
    % Last resort - if we see a line with d^(-0.5) or similar, create the function
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if contains(line, 'd') && (contains(line, '^(-0.5)') || contains(line, '.^(-0.5)') || contains(line, '^0.5') || contains(line, 'sqrt'))
            clean = sprintf('yield_strength = @(d, sigma_0, k) %s;', line);
            return;
        end
    end
    
    clean = '';
end

%% Helper function for newline character
function nl = newline_char()
    nl = char(10);
end

function [result, agent_state] = action_test_function(input, agent_state)
    result = struct();
    
    try
        % Get test values
        if isstruct(input) && isfield(input, 'test_d')
            test_d = input.test_d;
        else
            test_d = [0.01, 0.05, 0.1, 0.2];
        end
        
        if isstruct(input) && isfield(input, 'test_sigma0')
            test_sigma0 = input.test_sigma0;
        else
            test_sigma0 = 200;
        end
        
        if isstruct(input) && isfield(input, 'test_k')
            test_k = input.test_k;
        else
            test_k = 100;
        end
        
        % Get function
        if ~evalin('base', 'exist(''yield_strength'', ''var'')')
            evalin('base', agent_state.function.func_str);
        end
        
        yield_strength = evalin('base', 'yield_strength');
        test_result = yield_strength(test_d, test_sigma0, test_k);
        
        result.success = true;
        result.message = sprintf('Test passed. Output: [%s]', num2str(test_result, '%.2f '));
        result.metadata = struct('test_output', test_result);
        
        agent_state.function.test_passed = true;
        agent_state.function.ready = true;
        
    catch ME
        result.success = false;
        result.message = sprintf('Test failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_fit_model(input, agent_state)
    result = struct();
    
    try
        d = agent_state.data.d;
        sigy = agent_state.data.sigy;
        
        % Get function
        if ~evalin('base', 'exist(''yield_strength'', ''var'')')
            evalin('base', agent_state.function.func_str);
        end
        yield_strength = evalin('base', 'yield_strength');
        
        % Initial guess
        if isstruct(input) && isfield(input, 'initial_sigma0') && isfield(input, 'initial_k')
            p0 = [input.initial_sigma0, input.initial_k];
        else
            % Reasonable initial guess based on data
            p0 = [min(sigy), (max(sigy) - min(sigy)) * mean(d.^(-0.5))];
        end
        
        % Fit
        fit_func = @(p, d) yield_strength(d, p(1), p(2));
        [p_opt, resnorm, ~, exitflag] = lsqcurvefit(fit_func, p0, d, sigy, [0,0], [Inf,Inf], ...
            optimoptions('lsqcurvefit', 'Display', 'off'));
        
        % Update state
        agent_state.model.fitted = (exitflag > 0);
        agent_state.model.sigma0 = p_opt(1);
        agent_state.model.k = p_opt(2);
        agent_state.model.resnorm = resnorm;
        
        assignin('base', 'agent_sig0', p_opt(1));
        assignin('base', 'agent_k', p_opt(2));
        
        result.success = true;
        result.message = sprintf('Fit complete: σ₀=%.4f, k=%.4f, resnorm=%.4f', ...
            p_opt(1), p_opt(2), resnorm);
        result.metadata = struct('sigma0', p_opt(1), 'k', p_opt(2), 'resnorm', resnorm);
        
    catch ME
        result.success = false;
        result.message = sprintf('Fitting failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_validate_fit(~, agent_state)
    result = struct();
    
    try
        d = agent_state.data.d;
        sigy = agent_state.data.sigy;
        sig0 = agent_state.model.sigma0;
        k = agent_state.model.k;
        
        % Get function
        if ~evalin('base', 'exist(''yield_strength'', ''var'')')
            evalin('base', agent_state.function.func_str);
        end
        yield_strength = evalin('base', 'yield_strength');
        
        % Calculate predictions and metrics
        sigy_pred = yield_strength(d, sig0, k);
        ss_res = sum((sigy - sigy_pred).^2);
        ss_tot = sum((sigy - mean(sigy)).^2);
        rsquared = 1 - ss_res/ss_tot;
        rmse = sqrt(mean((sigy - sigy_pred).^2));
        
        % Update state
        agent_state.validation.rsquared = rsquared;
        agent_state.validation.rmse = rmse;
        agent_state.validation.residuals = sigy - sigy_pred;
        
        result.success = true;
        result.message = sprintf('Validation: R²=%.4f, RMSE=%.4f MPa', rsquared, rmse);
        result.metadata = struct('rsquared', rsquared, 'rmse', rmse);
        
    catch ME
        result.success = false;
        result.message = sprintf('Validation failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_create_plots(~, agent_state)
    result = struct();
    
    try
        % Close any existing figure windows to prevent accumulation
        close all;
        
        % Get data and parameters from agent state
        d = agent_state.data.d;
        sigy = agent_state.data.sigy;
        sig0 = agent_state.model.sigma0;
        k = agent_state.model.k;
        
        % Validate data
        if isempty(d) || isempty(sigy)
            error('No data available for plotting');
        end
        
        if isnan(sig0) || isnan(k)
            error('Model parameters not available - run fit_model first');
        end
        
        % Get function
        if ~evalin('base', 'exist(''yield_strength'', ''var'')')
            evalin('base', agent_state.function.func_str);
        end
        yield_strength = evalin('base', 'yield_strength');
        
        % Create grid for fitted curve
        dgrid = linspace(min(d), max(d), 200)';
        
        % Calculate fitted values
        sigy_fit = yield_strength(dgrid, sig0, k);
        
        % Transform data for linearized plot
        d_transformed = d.^(-0.5);
        dgrid_transformed = dgrid.^(-0.5);
        
        %% Plot 1: Original and Linearized space (subplots)
        fig1 = figure('Position', [100, 100, 1200, 500], 'Name', 'Hall-Petch Fitting Results');
        
        % Original space subplot
        subplot(1, 2, 1);
        plot(d, sigy, 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'b', 'DisplayName', 'Data'); 
        hold on;
        plot(dgrid, sigy_fit, '-r', 'LineWidth', 2, 'DisplayName', 'LLM-Generated Fit');
        xlabel('Grain diameter, d [mm]'); 
        ylabel('Yield strength, σ [MPa]'); 
        grid on; 
        legend('Location', 'best');
        title('Hall-Petch Relationship: Original Space');
        
        % Add equation to plot
        eq_text = sprintf('σ = %.2f + %.2f · d^{-0.5}', sig0, k);
        text(0.05, 0.95, eq_text, 'Units', 'normalized', 'FontSize', 11, ...
             'BackgroundColor', 'white', 'VerticalAlignment', 'top', 'EdgeColor', 'black');
        
        % Linearized space subplot
        subplot(1, 2, 2);
        plot(d_transformed, sigy, 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'b', 'DisplayName', 'Data'); 
        hold on;
        plot(dgrid_transformed, sigy_fit, '-r', 'LineWidth', 2, 'DisplayName', 'Linear Fit');
        xlabel('d^{-0.5} [mm^{-0.5}]'); 
        ylabel('Yield strength, σ [MPa]'); 
        grid on; 
        legend('Location', 'best');
        title('Hall-Petch Relationship: Linearized Form');
        
        % Add slope/intercept info
        text(0.95, 0.05, sprintf('Slope (k) = %.2f\nIntercept (σ₀) = %.2f', k, sig0), ...
            'Units', 'normalized', 'FontSize', 10, 'BackgroundColor', 'white', ...
            'EdgeColor', 'black', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right', ...
            'Margin', 5);
        
        % Add R² value
        text(0.05, 0.85, sprintf('R² = %.4f', agent_state.validation.rsquared), ...
            'Units', 'normalized', 'FontSize', 10, 'BackgroundColor', 'white', ...
            'EdgeColor', 'black', 'VerticalAlignment', 'top');
        
        %% Plot 2: Residuals (separate figure)
        fig2 = figure('Position', [100, 650, 800, 400], 'Name', 'Residual Analysis');
        
        % Calculate residuals
        sigy_pred_full = yield_strength(d, sig0, k);
        residuals = sigy - sigy_pred_full;
        
        plot(d_transformed, residuals, 'o', 'MarkerSize', 6, 'MarkerFaceColor', 'r', ...
            'MarkerEdgeColor', 'r', 'DisplayName', 'Residuals');
        hold on;
        yline(0, '--k', 'LineWidth', 1.5, 'DisplayName', 'Zero Line');
        xlabel('d^{-0.5} [mm^{-0.5}]');
        ylabel('Residuals [MPa]');
        title('Residual Plot in Linearized Space');
        legend('Location', 'best');
        grid on;
        
        % Add residual statistics
        res_mean = mean(residuals);
        res_std = std(residuals);
        res_text = sprintf('Mean = %.4f MPa\nStd Dev = %.4f MPa\nRMSE = %.4f MPa', ...
            res_mean, res_std, agent_state.validation.rmse);
        
        text(0.05, 0.95, res_text, 'Units', 'normalized', 'FontSize', 10, ...
            'BackgroundColor', 'white', 'EdgeColor', 'black', ...
            'VerticalAlignment', 'top', 'Margin', 5);
        
        % Force figure update
        drawnow;
        
        result.success = true;
        result.message = sprintf('Created 2 figures with 3 plots total. Figure %d: Original+Linearized, Figure %d: Residuals', ...
            fig1.Number, fig2.Number);
        result.metadata = struct('figure1', fig1.Number, 'figure2', fig2.Number);
        
    catch ME
        result.success = false;
        result.message = sprintf('Plotting failed: %s', ME.message);
        result.metadata = struct();
        % Don't rethrow - let agent continue
        fprintf('Warning: Plotting failed but agent can continue: %s\n', ME.message);
    end
end

function [result, agent_state] = action_debug_env(input, agent_state)
    result = struct();
    
    try
        % Ensure function exists - but ONLY from stored LLM function
        if ~evalin('base', 'exist(''yield_strength'', ''var'')')
            if ~isempty(agent_state.function.func_str)
                evalin('base', agent_state.function.func_str);
                source = 'recreated from stored LLM function';
            else
                error('No Hall-Petch function available. Must run generate_function first.');
            end
        else
            source = 'already exists';
        end
        
        result.success = true;
        result.message = sprintf('Debug complete: function %s', source);
        result.metadata = struct('source', source);
        
    catch ME
        result.success = false;
        result.message = sprintf('Debug failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_export_results(input, agent_state)
    result = struct();
    
    try
        format = 'table';
        filename = 'hall_petch_results.mat';
        
        if isstruct(input)
            if isfield(input, 'format')
                format = input.format;
            end
            if isfield(input, 'filename')
                filename = input.filename;
            end
        end
        
        % Create results structure
        results = struct();
        results.sigma0 = agent_state.model.sigma0;
        results.k = agent_state.model.k;
        results.rsquared = agent_state.validation.rsquared;
        results.rmse = agent_state.validation.rmse;
        results.function_source = agent_state.function.source;
        results.function_str = agent_state.function.func_str;
        results.generation_date = datestr(now);
        results.n_data_points = length(agent_state.data.d);
        
        save(filename, 'results');
        
        result.success = true;
        result.message = sprintf('Results exported to %s', filename);
        result.metadata = struct('filename', filename, 'format', format);
        
    catch ME
        result.success = false;
        result.message = sprintf('Export failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_finalize(~, agent_state)
    result = struct();
    
    if agent_state.model.fitted
        result.success = true;
        result.message = sprintf([ ...
            'Task complete! Final model (from %s): σ = %.4f + %.4f * d^(-0.5)\n' ...
            'R² = %.4f, RMSE = %.4f MPa\n' ...
            '2 figures created: original+linearized (combined), and residuals\n' ...
            'Equation source: %s'], ...
            agent_state.function.source, ...
            agent_state.model.sigma0, agent_state.model.k, ...
            agent_state.validation.rsquared, agent_state.validation.rmse, ...
            agent_state.function.source);
        result.metadata = struct('sigma0', agent_state.model.sigma0, 'k', agent_state.model.k);
    else
        result.success = false;
        result.message = 'Cannot finalize: model not fitted yet';
        result.metadata = struct();
    end
end