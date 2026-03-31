%% Agent for Kuhn Equation Fitting - GPT-5 Version
% This version uses GPT-5 (reasoning model) which doesn't support temperature
% Modified to work with relative file paths - dataset should be in the same folder as this script

clc; clear; close all;

%% Get the script's directory and set up file paths
scriptDir = fileparts(which(mfilename('fullpath')));
datasetFile = fullfile(scriptDir, 'Kuhn_dataset.csv');

% Check if dataset exists
if ~exist(datasetFile, 'file')
    error('Dataset file not found in script directory: %s\nPlease ensure Kuhn_dataset.csv is in the same folder as this script.', datasetFile);
end

fprintf('Script directory: %s\n', scriptDir);
fprintf('Dataset location: %s\n', datasetFile);

%% Initialize AI Model for ReAct Reasoning
% GPT-5 reasoning models don't use temperature
ai_model = openAIChat([ ...
    'You are a ReAct agent that fits the HOMO-LUMO gap of helicenes data using Kuhn''s model. ' ...
    'At each step: 1) THINK about what to do next based on current state, ' ...
    '2) Choose an ACTION from available tools, 3) OBSERVE the result. '], ...
    'ModelName', 'gpt-5');

%% Initialize Tool Registry
tools = struct();

% Tool 1: Load Data
tools.load_data = struct();
tools.load_data.description = 'Load helicene dataset (n, gap in eV) and convert to Hartree';
tools.load_data.input_schema = {'filename'};
tools.load_data.execute = @action_load_data;

% Tool 2: Get Kuhn Equation from LLM knowledge
tools.get_kuhn_equation = struct();
tools.get_kuhn_equation.description = 'Get Kuhn equation from LLM knowledge (NO FALLBACK)';
tools.get_kuhn_equation.input_schema = {};
tools.get_kuhn_equation.execute = @action_get_kuhn_equation;

% Tool 3: Convert LaTeX to MATLAB
tools.convert_to_matlab = struct();
tools.convert_to_matlab.description = 'Convert LaTeX equation to MATLAB function';
tools.convert_to_matlab.input_schema = {};
tools.convert_to_matlab.execute = @action_convert_to_matlab;

% Tool 4: Test Function
tools.test_function = struct();
tools.test_function.description = 'Test the generated MATLAB function with sample N values';
tools.test_function.input_schema = {'test_N', 'test_v0'};
tools.test_function.execute = @action_test_function;

% Tool 5: Fit Model
tools.fit_model = struct();
tools.fit_model.description = 'Fit the model to data using lsqcurvefit';
tools.fit_model.input_schema = {'initial_v0'};
tools.fit_model.execute = @action_fit_model;

% Tool 6: Validate Fit
tools.validate_fit = struct();
tools.validate_fit.description = 'Calculate R² and other fit quality metrics';
tools.validate_fit.input_schema = {};
tools.validate_fit.execute = @action_validate_fit;

% Tool 7: Create Plots
tools.create_plots = struct();
tools.create_plots.description = 'Plot data and fitted curve';
tools.create_plots.input_schema = {};
tools.create_plots.execute = @action_create_plots;

% Tool 8: Finalize
tools.finalize = struct();
tools.finalize.description = 'Complete the task and show final results';
tools.finalize.input_schema = {};
tools.finalize.execute = @action_finalize;

%% Initialize Agent State
agent_state = struct();
agent_state.complete = false;
agent_state.iteration = 0;
agent_state.max_iterations = 15;

% File paths - now using relative path
agent_state.filename = datasetFile;
agent_state.context = 'Task: Load helicene data and fit Kuhn model using equation from LLM knowledge';

% Data state
agent_state.data = struct('loaded', false, 'n', [], 'gap_ev', [], 'gap_hartree', [], 'filename', '');

% Equation state (MUST come from LLM)
agent_state.equation = struct('ready', false, 'latex', '', 'func_str', '', 'source', 'none', 'test_passed', false);

% Model state
agent_state.model = struct('fitted', false, 'v0', NaN, 'v0_ev', NaN, 'resnorm', NaN, 'exitflag', NaN);

% Validation state
agent_state.validation = struct('rsquared', NaN, 'rmse_ev', NaN, 'residuals', []);

