%% Agent for Paris Law Fitting - PORTABLE VERSION
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
DATA_FILENAME = 'FCG_Data_0.1.csv';  % <-- CHANGE THIS to your file name

%% Get the current script's directory and build full path
% This works on any computer - finds where this script is located
script_dir = fileparts(which(mfilename('fullpath')));
full_data_path = fullfile(script_dir, DATA_FILENAME);

fprintf('Script directory: %s\n', script_dir);
fprintf('Looking for data file: %s\n', full_data_path);

%% Initialize AI Model for ReAct Reasoning
ai_model = openAIChat(['You are an agent helping fit Paris law to fatigue crack growth data. ' ...
    'At each step: 1) Think about what to do next, 2) Choose an action, 3) Observe results. ' ...
    'Be concise and specific.'], ModelName="gpt-4", Temperature=0.1);

%% Initialize Tool Registry
tools = struct();

% Tool 1: Load Data
tools.load_data = struct();
tools.load_data.description = 'Load fatigue crack growth data from CSV file';
tools.load_data.input_schema = {'filename'};
tools.load_data.execute = @action_load_data;

% Tool 2: Auto-Select Region (Slope-Based Approach)
tools.auto_select_region = struct();
tools.auto_select_region.description = 'Automatically detect and select Paris law Region II using slope analysis';
tools.auto_select_region.input_schema = {};  % No inputs needed - fully automatic
tools.auto_select_region.execute = @action_auto_select_region;

% Tool 3: Generate Paris Law Function (MUST come from LLM - NO FALLBACK)
tools.generate_function = struct();
tools.generate_function.description = 'Generate Paris law function using LLM (MUST come from LLM)';
tools.generate_function.input_schema = {};  % No inputs needed
tools.generate_function.execute = @(input, agent_state) action_generate_paris_function(input, agent_state);

% Tool 4: Calculate Initial Estimates
tools.calc_initial = struct();
tools.calc_initial.description = 'Calculate initial parameter estimates from log-log data';
tools.calc_initial.input_schema = {};  % Uses selected region data
tools.calc_initial.execute = @action_calc_initial;

% Tool 5: Fit Model
tools.fit_model = struct();
tools.fit_model.description = 'Fit Paris law model to data using lsqcurvefit (inputs: initial_C, initial_m only)';
tools.fit_model.input_schema = {'initial_C', 'initial_m'};
tools.fit_model.execute = @action_fit_paris_model;

% Tool 6: Validate Fit
tools.validate_fit = struct();
tools.validate_fit.description = 'Calculate R-squared, RMSE, and confidence intervals (no inputs needed)';
tools.validate_fit.input_schema = {};
tools.validate_fit.execute = @action_validate_paris_fit;

% Tool 7: Create Plots
tools.create_plots = struct();
tools.create_plots.description = 'Create comprehensive visualization plots (log-log, residuals) - no inputs needed';
tools.create_plots.input_schema = {};  % No required inputs - saves plots automatically
tools.create_plots.execute = @action_create_paris_plots;

% Tool 8: Debug Environment
tools.debug_env = struct();
tools.debug_env.description = 'Debug workspace environment for plotting';
tools.debug_env.input_schema = {'force_recreate'};
tools.debug_env.execute = @action_debug_env;

% Tool 9: Export Results
tools.export_results = struct();
tools.export_results.description = 'Export fitted parameters and metrics';
tools.export_results.input_schema = {'format', 'filename'};
tools.export_results.execute = @action_export_paris_results;

% Tool 10: Finalize
tools.finalize = struct();
tools.finalize.description = 'Complete the task and show final results (no inputs needed)';
tools.finalize.input_schema = {};
tools.finalize.execute = @action_finalize_paris;

%% Initialize Agent State
agent_state = struct();
agent_state.complete = false;
agent_state.iteration = 0;
agent_state.max_iterations = 20;
agent_state.filename = full_data_path;  % Now uses the dynamic path
agent_state.context = 'Task: Load fatigue crack growth data, automatically select Region II, and fit Paris law';

% Data state
agent_state.data = struct('loaded', false, 'SIF', [], 'dadN', [], 'filename', '');

% Region selection state
agent_state.region = struct('selected', false, 'SIF', [], 'dadN', [], ...
    'DeltaK_min', NaN, 'DeltaK_max', NaN, 'n_points', 0, 'total_points', 0, ...
    'detected_slope_range', [], 'selection_method', 'none');

% Function state (MUST come from LLM)
agent_state.function = struct('ready', false, 'source', 'none', 'func_str', '', ...
    'raw_llm_response', '', 'test_passed', false, 'param_names', {{}});

% Initial estimates state
agent_state.initial = struct('calculated', false, 'C', NaN, 'm', NaN, 'log_C', NaN);

% Model state
agent_state.model = struct('fitted', false, 'C', NaN, 'm', NaN, 'resnorm', NaN, ...
    'exitflag', NaN, 'jacobian', [], 'residuals', [], 'all_params', []);

% Validation state
agent_state.validation = struct('rsquared', NaN, 'rsquared_log', NaN, 'rsquared_adj', NaN, ...
    'rmse', NaN, 'rmse_log', NaN, 'CI_lower', [], 'CI_upper', [], 'has_CI', false);

% History
agent_state.history = {};

fprintf('=== Pure ReAct Agent with Structured Tools Started ===\n');
fprintf('Task: Fit Paris law model to fatigue crack growth data\n');
fprintf('Data file: %s\n', agent_state.filename);
fprintf('Available tools: %s\n\n', strjoin(fieldnames(tools)', ', '));
fprintf('*** NOTE: Paris law equation MUST come from LLM - no fallback provided ***\n');
fprintf('*** ENHANCED PLOTTING: Will create comprehensive log-log and residual plots ***\n');
fprintf('*** AUTO-REGION SELECTION: Using slope-based detection (no manual input) ***\n\n');

%% Check if data file exists
if ~exist(agent_state.filename, 'file')
    fprintf('\n!!! WARNING: Data file not found at: %s\n', agent_state.filename);
    fprintf('Please ensure the file "%s" is in the same folder as this script.\n', DATA_FILENAME);
    fprintf('Current script location: %s\n', script_dir);
    fprintf('Looking for file: %s\n', full_data_path);
    fprintf('\nPress any key to continue with simulation (will fail)...\n');
    pause;
end

%% Main ReAct Loop (rest of the code remains the same)
% ... [All the remaining functions stay exactly as in your original code] ...%% Agent for Paris Law Fitting - PORTABLE VERSION
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
DATA_FILENAME = 'FCG_Data_0.1.csv';  % <-- CHANGE THIS to your file name

%% Get the current script's directory and build full path
% This works on any computer - finds where this script is located
script_dir = fileparts(which(mfilename('fullpath')));
full_data_path = fullfile(script_dir, DATA_FILENAME);

fprintf('Script directory: %s\n', script_dir);
fprintf('Looking for data file: %s\n', full_data_path);

%% Initialize AI Model for ReAct Reasoning
ai_model = openAIChat(['You are an agent helping fit Paris law to fatigue crack growth data. ' ...
    'At each step: 1) Think about what to do next, 2) Choose an action, 3) Observe results. ' ...
    'Be concise and specific.'], ModelName="gpt-4", Temperature=0.1);

%% Initialize Tool Registry
tools = struct();

% Tool 1: Load Data
tools.load_data = struct();
tools.load_data.description = 'Load fatigue crack growth data from CSV file';
tools.load_data.input_schema = {'filename'};
tools.load_data.execute = @action_load_data;

% Tool 2: Auto-Select Region (Slope-Based Approach)
tools.auto_select_region = struct();
tools.auto_select_region.description = 'Automatically detect and select Paris law Region II using slope analysis';
tools.auto_select_region.input_schema = {};  % No inputs needed - fully automatic
tools.auto_select_region.execute = @action_auto_select_region;

% Tool 3: Generate Paris Law Function (MUST come from LLM - NO FALLBACK)
tools.generate_function = struct();
tools.generate_function.description = 'Generate Paris law function using LLM (MUST come from LLM)';
tools.generate_function.input_schema = {};  % No inputs needed
tools.generate_function.execute = @(input, agent_state) action_generate_paris_function(input, agent_state);

% Tool 4: Calculate Initial Estimates
tools.calc_initial = struct();
tools.calc_initial.description = 'Calculate initial parameter estimates from log-log data';
tools.calc_initial.input_schema = {};  % Uses selected region data
tools.calc_initial.execute = @action_calc_initial;

% Tool 5: Fit Model
tools.fit_model = struct();
tools.fit_model.description = 'Fit Paris law model to data using lsqcurvefit (inputs: initial_C, initial_m only)';
tools.fit_model.input_schema = {'initial_C', 'initial_m'};
tools.fit_model.execute = @action_fit_paris_model;

% Tool 6: Validate Fit
tools.validate_fit = struct();
tools.validate_fit.description = 'Calculate R-squared, RMSE, and confidence intervals (no inputs needed)';
tools.validate_fit.input_schema = {};
tools.validate_fit.execute = @action_validate_paris_fit;

% Tool 7: Create Plots
tools.create_plots = struct();
tools.create_plots.description = 'Create comprehensive visualization plots (log-log, residuals) - no inputs needed';
tools.create_plots.input_schema = {};  % No required inputs - saves plots automatically
tools.create_plots.execute = @action_create_paris_plots;

% Tool 8: Debug Environment
tools.debug_env = struct();
tools.debug_env.description = 'Debug workspace environment for plotting';
tools.debug_env.input_schema = {'force_recreate'};
tools.debug_env.execute = @action_debug_env;

% Tool 9: Export Results
tools.export_results = struct();
tools.export_results.description = 'Export fitted parameters and metrics';
tools.export_results.input_schema = {'format', 'filename'};
tools.export_results.execute = @action_export_paris_results;

% Tool 10: Finalize
tools.finalize = struct();
tools.finalize.description = 'Complete the task and show final results (no inputs needed)';
tools.finalize.input_schema = {};
tools.finalize.execute = @action_finalize_paris;

%% Initialize Agent State
agent_state = struct();
agent_state.complete = false;
agent_state.iteration = 0;
agent_state.max_iterations = 20;
agent_state.filename = full_data_path;  % Now uses the dynamic path
agent_state.context = 'Task: Load fatigue crack growth data, automatically select Region II, and fit Paris law';

% Data state
agent_state.data = struct('loaded', false, 'SIF', [], 'dadN', [], 'filename', '');

% Region selection state
agent_state.region = struct('selected', false, 'SIF', [], 'dadN', [], ...
    'DeltaK_min', NaN, 'DeltaK_max', NaN, 'n_points', 0, 'total_points', 0, ...
    'detected_slope_range', [], 'selection_method', 'none');

% Function state (MUST come from LLM)
agent_state.function = struct('ready', false, 'source', 'none', 'func_str', '', ...
    'raw_llm_response', '', 'test_passed', false, 'param_names', {{}});

% Initial estimates state
agent_state.initial = struct('calculated', false, 'C', NaN, 'm', NaN, 'log_C', NaN);

% Model state
agent_state.model = struct('fitted', false, 'C', NaN, 'm', NaN, 'resnorm', NaN, ...
    'exitflag', NaN, 'jacobian', [], 'residuals', [], 'all_params', []);

% Validation state
agent_state.validation = struct('rsquared', NaN, 'rsquared_log', NaN, 'rsquared_adj', NaN, ...
    'rmse', NaN, 'rmse_log', NaN, 'CI_lower', [], 'CI_upper', [], 'has_CI', false);

% History
agent_state.history = {};

fprintf('\n=== Pure ReAct Agent with Structured Tools Started ===\n');
fprintf('Task: Fit Paris law model to fatigue crack growth data\n');
fprintf('Data file: %s\n', agent_state.filename);
fprintf('Available tools: %s\n\n', strjoin(fieldnames(tools)', ', '));
fprintf('*** NOTE: Paris law equation MUST come from LLM - no fallback provided ***\n');
fprintf('*** ENHANCED PLOTTING: Will create comprehensive log-log and residual plots ***\n');
fprintf('*** AUTO-REGION SELECTION: Using slope-based detection (no manual input) ***\n\n');

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
    thought_action = get_llm_decision(ai_model, agent_state, tools);
    
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
            fprintf('\n*** CRITICAL ERROR: LLM failed to generate Paris law equation. ***\n');
            fprintf('*** No fallback provided - agent cannot continue. ***\n');
            error('Paris law equation generation failed - no fallback available');
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
    fprintf('C = %.6e m/cycle\n', agent_state.model.C);
    fprintf('m = %.4f\n', agent_state.model.m);
    fprintf('R² (log) = %.4f\n', agent_state.validation.rsquared_log);
    fprintf('R² (linear) = %.4f\n', agent_state.validation.rsquared);
    fprintf('RMSE = %.4e m/cycle\n', agent_state.validation.rmse);
    fprintf('Equation source: %s\n', agent_state.function.source);
    fprintf('Equation: %s\n', agent_state.function.func_str);
    fprintf('Parameter order: %s\n', strjoin(agent_state.function.param_names, ', '));
    fprintf('Region selection method: %s\n', agent_state.region.selection_method);
    fprintf('Detected slope range: [%.2f, %.2f]\n', agent_state.region.detected_slope_range(1), agent_state.region.detected_slope_range(2));
    
    if agent_state.validation.has_CI
        fprintf('\n95%% Confidence Intervals:\n');
        fprintf('  C: [%.6e , %.6e]\n', agent_state.validation.CI_lower(1), agent_state.validation.CI_upper(1));
        fprintf('  m: [%.4f , %.4f]\n', agent_state.validation.CI_lower(2), agent_state.validation.CI_upper(2));
    end
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

%% Core ReAct Functions

function response = get_llm_decision(model, agent_state, tools)
    % Build prompt with current state and history
    prompt = build_react_prompt(agent_state, tools);
    
    % Get LLM response
    response = generate(model, prompt);
    response = strtrim(string(response));
end

function prompt = build_react_prompt(agent_state, tools)
    % Build prompt with explicit filename and available tools
    tool_list = fieldnames(tools);
    tool_descriptions = '';
    for i = 1:length(tool_list)
        tool_name = tool_list{i};
        tool = tools.(tool_name);
        
        % Add input schema to description
        if ~isempty(tool.input_schema)
            inputs = strjoin(tool.input_schema, ', ');
            tool_descriptions = [tool_descriptions sprintf('- %s: %s (inputs: %s)\n', ...
                tool_name, tool.description, inputs)];
        else
            tool_descriptions = [tool_descriptions sprintf('- %s: %s (no inputs needed)\n', ...
                tool_name, tool.description)];
        end
    end
    
    prompt = [ ...
        'You are a ReAct agent for fatigue crack growth data fitting.\n\n' ...
        'TASK: ' agent_state.context '\n\n' ...
        'The data file is located at: ' agent_state.filename '\n' ...
        'IMPORTANT: Use this EXACT filename when calling load_data.\n\n' ...
        'AVAILABLE TOOLS:\n' tool_descriptions ...
        '\nNOTE: Tools that require data (fit_model, validate_fit, create_plots) automatically use\n' ...
        'the currently loaded data and selected region from the agent state. You do NOT need to\n' ...
        'pass data or function names in the input - just provide the required input parameters.\n\n' ...
        'IMPORTANT: Region selection is now AUTOMATIC using slope analysis. The auto_select_region tool\n' ...
        'will detect Region II based on slope stability without any user input.\n\n' ...
        'CURRENT STATE:\n'];
    
    if agent_state.data.loaded
        prompt = [prompt sprintf('- Data loaded: %d points\n', length(agent_state.data.SIF))];
        prompt = [prompt sprintf('  ΔK range: [%.3e, %.3e] MPa√m\n', min(agent_state.data.SIF), max(agent_state.data.SIF))];
        prompt = [prompt sprintf('  da/dN range: [%.3e, %.3e] m/cycle\n', min(agent_state.data.dadN), max(agent_state.data.dadN))];
    else
        prompt = [prompt '- Data not loaded yet\n'];
        prompt = [prompt sprintf('  Please load data from: %s\n', agent_state.filename)];
    end
    
    if agent_state.region.selected
        prompt = [prompt sprintf('- Region II automatically selected: %d/%d points\n', ...
            agent_state.region.n_points, agent_state.region.total_points)];
        prompt = [prompt sprintf('  ΔK range: [%.3f, %.3f] MPa√m\n', ...
            agent_state.region.DeltaK_min, agent_state.region.DeltaK_max)];
        prompt = [prompt sprintf('  Detected slope range: [%.2f, %.2f]\n', ...
            agent_state.region.detected_slope_range(1), agent_state.region.detected_slope_range(2))];
    else
        prompt = [prompt '- Region II not selected yet\n'];
        prompt = [prompt '  Run auto_select_region to automatically detect the linear region\n'];
    end
    
    if agent_state.function.ready
        prompt = [prompt sprintf('- Function ready (from %s)\n', agent_state.function.source)];
        if agent_state.function.test_passed
            prompt = [prompt '  Function test: PASSED\n'];
            prompt = [prompt sprintf('  Parameter order: %s\n', strjoin(agent_state.function.param_names, ', '))];
        end
    else
        prompt = [prompt '- Function not generated yet\n'];
        prompt = [prompt '  *** MUST generate equation from LLM - no default provided ***\n'];
    end
    
    if agent_state.initial.calculated
        prompt = [prompt sprintf('- Initial estimates: C = %.2e, m = %.2f\n', ...
            agent_state.initial.C, agent_state.initial.m)];
        prompt = [prompt '  To fit the model, call fit_model with: {"initial_C": value, "initial_m": value}\n'];
    end
    
    if agent_state.model.fitted
        prompt = [prompt sprintf('- Model fitted: C = %.2e, m = %.2f\n', ...
            agent_state.model.C, agent_state.model.m)];
    end
    
    if ~isnan(agent_state.validation.rsquared)
        prompt = [prompt sprintf('- Validated: R²=%.4f, R²(log)=%.4f, RMSE=%.2e\n', ...
            agent_state.validation.rsquared, agent_state.validation.rsquared_log, ...
            agent_state.validation.rmse)];
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
        'Remember:\n' ...
        '- Use the EXACT filename when calling load_data\n' ...
        '- generate_function MUST produce a valid equation from your knowledge (no fallback)\n' ...
        '- auto_select_region needs no inputs - it automatically finds Region II using slope analysis\n' ...
        '- fit_model only needs initial_C and initial_m as inputs (data and function are already in agent state)\n' ...
        '- validate_fit and create_plots need no inputs\n\n' ...
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
                if isfield(result.metadata, 'SIF')
                    agent_state.data.SIF = result.metadata.SIF;
                    agent_state.data.dadN = result.metadata.dadN;
                end
            
            case 'auto_select_region'
                agent_state.region.selected = true;
                agent_state.region.SIF = result.metadata.SIF;
                agent_state.region.dadN = result.metadata.dadN;
                agent_state.region.DeltaK_min = result.metadata.DeltaK_min;
                agent_state.region.DeltaK_max = result.metadata.DeltaK_max;
                agent_state.region.n_points = result.metadata.n_points;
                agent_state.region.total_points = result.metadata.total_points;
                agent_state.region.detected_slope_range = result.metadata.slope_range;
                agent_state.region.selection_method = 'slope-based automatic';
            
            case 'generate_function'
                agent_state.function.ready = result.metadata.test_passed;
                agent_state.function.source = result.metadata.source;
                agent_state.function.func_str = result.metadata.func_str;
                agent_state.function.raw_llm_response = result.metadata.raw_response;
                agent_state.function.test_passed = result.metadata.test_passed;
                agent_state.function.param_names = result.metadata.param_names;
            
            case 'calc_initial'
                agent_state.initial.calculated = true;
                agent_state.initial.C = result.metadata.C;
                agent_state.initial.m = result.metadata.m;
                agent_state.initial.log_C = result.metadata.log_C;
            
            case 'fit_model'
                agent_state.model.fitted = true;
                agent_state.model.C = result.metadata.C;
                agent_state.model.m = result.metadata.m;
                agent_state.model.resnorm = result.metadata.resnorm;
                agent_state.model.exitflag = result.metadata.exitflag;
                agent_state.model.jacobian = result.metadata.jacobian;
                agent_state.model.residuals = result.metadata.residuals;
                if isfield(result.metadata, 'all_params')
                    agent_state.model.all_params = result.metadata.all_params;
                end
            
            case 'validate_fit'
                agent_state.validation.rsquared = result.metadata.rsquared;
                agent_state.validation.rsquared_log = result.metadata.rsquared_log;
                agent_state.validation.rsquared_adj = result.metadata.rsquared_adj;
                agent_state.validation.rmse = result.metadata.rmse;
                agent_state.validation.rmse_log = result.metadata.rmse_log;
                if isfield(result.metadata, 'CI_lower')
                    agent_state.validation.CI_lower = result.metadata.CI_lower;
                    agent_state.validation.CI_upper = result.metadata.CI_upper;
                    agent_state.validation.has_CI = result.metadata.has_CI;
                end
        end
    end
end

%% Tool Implementation Functions

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
        
        SIF = data(:, 1);
        dadN = data(:, 2);
        
        % Update agent state
        agent_state.data.loaded = true;
        agent_state.data.SIF = SIF;
        agent_state.data.dadN = dadN;
        agent_state.data.filename = filename;
        
        % Store in base workspace
        assignin('base', 'agent_SIF', SIF);
        assignin('base', 'agent_dadN', dadN);
        
        % Result
        result.success = true;
        result.message = sprintf('Loaded %d data points. ΔK range: [%.3e, %.3e] MPa√m, da/dN range: [%.3e, %.3e] m/cycle', ...
            length(SIF), min(SIF), max(SIF), min(dadN), max(dadN));
        result.metadata = struct('SIF', SIF, 'dadN', dadN, 'n_points', length(SIF));
        
    catch ME
        result.success = false;
        result.message = sprintf('Failed to load data: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

%% Automatic Region Selection using Slope Analysis
function [result, agent_state] = action_auto_select_region(~, agent_state)
    result = struct();
    
    try
        % Get data from agent state
        SIF = agent_state.data.SIF;
        dadN = agent_state.data.dadN;
        
        if isempty(SIF) || isempty(dadN)
            error('No data loaded. Run load_data first.');
        end
        
        % Convert to log space
        log_SIF = log10(SIF);
        log_dadN = log10(dadN);
        
        % Calculate moving window slope
        window_size = max(5, round(length(SIF) * 0.15));
        window_size = min(window_size, floor(length(SIF)/2));
        
        slopes = zeros(length(SIF) - window_size + 1, 1);
        mid_points = zeros(length(SIF) - window_size + 1, 1);
        r2_values = zeros(length(SIF) - window_size + 1, 1);
        
        for i = 1:length(slopes)
            idx = i:i+window_size-1;
            p = polyfit(log_SIF(idx), log_dadN(idx), 1);
            slopes(i) = p(1);
            mid_points(i) = mean(log_SIF(idx));
            
            y_fit = polyval(p, log_SIF(idx));
            ss_res = sum((log_dadN(idx) - y_fit).^2);
            ss_tot = sum((log_dadN(idx) - mean(log_dadN(idx))).^2);
            r2_values(i) = 1 - ss_res/ss_tot;
        end
        
        min_acceptable_slope = 2.0;
        max_acceptable_slope = 4.0;
        min_r2 = 0.95;
        valid_region = (slopes >= min_acceptable_slope) & (slopes <= max_acceptable_slope) & (r2_values >= min_r2);
        
        if ~any(valid_region)
            min_r2 = 0.90;
            valid_region = (slopes >= min_acceptable_slope) & (slopes <= max_acceptable_slope) & (r2_values >= min_r2);
        end
        
        if ~any(valid_region)
            slope_std = movstd(slopes, max(3, round(length(slopes)*0.2)));
            [~, best_idx] = min(slope_std);
            start_idx = best_idx;
            end_idx = best_idx + window_size - 1;
            region_idx = start_idx:min(end_idx, length(SIF));
            SIF_region = SIF(region_idx);
            dadN_region = dadN(region_idx);
            p_region = polyfit(log10(SIF_region), log10(dadN_region), 1);
            slope_range = [p_region(1), p_region(1)];
        else
            valid_diff = diff([0; valid_region; 0]);
            starts = find(valid_diff == 1);
            ends = find(valid_diff == -1) - 1;
            
            if isempty(starts)
                error('Could not identify valid Region II segment');
            end
            
            [~, longest] = max(ends - starts);
            best_start_window = starts(longest);
            best_end_window = ends(longest);
            
            start_idx = best_start_window;
            end_idx = best_end_window + window_size - 1;
            start_idx = max(1, start_idx);
            end_idx = min(length(SIF), end_idx);
            
            region_idx = start_idx:end_idx;
            SIF_region = SIF(region_idx);
            dadN_region = dadN(region_idx);
            
            slopes_in_region = slopes(best_start_window:best_end_window);
            slope_range = [min(slopes_in_region), max(slopes_in_region)];
        end
        
        if length(SIF_region) < 5
            error('Selected region has too few points (%d). Need at least 5.', length(SIF_region));
        end
        
        agent_state.region.selected = true;
        agent_state.region.SIF = SIF_region;
        agent_state.region.dadN = dadN_region;
        agent_state.region.DeltaK_min = min(SIF_region);
        agent_state.region.DeltaK_max = max(SIF_region);
        agent_state.region.n_points = length(SIF_region);
        agent_state.region.total_points = length(SIF);
        agent_state.region.detected_slope_range = slope_range;
        agent_state.region.selection_method = 'slope-based automatic';
        
        assignin('base', 'agent_SIF_region', SIF_region);
        assignin('base', 'agent_dadN_region', dadN_region);
        
        result.success = true;
        result.message = sprintf(['Auto-selected Region II: ΔK range [%.3f, %.3f] MPa√m, %d points out of %d\n' ...
            'Detected slope range: [%.2f, %.2f] (acceptable range: 2-4)'], ...
            min(SIF_region), max(SIF_region), length(SIF_region), length(SIF), ...
            slope_range(1), slope_range(2));
        
        result.metadata = struct('SIF', SIF_region, 'dadN', dadN_region, ...
            'DeltaK_min', min(SIF_region), 'DeltaK_max', max(SIF_region), ...
            'n_points', length(SIF_region), 'total_points', length(SIF), ...
            'slope_range', slope_range);
        
    catch ME
        result.success = false;
        result.message = sprintf('Auto-region selection failed: %s', ME.message);
        result.metadata = struct();
        fprintf('Warning: Auto-region selection failed: %s\n', ME.message);
    end
end

%% Paris law function generation - MUST come from LLM with no hints
function [result, agent_state] = action_generate_paris_function(~, agent_state)
    result = struct();
    
    try
        equation_model = openAIChat( ...
            'You are a materials science expert who understands fatigue crack growth.', ...
            ModelName="gpt-4", ...
            Temperature=0.1);
        
        if agent_state.region.selected
            SIF_min = min(agent_state.region.SIF);
            SIF_max = max(agent_state.region.SIF);
            dadN_min = min(agent_state.region.dadN);
            dadN_max = max(agent_state.region.dadN);
            data_context = sprintf('The automatically selected Region II data shows da/dN ranging from %.2e to %.2e m/cycle for ΔK from %.2f to %.2f MPa√m.', ...
                dadN_min, dadN_max, SIF_min, SIF_max);
        elseif agent_state.data.loaded
            SIF_min = min(agent_state.data.SIF);
            SIF_max = max(agent_state.data.SIF);
            dadN_min = min(agent_state.data.dadN);
            dadN_max = max(agent_state.data.dadN);
            data_context = sprintf('The full dataset shows da/dN ranging from %.2e to %.2e m/cycle for ΔK from %.2f to %.2f MPa√m.', ...
                dadN_min, dadN_max, SIF_min, SIF_max);
        else
            data_context = 'The data will be loaded separately.';
        end
        
        equation_prompt = [ ...
            'What is the governing equation that relates fatigue crack growth rate (da/dN) to stress intensity factor range (ΔK) for Region II crack growth?\n\n' ...
            'IMPORTANT: Respond with ONLY the equation and parameter definitions in PLAIN TEXT.\n' ...
            'DO NOT include any JSON, code blocks, or structured data formats.\n\n' ...
            'Provide the equation in this format:\n' ...
            'da/dN = [mathematical expression with parameters]\n\n' ...
            'Then on new lines, provide:\n' ...
            '- Parameter 1: name and physical meaning\n' ...
            '- Parameter 2: name and physical meaning\n' ...
            '- Units for each variable'];
        
        fprintf('Asking LLM for equation form...\n');
        equation_form = generate(equation_model, equation_prompt);
        equation_form = strtrim(string(equation_form));
        
        fprintf('✓ Received equation form:\n%s\n', equation_form);
        
        code_model = openAIChat( ...
            'You are a MATLAB code generator. You output ONLY valid MATLAB code.', ...
            ModelName="gpt-4", ...
            Temperature=0.1);
        
        code_prompt = [ ...
            'Based on this equation:\n\n' ...
            char(equation_form) '\n\n' ...
            'Create a MATLAB anonymous function that implements this equation.\n\n' ...
            'Context from data:\n' ...
            data_context '\n\n' ...
            'REQUIREMENTS - PARAMETER ORDER IS CRITICAL:\n' ...
            '1. Function name must be: crack_growth_model\n' ...
            '2. The FIRST input parameter must be the independent variable ΔK\n' ...
            '3. The REMAINING input parameters must be the material constants, in the order they appear in your equation\n' ...
            '4. Use element-wise operations (.*, ./, .^) for vectorized computation\n\n' ...
            'OUTPUT FORMAT:\n' ...
            'Output EXACTLY ONE LINE of MATLAB code with NO additional text.\n' ...
            'DO NOT include JSON, markdown, backticks, or explanations.'];
        
        fprintf('Converting to MATLAB function...\n');
        response = generate(code_model, code_prompt);
        response = strtrim(string(response));
        
        raw_response = response;
        [func_str, param_names] = robust_clean_response(response, equation_form);
        
        if isempty(func_str) || ~contains(func_str, 'crack_growth_model') || ~contains(func_str, '@(')
            fprintf('\n=== LLM DEBUG OUTPUT ===\n');
            fprintf('Raw response:\n%s\n', response);
            fprintf('Equation form:\n%s\n', equation_form);
            fprintf('========================\n\n');
            error('LLM failed to output valid MATLAB function');
        end
        
        if ~endsWith(strtrim(func_str), ';')
            func_str = [strtrim(func_str), ';'];
        end
        
        try
            eval(func_str);
            
            if isempty(param_names) || length(param_names) < 2
                error('Function must have at least 2 parameters');
            end
            
            if agent_state.region.selected
                test_SIF = linspace(agent_state.region.DeltaK_min, agent_state.region.DeltaK_max, 5);
            else
                test_SIF = [5, 10, 15, 20];
            end
            
            n_constants = length(param_names) - 1;
            test_params = [];
            for i = 1:n_constants
                if i == 1
                    test_params(i) = 1e-12;
                elseif i == 2
                    test_params(i) = 3;
                else
                    test_params(i) = 1;
                end
            end
            
            test_call = 'crack_growth_model(test_SIF';
            for i = 1:length(test_params)
                test_call = [test_call, sprintf(', %.6e', test_params(i))];
            end
            test_call = [test_call, ');'];
            
            test_result = eval(test_call);
            
            if isempty(test_result) || any(isnan(test_result)) || any(~isfinite(test_result))
                error('Function returned invalid values');
            end
            
            fprintf('✓ Function test passed with %d parameters\n', length(param_names));
            fprintf('  Parameter order: %s\n', strjoin(param_names, ', '));
            test_passed = true;
            
        catch test_err
            error('Function test failed: %s\nFunction was: %s', test_err.message, func_str);
        end
        
        evalin('base', func_str);
        assignin('base', 'agent_function_str', func_str);
        assignin('base', 'agent_equation_form', equation_form);
        
        agent_state.function.ready = true;
        agent_state.function.source = 'LLM generated from knowledge';
        agent_state.function.func_str = func_str;
        agent_state.function.raw_llm_response = raw_response;
        agent_state.function.test_passed = test_passed;
        agent_state.function.param_names = param_names;
        
        result.success = true;
        result.message = sprintf('LLM generated: %s\nBased on equation: %s', func_str, equation_form);
        result.metadata = struct('func_str', func_str, 'test_passed', test_passed, ...
            'source', 'LLM knowledge', 'equation_form', equation_form, ...
            'raw_response', raw_response, 'param_names', {param_names});
        
    catch ME
        result.success = false;
        result.message = sprintf('FAILED: %s', ME.message);
        result.metadata = struct();
        
        fprintf('\n*** AGENT HALTED: LLM failed to generate equation ***\n');
        fprintf('Error: %s\n', ME.message);
        fprintf('This is a pure test - no fallback provided.\n\n');
        rethrow(ME);
    end
end

function [clean, param_names] = robust_clean_response(raw, equation_form)
    clean = '';
    param_names = {};
    raw = char(raw);
    
    json_pattern = '\{[^{}]*\}';
    prev_raw = '';
    while ~strcmp(prev_raw, raw)
        prev_raw = raw;
        raw = regexprep(raw, json_pattern, '');
    end
    
    raw = strrep(raw, '```matlab', '');
    raw = strrep(raw, '```', '');
    raw = strrep(raw, '`', '');
    
    lines = splitlines(raw);
    code_candidates = {};
    
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if isempty(line)
            continue;
        end
        if contains(line, ':') && ~contains(line, '=') && ~contains(line, '@')
            continue;
        end
        if contains(line, '(MPa') || contains(line, '(m/cycle')
            continue;
        end
        if contains(line, '=') && (contains(line, '@') || contains(line, 'function'))
            code_candidates{end+1} = line;
        elseif contains(line, '@(') && contains(line, ')')
            code_candidates{end+1} = line;
        end
    end
    
    if ~isempty(code_candidates)
        for i = 1:length(code_candidates)
            candidate = code_candidates{i};
            if contains(candidate, 'crack_growth_model') && contains(candidate, '@(')
                clean = candidate;
                comment_idx = strfind(clean, '%');
                if ~isempty(comment_idx)
                    clean = clean(1:comment_idx(1)-1);
                end
                param_match = regexp(clean, '@\(([^)]+)\)', 'tokens');
                if ~isempty(param_match) && ~isempty(param_match{1})
                    param_str = param_match{1}{1};
                    param_names = strsplit(strtrim(param_str), ',');
                    param_names = strtrim(param_names);
                end
                return;
            end
        end
        clean = code_candidates{1};
        if ~contains(clean, 'crack_growth_model')
            clean = ['crack_growth_model = ', clean];
        end
        param_match = regexp(clean, '@\(([^)]+)\)', 'tokens');
        if ~isempty(param_match) && ~isempty(param_match{1})
            param_str = param_match{1}{1};
            param_names = strsplit(strtrim(param_str), ',');
            param_names = strtrim(param_names);
        end
        return;
    end
    
    clean = '';
end

function [result, agent_state] = action_calc_initial(~, agent_state)
    result = struct();
    
    try
        SIF_paris = agent_state.region.SIF;
        dadN_paris = agent_state.region.dadN;
        
        if isempty(SIF_paris) || isempty(dadN_paris)
            error('No region data available. Run auto_select_region first.');
        end
        
        log_SIF = log(SIF_paris);
        log_dadN = log(dadN_paris);
        
        p_log = polyfit(log_SIF, log_dadN, 1);
        
        m_initial = p_log(1);
        log_C_initial = p_log(2);
        C_initial = exp(log_C_initial);
        
        agent_state.initial.calculated = true;
        agent_state.initial.C = C_initial;
        agent_state.initial.m = m_initial;
        agent_state.initial.log_C = log_C_initial;
        
        assignin('base', 'agent_C_initial', C_initial);
        assignin('base', 'agent_m_initial', m_initial);
        
        result.success = true;
        result.message = sprintf('Initial estimates: C = %.4e, m = %.4f', C_initial, m_initial);
        result.metadata = struct('C', C_initial, 'm', m_initial, 'log_C', log_C_initial);
        
    catch ME
        result.success = false;
        result.message = sprintf('Initial estimate calculation failed: %s', ME.message);
        result.metadata = struct();
        fprintf('Warning: Initial estimate calculation failed: %s\n', ME.message);
    end
end

function [result, agent_state] = action_fit_paris_model(input, agent_state)
    result = struct();
    
    try
        SIF_paris = agent_state.region.SIF;
        dadN_paris = agent_state.region.dadN;
        
        if isempty(SIF_paris) || isempty(dadN_paris)
            error('No region data available. Run auto_select_region first.');
        end
        
        if ~evalin('base', 'exist(''crack_growth_model'', ''var'')')
            if ~isempty(agent_state.function.func_str)
                evalin('base', agent_state.function.func_str);
            else
                error('No function available. Run generate_function first.');
            end
        end
        crack_growth_model = evalin('base', 'crack_growth_model');
        
        param_names = agent_state.function.param_names;
        if isempty(param_names)
            func_str = func2str(crack_growth_model);
            param_match = regexp(func_str, '@\(([^)]+)\)', 'tokens');
            if ~isempty(param_match) && ~isempty(param_match{1})
                param_str = param_match{1}{1};
                param_names = strsplit(strtrim(param_str), ',');
                param_names = strtrim(param_names);
            else
                param_names = {'DeltaK', 'C', 'm'};
            end
        end
        
        initial_C = agent_state.initial.C;
        initial_m = agent_state.initial.m;
        
        if isstruct(input)
            if isfield(input, 'initial_C') && isfield(input, 'initial_m')
                initial_C = input.initial_C;
                initial_m = input.initial_m;
            end
        end
        
        if isnan(initial_C) || isnan(initial_m) || initial_C <= 0 || initial_m <= 0
            error('Valid initial estimates required. Run calc_initial first or provide valid inputs.');
        end
        
        n_params = length(param_names) - 1;
        
        p0 = [];
        for i = 1:n_params
            if i == 1
                p0(i) = initial_C;
            elseif i == 2
                p0(i) = initial_m;
            else
                p0(i) = 1;
            end
        end
        
        opts = optimoptions('lsqcurvefit', 'Display', 'off', ...
            'MaxIterations', 400, 'MaxFunctionEvaluations', 1000);
        
        fit_success = false;
        
        if n_params == 2
            try
                fit_func = @(p, x) crack_growth_model(x, p(1), p(2));
                [p_opt, resnorm, residual, exitflag, ~, ~, jacobian] = ...
                    lsqcurvefit(fit_func, p0, SIF_paris, dadN_paris, [], [], opts);
                fit_success = (exitflag > 0);
            catch
            end
        end
        
        if ~fit_success
            try
                fit_func = @(p, x) crack_growth_model(x, p(:));
                [p_opt, resnorm, residual, exitflag, ~, ~, jacobian] = ...
                    lsqcurvefit(fit_func, p0, SIF_paris, dadN_paris, [], [], opts);
                fit_success = (exitflag > 0);
            catch ME
                error('Fitting failed: %s', ME.message);
            end
        end
        
        agent_state.model.fitted = true;
        agent_state.model.C = p_opt(1);
        agent_state.model.m = p_opt(2);
        agent_state.model.resnorm = resnorm;
        agent_state.model.exitflag = exitflag;
        agent_state.model.jacobian = jacobian;
        agent_state.model.residuals = residual;
        
        if length(p_opt) > 2
            agent_state.model.all_params = p_opt;
        end
        
        assignin('base', 'agent_C_hat', p_opt(1));
        assignin('base', 'agent_m_hat', p_opt(2));
        
        result.success = true;
        result.message = sprintf('Fit complete: C = %.4e, m = %.4f, resnorm = %.4e', ...
            p_opt(1), p_opt(2), resnorm);
        
        metadata = struct('C', p_opt(1), 'm', p_opt(2), ...
            'resnorm', resnorm, 'exitflag', exitflag, ...
            'residuals', residual, 'jacobian', jacobian);
        
        if length(p_opt) > 2
            metadata.all_params = p_opt;
        end
        
        result.metadata = metadata;
        
    catch ME
        result.success = false;
        result.message = sprintf('Fitting failed: %s', ME.message);
        result.metadata = struct();
        fprintf('Warning: Fitting failed but agent can continue: %s\n', ME.message);
    end
end

function [result, agent_state] = action_validate_paris_fit(~, agent_state)
    result = struct();
    
    try
        if ~agent_state.model.fitted
            error('No fitted model available. Run fit_model first.');
        end
        
        SIF_paris = agent_state.region.SIF;
        dadN_paris = agent_state.region.dadN;
        C_hat = agent_state.model.C;
        m_hat = agent_state.model.m;
        
        if isempty(SIF_paris) || isempty(dadN_paris)
            error('No region data available.');
        end
        
        if ~evalin('base', 'exist(''crack_growth_model'', ''var'')')
            if ~isempty(agent_state.function.func_str)
                evalin('base', agent_state.function.func_str);
            else
                error('No function available.');
            end
        end
        crack_growth_model = evalin('base', 'crack_growth_model');
        
        param_names = agent_state.function.param_names;
        n_params = length(param_names) - 1;
        
        if n_params == 2
            dadN_pred = crack_growth_model(SIF_paris, C_hat, m_hat);
        else
            p_test = [C_hat, m_hat, ones(1, n_params-2)];
            dadN_pred = crack_growth_model(SIF_paris, p_test(:));
        end
        
        ss_res = sum((dadN_paris - dadN_pred).^2);
        ss_tot = sum((dadN_paris - mean(dadN_paris)).^2);
        rsquared = 1 - ss_res/ss_tot;
        rmse = sqrt(mean((dadN_paris - dadN_pred).^2));
        
        log_dadN = log(dadN_paris);
        log_dadN_pred = log(dadN_pred);
        ss_res_log = sum((log_dadN - log_dadN_pred).^2);
        ss_tot_log = sum((log_dadN - mean(log_dadN)).^2);
        rsquared_log = 1 - ss_res_log/ss_tot_log;
        rmse_log = sqrt(mean((log_dadN - log_dadN_pred).^2));
        
        n = length(SIF_paris);
        p_params = 2;
        rsquared_adj = 1 - (1 - rsquared)*(n-1)/(n-p_params-1);
        
        agent_state.validation.rsquared = rsquared;
        agent_state.validation.rsquared_log = rsquared_log;
        agent_state.validation.rsquared_adj = rsquared_adj;
        agent_state.validation.rmse = rmse;
        agent_state.validation.rmse_log = rmse_log;
        
        if ~isempty(agent_state.model.jacobian) && agent_state.model.exitflag > 0
            J = full(agent_state.model.jacobian);
            mse = agent_state.model.resnorm/(n - p_params);
            
            cond_num = cond(J'*J);
            if cond_num < 1e10
                C_cov = inv(J'*J)*mse;
                se = sqrt(diag(C_cov));
                alpha = 0.05;
                t_crit = tinv(1-alpha/2, n-p_params);
                CI_lower = [C_hat, m_hat] - t_crit*se';
                CI_upper = [C_hat, m_hat] + t_crit*se';
                
                agent_state.validation.CI_lower = CI_lower;
                agent_state.validation.CI_upper = CI_upper;
                agent_state.validation.has_CI = true;
            else
                agent_state.validation.has_CI = false;
            end
        end
        
        result.success = true;
        result.message = sprintf(['Validation: R²=%.4f, R²(log)=%.4f, RMSE=%.4e\n' ...
            'Adjusted R²=%.4f, RMSE(log)=%.4e'], ...
            rsquared, rsquared_log, rmse, rsquared_adj, rmse_log);
        
        metadata = struct('rsquared', rsquared, 'rsquared_log', rsquared_log, ...
            'rsquared_adj', rsquared_adj, 'rmse', rmse, 'rmse_log', rmse_log);
        
        if agent_state.validation.has_CI
            metadata.CI_lower = CI_lower;
            metadata.CI_upper = CI_upper;
            metadata.has_CI = true;
        else
            metadata.has_CI = false;
        end
        
        result.metadata = metadata;
        
    catch ME
        result.success = false;
        result.message = sprintf('Validation failed: %s', ME.message);
        result.metadata = struct();
        fprintf('Warning: Validation failed: %s\n', ME.message);
    end
end

function [result, agent_state] = action_create_paris_plots(~, agent_state)
    result = struct();
    
    try
        if ~agent_state.model.fitted
            error('No fitted model available. Run fit_model first.');
        end
        
        SIF_full = agent_state.data.SIF;
        dadN_full = agent_state.data.dadN;
        SIF_paris = agent_state.region.SIF;
        dadN_paris = agent_state.region.dadN;
        DeltaK_min = agent_state.region.DeltaK_min;
        DeltaK_max = agent_state.region.DeltaK_max;
        C_hat = agent_state.model.C;
        m_hat = agent_state.model.m;
        
        if isempty(SIF_full) || isempty(dadN_full)
            error('No data available.');
        end
        
        if ~evalin('base', 'exist(''crack_growth_model'', ''var'')')
            if ~isempty(agent_state.function.func_str)
                evalin('base', agent_state.function.func_str);
            else
                error('No function available.');
            end
        end
        crack_growth_model = evalin('base', 'crack_growth_model');
        
        param_names = agent_state.function.param_names;
        n_params = length(param_names) - 1;
        
        if n_params == 2
            dadN_fit = crack_growth_model(logspace(log10(DeltaK_min), log10(DeltaK_max), 200)', C_hat, m_hat);
        else
            p_fit = [C_hat, m_hat, ones(1, n_params-2)];
            dadN_fit = crack_growth_model(logspace(log10(DeltaK_min), log10(DeltaK_max), 200)', p_fit(:));
        end
        
        fig1 = figure('Position', [100, 100, 1000, 700], 'Name', 'Paris Law Fit');
        
        loglog(SIF_full, dadN_full, 'ko', 'MarkerSize', 6, 'DisplayName', 'All Data');
        hold on;
        loglog(SIF_paris, dadN_paris, 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b', ...
            'DisplayName', sprintf('Region II (auto-selected, %d pts)', length(SIF_paris)));
        loglog(logspace(log10(DeltaK_min), log10(DeltaK_max), 200)', dadN_fit, 'r-', 'LineWidth', 2.5, 'DisplayName', 'Paris Law Fit');
        
        xlabel('\DeltaK (MPa\surdm)', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('da/dN (m/cycle)', 'FontSize', 12, 'FontWeight', 'bold');
        legend('Location', 'northeast', 'FontSize', 11);
        grid on;
        box on;
        
        text_str = sprintf(['Fit Statistics:\n' ...
            'C = %.2e m/cycle\n' ...
            'm = %.3f\n' ...
            'R²(log) = %.4f\n' ...
            'RMSE = %.2e m/cycle\n' ...
            'Region slope range: [%.2f, %.2f]'], ...
            C_hat, m_hat, agent_state.validation.rsquared_log, ...
            agent_state.validation.rmse, ...
            agent_state.region.detected_slope_range(1), ...
            agent_state.region.detected_slope_range(2));
        
        annotation('textbox', [0.15, 0.75, 0.2, 0.15], ...
            'String', text_str, ...
            'FontSize', 10, ...
            'BackgroundColor', 'white', ...
            'EdgeColor', 'black', ...
            'LineWidth', 1.5);
        
        fig2 = figure('Position', [150, 150, 1000, 500], 'Name', 'Residual Analysis');
        
        if n_params == 2
            dadN_pred_full = crack_growth_model(SIF_paris, C_hat, m_hat);
        else
            dadN_pred_full = crack_growth_model(SIF_paris, p_fit(:));
        end
        
        residuals = (dadN_paris - dadN_pred_full) ./ dadN_paris * 100;
        
        subplot(1, 2, 1);
        loglog(SIF_paris, abs(residuals), 'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
        xlabel('\DeltaK (MPa\surdm)', 'FontSize', 11);
        ylabel('|% Residual|', 'FontSize', 11);
        title('Absolute Percent Residuals', 'FontSize', 12);
        grid on;
        
        subplot(1, 2, 2);
        plot(SIF_paris, residuals, 'bo', 'MarkerSize', 6, 'MarkerFaceColor', 'b');
        hold on;
        yline(0, '--k', 'LineWidth', 1.5);
        xlabel('\DeltaK (MPa\surdm)', 'FontSize', 11);
        ylabel('% Residual', 'FontSize', 11);
        title('Residual Distribution', 'FontSize', 12);
        grid on;
        
        res_mean = mean(residuals);
        res_std = std(residuals);
        res_text = sprintf('Mean = %.2f%%\nStd Dev = %.2f%%', res_mean, res_std);
        text(0.05, 0.95, res_text, 'Units', 'normalized', 'FontSize', 10, ...
            'BackgroundColor', 'white', 'EdgeColor', 'black', ...
            'VerticalAlignment', 'top', 'Margin', 5);
        
        fig3 = figure('Position', [200, 200, 600, 500], 'Name', 'Linearity Check');
        
        loglog(SIF_paris, dadN_paris, 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
        hold on;
        
        log_SIF = log10(SIF_paris);
        log_dadN = log10(dadN_paris);
        p = polyfit(log_SIF, log_dadN, 1);
        log_fit_line = 10.^(polyval(p, log_SIF));
        loglog(SIF_paris, log_fit_line, 'r-', 'LineWidth', 2);
        
        xlabel('\DeltaK (MPa\surdm)', 'FontSize', 12);
        ylabel('da/dN (m/cycle)', 'FontSize', 12);
        title('Log-Log Linearity Check', 'FontSize', 14);
        legend('Data', sprintf('Log-Log Fit (slope = %.3f)', p(1)), 'Location', 'northwest');
        grid on;
        
        drawnow;
        
        result.success = true;
        result.message = sprintf('Created 3 figures with comprehensive Paris law analysis. Figures %d, %d, %d', ...
            fig1.Number, fig2.Number, fig3.Number);
        result.metadata = struct('figure1', fig1.Number, 'figure2', fig2.Number, 'figure3', fig3.Number);
        
    catch ME
        result.success = false;
        result.message = sprintf('Plotting failed: %s', ME.message);
        result.metadata = struct();
        fprintf('Warning: Plotting failed but agent can continue: %s\n', ME.message);
    end
end

function [result, agent_state] = action_debug_env(input, agent_state)
    result = struct();
    
    try
        if ~evalin('base', 'exist(''crack_growth_model'', ''var'')')
            if ~isempty(agent_state.function.func_str)
                evalin('base', agent_state.function.func_str);
                source = 'recreated from stored LLM function';
            else
                error('No function available. Must run generate_function first.');
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

function [result, agent_state] = action_export_paris_results(input, agent_state)
    result = struct();
    
    try
        format = 'mat';
        filename = 'paris_law_results.mat';
        
        if isstruct(input)
            if isfield(input, 'format')
                format = input.format;
            end
            if isfield(input, 'filename')
                filename = input.filename;
            end
        end
        
        results = struct();
        results.C = agent_state.model.C;
        results.m = agent_state.model.m;
        results.rsquared = agent_state.validation.rsquared;
        results.rsquared_log = agent_state.validation.rsquared_log;
        results.rsquared_adj = agent_state.validation.rsquared_adj;
        results.rmse = agent_state.validation.rmse;
        results.function_source = agent_state.function.source;
        results.function_str = agent_state.function.func_str;
        results.function_params = agent_state.function.param_names;
        results.generation_date = datestr(now);
        results.n_data_points = length(agent_state.data.SIF);
        results.n_region_points = agent_state.region.n_points;
        results.DeltaK_range = [agent_state.region.DeltaK_min, agent_state.region.DeltaK_max];
        results.region_selection_method = agent_state.region.selection_method;
        results.detected_slope_range = agent_state.region.detected_slope_range;
        
        if ~isempty(agent_state.model.all_params)
            results.all_params = agent_state.model.all_params;
        end
        
        if agent_state.validation.has_CI
            results.CI_C = [agent_state.validation.CI_lower(1), agent_state.validation.CI_upper(1)];
            results.CI_m = [agent_state.validation.CI_lower(2), agent_state.validation.CI_upper(2)];
        end
        
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

function [result, agent_state] = action_finalize_paris(~, agent_state)
    result = struct();
    
    if agent_state.model.fitted
        ci_text = '';
        if agent_state.validation.has_CI
            ci_text = sprintf('\n95%% CI for C: [%.2e , %.2e]\n95%% CI for m: [%.3f , %.3f]', ...
                agent_state.validation.CI_lower(1), agent_state.validation.CI_upper(1), ...
                agent_state.validation.CI_lower(2), agent_state.validation.CI_upper(2));
        end
        
        param_order_text = sprintf('Parameter order: %s', strjoin(agent_state.function.param_names, ', '));
        
        result.success = true;
        result.message = sprintf([ ...
            'Task complete! Final Paris law model (from %s):\n' ...
            '%s\n' ...
            '%s\n\n' ...
            'Region automatically selected using slope analysis\n' ...
            'Detected slope range: [%.2f, %.2f]\n\n' ...
            'Fitted values:\n' ...
            'C = %.4e m/cycle\n' ...
            'm = %.4f\n\n' ...
            'Fit Statistics:\n' ...
            'R² (log) = %.4f\n' ...
            'R² (linear) = %.4f\n' ...
            'Adjusted R² = %.4f\n' ...
            'RMSE = %.4e m/cycle\n' ...
            'Region II points: %d/%d\n' ...
            'ΔK range: [%.2f, %.2f] MPa√m%s'], ...
            agent_state.function.source, ...
            agent_state.function.func_str, ...
            param_order_text, ...
            agent_state.region.detected_slope_range(1), ...
            agent_state.region.detected_slope_range(2), ...
            agent_state.model.C, agent_state.model.m, ...
            agent_state.validation.rsquared_log, ...
            agent_state.validation.rsquared, ...
            agent_state.validation.rsquared_adj, ...
            agent_state.validation.rmse, ...
            agent_state.region.n_points, agent_state.region.total_points, ...
            agent_state.region.DeltaK_min, agent_state.region.DeltaK_max, ...
            ci_text);
        
        result.metadata = struct('C', agent_state.model.C, 'm', agent_state.model.m);
    else
        result.success = false;
        result.message = 'Cannot finalize: model not fitted yet';
        result.metadata = struct();
    end
end