% History
agent_state.history = {};

fprintf('=== Pure ReAct Agent for Kuhn Equation Fitting (GPT-5) Started ===\n');
fprintf('Task: Fit Kuhn model to helicene data\n');
fprintf('Data file: %s\n', agent_state.filename);
fprintf('Available tools: %s\n\n', strjoin(fieldnames(tools)', ', '));
fprintf('*** NOTE: Kuhn equation MUST come from LLM knowledge - no extraction from paper ***\n\n');

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
        
        % If equation generation fails, agent will halt (no fallback)
        if strcmp(tool_name, 'get_kuhn_equation')
            fprintf('\n*** CRITICAL ERROR: LLM failed to provide Kuhn equation. ***\n');
            fprintf('*** No fallback provided - agent cannot continue. ***\n');
            error('Kuhn equation generation failed - no fallback available');
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
    fprintf('v₀ = %.6f hartree\n', agent_state.model.v0);
    fprintf('v₀ = %.6f eV\n', agent_state.model.v0_ev);
    fprintf('R² = %.4f\n', agent_state.validation.rsquared);
    fprintf('RMSE = %.4f eV\n', agent_state.validation.rmse_ev);
    fprintf('Equation source: %s\n', agent_state.equation.source);
    fprintf('Equation: %s\n', agent_state.equation.latex);
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
    
    % Get LLM response - GPT-5 doesn't use temperature
    response = generate(model, prompt);
    response = strtrim(string(response));
end

function prompt = build_react_prompt(agent_state)
    % Build prompt with relative path information
    [~, filename, ext] = fileparts(agent_state.filename);
    shortFilename = [filename, ext];
    
    prompt = [ ...
        'You are a ReAct agent for helicene HOMO-LUMO gap fitting using Kuhn''s model.\n\n' ...
        'TASK: ' agent_state.context '\n\n' ...
        'The data file is named: ' shortFilename '\n' ...
        'IMPORTANT: The file is located in the same folder as this script. ' ...
        'Use the load_data tool with an empty input, and the tool will automatically find the dataset.\n\n' ...
        'AVAILABLE TOOLS:\n' ...
        '- load_data: Load CSV file (input: {}) - automatically finds the dataset in the script folder\n' ...
        '- get_kuhn_equation: Get Kuhn equation from LLM knowledge (input: {})\n' ...
        '  *** CRITICAL: This MUST provide the correct Kuhn equation. No fallback exists. ***\n' ...
        '- convert_to_matlab: Convert LaTeX to MATLAB function (input: {})\n' ...
        '- test_function: Test generated function (input: {"test_N": [values], "test_v0": val})\n' ...
        '- fit_model: Fit model to data (input: {"initial_v0": val})\n' ...
        '- validate_fit: Calculate fit metrics (input: {})\n' ...
        '- create_plots: Create plots (input: {})\n' ...
        '- finalize: Complete task (input: {})\n\n' ...
        'CURRENT STATE:\n'];
    
    if agent_state.data.loaded
        prompt = [prompt sprintf('- Data loaded: %d points\n', length(agent_state.data.n))];
        prompt = [prompt sprintf('  n range: [%d, %d]\n', min(agent_state.data.n), max(agent_state.data.n))];
        prompt = [prompt sprintf('  Gap range: [%.3f, %.3f] eV\n', min(agent_state.data.gap_ev), max(agent_state.data.gap_ev))];
    else
        prompt = [prompt '- Data not loaded yet\n'];
        prompt = [prompt sprintf('  Dataset file is in script folder: %s\n', agent_state.filename)];
    end
    
    if ~isempty(agent_state.equation.latex)
        prompt = [prompt sprintf('- Equation (LaTeX): %s\n', agent_state.equation.latex)];
    end
    
    if agent_state.equation.ready
        prompt = [prompt sprintf('- MATLAB function ready (from %s)\n', agent_state.equation.source)];
        if agent_state.equation.test_passed
            prompt = [prompt '  Function test: PASSED\n'];
        end
    else
        prompt = [prompt '- MATLAB function not generated yet - use convert_to_matlab\n'];
    end
    
    if agent_state.model.fitted
        prompt = [prompt sprintf('- Model fitted: v₀=%.6f hartree (%.6f eV)\n', ...
            agent_state.model.v0, agent_state.model.v0_ev)];
    end
    
    if ~isnan(agent_state.validation.rsquared)
        prompt = [prompt sprintf('- Validated: R²=%.4f, RMSE=%.4f eV\n', ...
            agent_state.validation.rsquared, agent_state.validation.rmse_ev)];
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
        'The dataset file is in the same folder as the script. Use load_data with empty input to load it automatically.\n' ...
        'IMPORTANT: get_kuhn_equation MUST provide the correct Kuhn equation. No fallback exists.\n' ...
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
            % Default action with empty input
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
                if isfield(result.metadata, 'n')
                    agent_state.data.n = result.metadata.n;
                    agent_state.data.gap_ev = result.metadata.gap_ev;
                    agent_state.data.gap_hartree = result.metadata.gap_hartree;
                end
            
            case 'get_kuhn_equation'
                agent_state.equation.latex = result.metadata.latex;
                agent_state.equation.source = result.metadata.source;
            
            case 'convert_to_matlab'
                agent_state.equation.ready = result.metadata.test_passed;
                agent_state.equation.func_str = result.metadata.func_str;
                agent_state.equation.test_passed = result.metadata.test_passed;
            
            case 'fit_model'
                agent_state.model.fitted = true;
                agent_state.model.v0 = result.metadata.v0;
                agent_state.model.v0_ev = result.metadata.v0_ev;
                agent_state.model.resnorm = result.metadata.resnorm;
            
            case 'validate_fit'
                agent_state.validation.rsquared = result.metadata.rsquared;
                agent_state.validation.rmse_ev = result.metadata.rmse_ev;
                agent_state.validation.residuals = result.metadata.residuals;
        end
    end
end

%% ==================== Tool Implementation Functions ====================

function [result, agent_state] = action_load_data(input, agent_state)
    result = struct();
    
    try
        % Get filename from input or use the one stored in agent_state
        if isstruct(input) && isfield(input, 'filename') && ~isempty(input.filename)
            filename = input.filename;
        else
            filename = agent_state.filename;
        end
        
        fprintf('Attempting to load data from: %s\n', filename);
        
        % Check if file exists
        if ~exist(filename, 'file')
            error('Data file not found: %s\nPlease ensure Kuhn_dataset.csv is in the same folder as this script.', filename);
        end
        
        % Load data
        data = readmatrix(filename);
        data = rmmissing(data); % Remove NaN rows
        
        if size(data, 2) < 2
            error('Data file must contain at least 2 columns (n and gap)');
        end
        
        n = data(:, 1);
        gap_ev = data(:, 2);
        hat2ev = 27.2114;
        gap_hartree = gap_ev / hat2ev;
        
        % Update agent state
        agent_state.data.loaded = true;
        agent_state.data.n = n;
        agent_state.data.gap_ev = gap_ev;
        agent_state.data.gap_hartree = gap_hartree;
        agent_state.data.filename = filename;
        
        % Store in base workspace
        assignin('base', 'agent_n', n);
        assignin('base', 'agent_gap_hartree', gap_hartree);
        
        % Result
        result.success = true;
        result.message = sprintf('Loaded %d data points from %s. n range: [%d, %d], Gap range: [%.3f, %.3f] eV', ...
            length(n), filename, min(n), max(n), min(gap_ev), max(gap_ev));
        result.metadata = struct('n', n, 'gap_ev', gap_ev, 'gap_hartree', gap_hartree);
        
    catch ME
        result.success = false;
        result.message = sprintf('Failed to load data: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

%% Get Kuhn equation from LLM knowledge - GPT-5 version (no temperature)
function [result, agent_state] = action_get_kuhn_equation(~, agent_state)
    result = struct();
    
    try
        % Create model for getting equation - GPT-5 doesn't use temperature
        equation_model = openAIChat( ...
            'You are an expert on helicene physics and Kuhn''s model. You provide accurate equations in LaTeX format.', ...
            'ModelName', 'gpt-5');
        
        % Prompt for Kuhn's equation
        prompt = ['What is Kuhn''s equation for the HOMO-LUMO gap of helicenes? ' ...
            'Provide the equation in LaTeX format. ' ...
            'Include the definitions: N = 4n+2 is the number of π electrons, ' ...
            'L is the helical length, h is Planck''s constant, m is electron mass, ' ...
            'and V₀ is a fitting parameter. ' ...
            'Output ONLY the LaTeX equation, no explanations.'];
        
        fprintf('Asking LLM for Kuhn''s equation...\n');
        latex_eq = generate(equation_model, prompt);
        latex_eq = strtrim(string(latex_eq));
        
        % Basic validation
        if isempty(latex_eq) || (~contains(latex_eq, 'Delta') && ~contains(latex_eq, 'frac'))
            error('LLM did not provide a valid equation');
        end
        
        fprintf('✓ Received equation: %s\n', latex_eq);
        
        % Update state
        agent_state.equation.latex = latex_eq;
        agent_state.equation.source = 'LLM knowledge';
        
        result.success = true;
        result.message = sprintf('Got Kuhn equation: %s', latex_eq);
        result.metadata = struct('latex', latex_eq, 'source', 'LLM knowledge');
        
    catch ME
        result.success = false;
        result.message = sprintf('FAILED: %s', ME.message);
        result.metadata = struct();
        
        fprintf('\n*** CRITICAL ERROR: LLM failed to provide Kuhn equation ***\n');
        fprintf('Error: %s\n', ME.message);
        rethrow(ME);
    end
end

%% Convert LaTeX to MATLAB function - GPT-5 version (no temperature)
function [result, agent_state] = action_convert_to_matlab(~, agent_state)
    result = struct();
    
    try
        % Check if we have an equation
        if isempty(agent_state.equation.latex)
            error('No equation to convert. Run get_kuhn_equation first.');
        end
        
        % Create converter model - GPT-5 doesn't use temperature
        converter = openAIChat( ...
            'You convert physics equations to MATLAB code. You output ONLY valid MATLAB code. No explanations.', ...
            'ModelName', 'gpt-5');
        
        % Get data range for context
        if agent_state.data.loaded
            n_min = min(agent_state.data.n);
            n_max = max(agent_state.data.n);
        else
            n_min = 1;
            n_max = 10;
        end
        
        % Build prompt using simple concatenation
        prompt = [ ...
            'Convert this LaTeX equation for Kuhn''s model to a MATLAB anonymous function.\n\n' ...
            'EQUATION:\n' char(agent_state.equation.latex) '\n\n' ...
            'PHYSICAL CONTEXT:\n' ...
            '- N = number of π electrons = 4n+2, where n is helicene number (' num2str(n_min) ' to ' num2str(n_max) ')\n' ...
            '- L = helical length in bohr: L = ((3.*n+3).*1.4*1.88973)\n' ...
            '- In atomic units: hbar = 1, but h = 2π, and m = 1\n' ...
            '- Therefore h²/(8m) = (2π)²/8 = 4π²/8 = π²/2\n\n' ...
            'FUNCTION SIGNATURE:\n' ...
            'gap_model = @(v0, N)\n\n' ... 
            'REQUIREMENTS:\n' ...
            '1. Replace n with (N-2)/4\n' ...
            '2. Use element-wise operations (.*, ./, .^)\n' ...
            '3. Use pi^2/2 for the h²/(8m) factor\n' ...
            '4. Output EXACTLY ONE LINE of MATLAB code\n' ...
            '5. No markdown, no backticks, no extra text' ];
        
        fprintf('Converting to MATLAB...\n');
        response = generate(converter, prompt);
        response = strtrim(string(response));
        
        % Clean response
        func_str = clean_matlab_response(response);
        
        if isempty(func_str) || ~contains(func_str, 'gap_model') || ~contains(func_str, '@(')
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
        
        % Test the function
        try
            eval(func_str);
            test_N = [6, 10, 14, 18];
            test_v0 = 0.1;
            test_result = gap_model(test_v0, test_N);
            
            % Basic validation
            if isempty(test_result) || any(isnan(test_result)) || any(test_result <= 0)
                error('Function produced invalid values');
            end
            
            test_passed = true;
            fprintf('✓ Function test passed\n');
            
        catch test_err
            error('Function test failed: %s\nFunction was: %s', test_err.message, func_str);
        end
        
        % Store in workspace
        evalin('base', func_str);
        assignin('base', 'agent_func_str', func_str);
        
        % Update state
        agent_state.equation.ready = true;
        agent_state.equation.func_str = func_str;
        agent_state.equation.test_passed = true;
        
        result.success = true;
        result.message = sprintf('LLM generated: %s', func_str);
        result.metadata = struct('func_str', func_str, 'test_passed', true);
        
    catch ME
        result.success = false;
        result.message = sprintf('FAILED: %s', ME.message);
        result.metadata = struct();
        
        fprintf('\n*** CRITICAL ERROR: LLM failed to convert to MATLAB function ***\n');
        fprintf('Error: %s\n', ME.message);
        rethrow(ME);
    end
end

%% Clean MATLAB response helper
function clean = clean_matlab_response(raw)
    raw = char(raw);
    
    % Remove everything before the first 'gap_model' if it exists
    idx = strfind(raw, 'gap_model');
    if ~isempty(idx)
        raw = raw(idx(1):end);
    end
    
    % Split into lines
    lines = splitlines(raw);
    
    % Find the first line that looks like our function
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if contains(line, 'gap_model') && contains(line, '@(')
            clean = line;
            return;
        end
    end
    
    % Try to extract any anonymous function
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if contains(line, '@(') && (contains(line, 'v0') || contains(line, 'N'))
            clean = sprintf('gap_model = %s;', line);
            return;
        end
    end
    
    clean = '';
end

function [result, agent_state] = action_test_function(input, agent_state)
    result = struct();
    
    try
        % Get test values
        if isstruct(input) && isfield(input, 'test_N')
            test_N = input.test_N;
        else
            test_N = [6, 10, 14, 18];
        end
        
        if isstruct(input) && isfield(input, 'test_v0')
            test_v0 = input.test_v0;
        else
            test_v0 = 0.1;
        end
        
        % Get function
        if ~evalin('base', 'exist(''gap_model'', ''var'')')
            evalin('base', agent_state.equation.func_str);
        end
        
        gap_model = evalin('base', 'gap_model');
        test_result = gap_model(test_v0, test_N);
        
        result.success = true;
        result.message = sprintf('Test passed. Output: [%s]', num2str(test_result, '%.4e '));
        result.metadata = struct('test_output', test_result);
        
        agent_state.equation.test_passed = true;
        agent_state.equation.ready = true;
        
    catch ME
        result.success = false;
        result.message = sprintf('Test failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_fit_model(input, agent_state)
    result = struct();
    hat2ev = 27.2114;
    
    try
        N = agent_state.data.n(:) * 4 + 2;
        gap_hartree = agent_state.data.gap_hartree(:);
        
        % Get function
        if ~evalin('base', 'exist(''gap_model'', ''var'')')
            evalin('base', agent_state.equation.func_str);
        end
        gap_model = evalin('base', 'gap_model');
        
        % Initial guess
        if isstruct(input) && isfield(input, 'initial_v0')
            v0_initial = input.initial_v0;
        else
            v0_initial = 0.1;
        end
        
        % Fit
        fit_func = @(v0, N) gap_model(v0, N);
        [v0_opt, resnorm, ~, exitflag] = lsqcurvefit(fit_func, v0_initial, N, gap_hartree, [], [], ...
            optimoptions('lsqcurvefit', 'Display', 'off'));
        
        % Update state
        agent_state.model.fitted = (exitflag > 0);
        agent_state.model.v0 = v0_opt;
        agent_state.model.v0_ev = v0_opt * hat2ev;
        agent_state.model.resnorm = resnorm;
        
        assignin('base', 'agent_v0', v0_opt);
        
        result.success = true;
        result.message = sprintf('Fit complete: v₀ = %.6f hartree (%.6f eV), resnorm = %.4e', ...
            v0_opt, v0_opt*hat2ev, resnorm);
        result.metadata = struct('v0', v0_opt, 'v0_ev', v0_opt*hat2ev, 'resnorm', resnorm);
        
    catch ME
        result.success = false;
        result.message = sprintf('Fitting failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_validate_fit(~, agent_state)
    result = struct();
    hat2ev = 27.2114;
    
    try
        N = agent_state.data.n(:) * 4 + 2;
        gap_hartree = agent_state.data.gap_hartree(:);
        v0 = agent_state.model.v0;
        
        % Get function
        if ~evalin('base', 'exist(''gap_model'', ''var'')')
            evalin('base', agent_state.equation.func_str);
        end
        gap_model = evalin('base', 'gap_model');
        
        % Calculate predictions and metrics
        gap_pred_hartree = gap_model(v0, N);
        gap_pred_ev = gap_pred_hartree * hat2ev;
        gap_obs_ev = agent_state.data.gap_ev;
        
        ss_res = sum((gap_obs_ev - gap_pred_ev).^2);
        ss_tot = sum((gap_obs_ev - mean(gap_obs_ev)).^2);
        rsquared = 1 - ss_res/ss_tot;
        rmse_ev = sqrt(mean((gap_obs_ev - gap_pred_ev).^2));
        
        % Update state
        agent_state.validation.rsquared = rsquared;
        agent_state.validation.rmse_ev = rmse_ev;
        agent_state.validation.residuals = gap_obs_ev - gap_pred_ev;
        
        result.success = true;
        result.message = sprintf('Validation: R²=%.4f, RMSE=%.4f eV', rsquared, rmse_ev);
        result.metadata = struct('rsquared', rsquared, 'rmse_ev', rmse_ev, 'residuals', agent_state.validation.residuals);
        
    catch ME
        result.success = false;
        result.message = sprintf('Validation failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_create_plots(~, agent_state)
    result = struct();
    hat2ev = 27.2114;
    
    try
        % Close any existing figure windows
        close all;
        
        n = agent_state.data.n;
        gap_ev = agent_state.data.gap_ev;
        v0 = agent_state.model.v0;
        v0_ev = v0 * hat2ev;
        
        % Get function
        if ~evalin('base', 'exist(''gap_model'', ''var'')')
            evalin('base', agent_state.equation.func_str);
        end
        gap_model = evalin('base', 'gap_model');
        
        % Create grid for fitted curve
        N_fine = linspace(min(4*n+2), max(4*n+2), 200)';
        n_fine = (N_fine - 2) / 4;
        
        % Calculate fitted values
        gap_fitted_hartree = gap_model(v0, N_fine);
        gap_fitted_ev = gap_fitted_hartree * hat2ev;
        
        % Create figure
        figure('Position', [100, 100, 800, 600], 'Name', 'Kuhn Model Fit');
        
        plot(n, gap_ev, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', 'DFT(LDA) Data');
        hold on;
        plot(n_fine, gap_fitted_ev, 'b-', 'LineWidth', 2, 'DisplayName', sprintf('Fitted Kuhn Model (v₀ = %.4f eV)', v0_ev));
        xlabel('Number of aromatic rings');
        ylabel('HOMO-LUMO gap (eV)');
        legend('Location', 'best');
        grid on;
        
        drawnow;
        
        result.success = true;
        result.message = 'Plot created successfully';
        result.metadata = struct();
        
    catch ME
        result.success = false;
        result.message = sprintf('Plotting failed: %s', ME.message);
        result.metadata = struct();
        fprintf('Warning: Plotting failed but agent can continue: %s\n', ME.message);
    end
end

function [result, agent_state] = action_finalize(~, agent_state)
    result = struct();
    
    if agent_state.model.fitted
        result.success = true;
        result.message = sprintf([ ...
            'Task complete! Final model (from %s): v₀ = %.6f hartree (%.4f eV)\n' ...
            'R² = %.4f, RMSE = %.4f eV\n' ...
            'Equation: %s'], ...
            agent_state.equation.source, ...
            agent_state.model.v0, agent_state.model.v0_ev, ...
            agent_state.validation.rsquared, agent_state.validation.rmse_ev, ...
            agent_state.equation.latex);
        result.metadata = struct('v0', agent_state.model.v0, 'v0_ev', agent_state.model.v0_ev);
    else
        result.success = false;
        result.message = 'Cannot finalize: model not fitted yet';
        result.metadata = struct();
    end
end