clc; clear all; close all;

%% Get the script's directory and set up file paths
scriptDir = fileparts(which(mfilename('fullpath')));
dftFile = fullfile(scriptDir, 'Helicene_DFT.csv');

% Check if DFT data file exists
if ~exist(dftFile, 'file')
    error('DFT data file not found in script directory: %s\nPlease ensure Helicene_DFT.csv is in the same folder as this script.', dftFile);
end

fprintf('Script directory: %s\n', scriptDir);
fprintf('DFT data location: %s\n', dftFile);

%% Initialize AI Model for ReAct Reasoning
ai_model = openAIChat([ ...
    'You are a ReAct agent that models strain effects on helicene HOMO-LUMO gaps. ' ...
    'The base Kuhn equation is PROVIDED to you. Your task is to modify it for strain effects. ' ...
    'At each step: 1) THINK about what to do next, 2) Choose an ACTION, 3) OBSERVE the result. ' ...
    'Available tools: load_data, generate_strain_function, test_function, calculate_response, plot_results, finalize. ' ...
    'Respond in this EXACT format:\n' ...
    'THOUGHT: <your reasoning>\n' ...
    'ACTION: {"tool": "<tool_name>", "input": <json_input>}\n'], ...
    'ModelName', 'gpt-4');

%% HARDCODED BASE KUHN EQUATION (as specified)
base_kuhn_equation = 'gap = (h^2.*(s+1)./(8*m*(l0.^2))) + (v0.*(1-(1./s)))';

fprintf('=== HARDCODED BASE KUHN EQUATION ===\n');
fprintf('%s\n\n', base_kuhn_equation);

%% Initialize Tool Registry
tools = struct();

% Tool 1: Load Experimental Data
tools.load_data = struct();
tools.load_data.description = 'Load strain-gap experimental data from CSV file';
tools.load_data.input_schema = {'dft_file'};
tools.load_data.execute = @action_load_data;

% Tool 2: Generate Strain-Modified Function (USES HARDCODED BASE)
tools.generate_strain_function = struct();
tools.generate_strain_function.description = 'Generate MATLAB function modifying the HARDCODED Kuhn equation for strain';
tools.generate_strain_function.input_schema = {};
tools.generate_strain_function.execute = @action_generate_strain_function;

% Tool 3: Test Function
tools.test_function = struct();
tools.test_function.description = 'Test generated function with sample strain values';
tools.test_function.input_schema = {'test_strains'};
tools.test_function.execute = @action_test_function;

% Tool 4: Calculate Strain Response
tools.calculate_response = struct();
tools.calculate_response.description = 'Calculate gap values across full strain range';
tools.calculate_response.input_schema = {'strain_min', 'strain_max'};
tools.calculate_response.execute = @action_calculate_response;

% Tool 5: Plot Results
tools.plot_results = struct();
tools.plot_results.description = 'Plot experimental data vs model predictions';
tools.plot_results.input_schema = {};
tools.plot_results.execute = @action_plot_results;

% Tool 6: Finalize
tools.finalize = struct();
tools.finalize.description = 'Complete the task and show results';
tools.finalize.input_schema = {};
tools.finalize.execute = @action_finalize;

%% Initialize Agent State
agent_state = struct();
agent_state.complete = false;
agent_state.iteration = 0;
agent_state.max_iterations = 10;

% File paths - now using relative paths (only DFT data)
agent_state.dft_file = dftFile;

% HARDCODED base equation (stored in state)
agent_state.base_equation = struct();
agent_state.base_equation.latex = base_kuhn_equation;
agent_state.base_equation.hardcoded = true;

% Data state
agent_state.data = struct('loaded', false, 'strain', [], 'gap', []);

% Physical parameters (HARDCODED as in your script)
agent_state.params = struct();
agent_state.params.n = 3:300;  % helicene range
agent_state.params.h = 2*pi;    % Planck's constant
agent_state.params.m = 1;        % electron mass
agent_state.params.v0 = 0.06;    % base gap parameter
agent_state.params.angstrom_to_bohr = 1.88973;

% Pre-calculate n-dependent values (as in your script)
agent_state.params.s = 4*agent_state.params.n + 2;
agent_state.params.l0 = (3.*agent_state.params.n + 3).*1.4.*agent_state.params.angstrom_to_bohr;

% Function state - store as anonymous function string
agent_state.function = struct();
agent_state.function.func_str = '';
agent_state.function.ready = false;
agent_state.function.test_passed = false;
agent_state.function.source = 'LLM generated using hardcoded base';

% Results state
agent_state.results = struct();
agent_state.results.strain_array = -40:1:150;  % strain in percentage
agent_state.results.gap_strain = [];
agent_state.results.gap_avg = [];

% Flag to track if plot was created
agent_state.plot_created = false;

% History
agent_state.history = {};

fprintf('=== ReAct Agent for Strain-Modified Kuhn Equation Started ===\n');
fprintf('BASE EQUATION: HARDCODED (provided to LLM)\n');
fprintf('Task: Generate strain modifications to match experimental data\n');
fprintf('Data file: %s\n', agent_state.dft_file);
fprintf('Available tools: %s\n\n', strjoin(fieldnames(tools)', ', '));

%% Main ReAct Loop
while ~agent_state.complete && agent_state.iteration < agent_state.max_iterations
    agent_state.iteration = agent_state.iteration + 1;
    
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('ITERATION %d\n', agent_state.iteration);
    fprintf('%s\n', repmat('=', 1, 60));
    
    %% Step 1: LLM THINKS and chooses ACTION
    thought_action = get_llm_decision(ai_model, agent_state);
    
    % Parse response
    [thought, action_json] = parse_react_response(thought_action);
    
    fprintf('\nTHOUGHT: %s\n', thought);
    fprintf('ACTION: %s\n', action_json);
    
    %% Step 2: Parse action
    try
        action = jsondecode(action_json);
        tool_name = action.tool;
        tool_input = action.input;
        
        if ~isfield(tools, tool_name)
            error('Unknown tool: %s', tool_name);
        end
        
        fprintf('Executing tool: %s\n', tool_name);
        
    catch ME
        observation = sprintf('Failed to parse action: %s', ME.message);
        fprintf('\nOBSERVATION: %s\n', observation);
        agent_state = record_history(agent_state, thought, action_json, observation, false);
        continue;
    end
    
    %% Step 3: Execute tool
    try
        [result, agent_state] = tools.(tool_name).execute(tool_input, agent_state);
        observation = result.message;
        success = true;
        fprintf('\nOBSERVATION: %s\n', observation);
        agent_state = update_state_from_result(agent_state, tool_name, result);
        
    catch ME
        observation = sprintf('ERROR: %s', ME.message);
        fprintf('\nOBSERVATION: %s\n', observation);
        success = false;
        
        % Critical failure - no fallback
        if strcmp(tool_name, 'generate_strain_function')
            fprintf('\n*** CRITICAL: LLM failed to generate strain modification ***\n');
            fprintf('Error: %s\n', ME.message);
            error('Strain function generation failed - no fallback');
        end
    end
    
    %% Step 4: Record history
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

if agent_state.function.ready
    fprintf('\n=== FINAL RESULTS ===\n');
    fprintf('Base equation: %s (HARDCODED)\n', agent_state.base_equation.latex);
    fprintf('Strain-modified function: %s\n', agent_state.function.func_str);
    fprintf('Source: %s\n', agent_state.function.source);
    fprintf('Test passed: %d\n', agent_state.function.test_passed);
    
    % Only plot if not already created by agent
    if agent_state.data.loaded && ~isempty(agent_state.results.gap_avg) && ~agent_state.plot_created
        create_final_plot(agent_state);
    elseif agent_state.plot_created
        fprintf('\n✓ Plot already created by agent during execution.\n');
    end
end

fprintf('\n=== REASONING TRACE ===\n');
for i = 1:length(agent_state.history)
    fprintf('\n--- Step %d ---\n', i);
    fprintf('THOUGHT: %s\n', agent_state.history{i}.thought);
    fprintf('ACTION: %s\n', agent_state.history{i}.action);
    fprintf('RESULT: %s\n', agent_state.history{i}.observation);
end

%% ==================== Core Functions ====================

function response = get_llm_decision(model, agent_state)
    prompt = build_react_prompt(agent_state);
    response = generate(model, prompt);
    response = strtrim(string(response));
end

function prompt = build_react_prompt(agent_state)
    % Get short filename for display
    [~, dft_filename, dft_ext] = fileparts(agent_state.dft_file);
    shortDftFile = [dft_filename, dft_ext];
    
    prompt = [ ...
        'You are a ReAct agent for modeling strain effects on helicene HOMO-LUMO gaps.\n\n' ...
        'TASK: Modify the HARDCODED base Kuhn equation to account for mechanical strain.\n\n' ...
        'HARDCODED BASE KUHN EQUATION (provided):\n' ...
        agent_state.base_equation.latex '\n\n' ...
        'Where:\n' ...
        '- n = helicene number (3 to 300)\n' ...
        '- h = 2π (Planck''s constant in Hartree)\n' ...
        '- m = 1 (electron mass in Hartree)\n' ...
        '- s = 4n+2 (π electrons)\n' ...
        '- l0 = (3n+3)*1.4*1.88973 (helical length in bohr)\n' ...
        '- v0 = 0.06 (base gap parameter in Hartree)\n\n' ...
        'PHYSICAL REQUIREMENTS for strain modification:\n' ...
        '1. Tension (epsilon > 0): Steeper parabolic response, maximum at epsilon = 0.25 (25%% strain)\n' ...
        '2. Compression (epsilon < 0): Gentler inverse parabolic decrease\n' ...
        '3. Strain affects both the helical length L and the parameter V0\n' ...
        '4. Input epsilon is strain as DECIMAL (e.g., 0.25 for 25%%)\n\n' ...
        'IMPORTANT - MATLAB SYNTAX REQUIREMENTS:\n' ...
        'You MUST output an ANONYMOUS FUNCTION, NOT a full function definition.\n' ...
        'Format: strain_kuhn = @(epsilon, n, h, m, s, l0, v0) ...\n' ...
        'Use element-wise operations: .*, ./, .^\n' ...
        'Do NOT use "function" keyword.\n' ...
        'Output ONLY the anonymous function line, nothing else.\n\n' ...
        'EXAMPLE (just for format, your physics may differ):\n' ...
        'strain_kuhn = @(epsilon, n, h, m, s, l0, v0) (h^2.*(s+1)./(8*m.*(l0.*(1+epsilon)).^2)) + (v0.*(1+2.5*epsilon.*(1-epsilon/0.25)).*(1-(1./s)));\n\n' ...
        'Data file (to be loaded - located in same folder as script):\n' ...
        '- DFT data: ' shortDftFile '\n\n' ...
        'AVAILABLE TOOLS:\n' ...
        '- load_data: Load experimental data (input: {}) - automatically finds DFT file in script folder\n' ...
        '- generate_strain_function: Create MATLAB function modifying base equation for strain (input: {})\n' ...
        '- test_function: Test with sample strains (input: {"test_strains": [values]})\n' ...
        '- calculate_response: Calculate across full strain range (input: {"strain_min": -40, "strain_max": 150})\n' ...
        '- plot_results: Create comparison plots (input: {})\n' ...
        '- finalize: Complete task (input: {})\n\n' ...
        'CURRENT STATE:\n'];
    
    if agent_state.data.loaded
        prompt = [prompt sprintf('- Data loaded: DFT (%d pts, strain %.1f-%.1f%%)\n', ...
            length(agent_state.data.strain), min(agent_state.data.strain), max(agent_state.data.strain))];
    else
        prompt = [prompt '- Data not loaded yet\n'];
        prompt = [prompt sprintf('  DFT data file is in script folder: %s\n', shortDftFile)];
    end
    
    if agent_state.function.ready
        prompt = [prompt '- Strain modification function ready\n'];
        if agent_state.function.test_passed
            prompt = [prompt '  Function test: PASSED\n'];
        end
    end
    
    % Safely check history
    if isfield(agent_state, 'history') && ~isempty(agent_state.history)
        prompt = [prompt '\nRECENT HISTORY:\n'];
        start_idx = max(1, length(agent_state.history) - 2);
        for i = start_idx:length(agent_state.history)
            h = agent_state.history{i};
            if isstruct(h) && all(isfield(h, {'action_preview', 'result_preview'}))
                prompt = [prompt sprintf('Step %d: %s -> %s\n', i, h.action_preview, h.result_preview)];
            end
        end
    end
    
    prompt = [prompt ...
        '\nWhat should you do next? Remember: base equation is HARDCODED, you only need to modify for strain.\n' ...
        'The data file is in the same folder as this script. Use load_data with empty input to load it automatically.\n' ...
        'Respond in EXACT format:\n' ...
        'THOUGHT: <your reasoning>\n' ...
        'ACTION: {"tool": "<tool_name>", "input": <json_object>}\n'];
end

function [thought, action_json] = parse_react_response(response)
    response = char(response);
    
    thought_pattern = 'THOUGHT:\s*(.*?)(?=ACTION:|$)';
    thought_tokens = regexp(response, thought_pattern, 'tokens', 'once');
    if ~isempty(thought_tokens)
        thought = strtrim(thought_tokens{1});
    else
        thought = "No thought provided";
    end
    
    action_pattern = 'ACTION:\s*(\{.*\})';
    action_tokens = regexp(response, action_pattern, 'tokens', 'once');
    if ~isempty(action_tokens)
        action_json = strtrim(action_tokens{1});
    else
        json_pattern = '\{.*"tool".*\}';
        action_tokens = regexp(response, json_pattern, 'match', 'once');
        if ~isempty(action_tokens)
            action_json = action_tokens;
        else
            % Default action with empty input for automatic file location
            action_json = '{"tool": "load_data", "input": {}}';
        end
    end
    action_json = regexprep(action_json, '\s+', ' ');
end

function agent_state = record_history(agent_state, thought, action, observation, success)
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
    
    history_entry = struct();
    history_entry.thought = char(thought);
    history_entry.action = char(action);
    history_entry.observation = char(observation);
    history_entry.action_preview = char(action_preview);
    history_entry.result_preview = char(result_preview);
    history_entry.success = success;
    history_entry.timestamp = datestr(now);
    
    if isempty(agent_state.history)
        agent_state.history = {history_entry};
    else
        agent_state.history{end+1} = history_entry;
    end
end

function agent_state = update_state_from_result(agent_state, tool_name, result)
    if result.success
        switch tool_name
            case 'load_data'
                agent_state.data.loaded = true;
                agent_state.data.strain = result.metadata.strain;
                agent_state.data.gap = result.metadata.gap;
                
            case 'generate_strain_function'
                agent_state.function.ready = true;
                agent_state.function.func_str = result.metadata.func_str;
                agent_state.function.test_passed = result.metadata.test_passed;
                
            case 'calculate_response'
                agent_state.results.gap_strain = result.metadata.gap_strain;
                agent_state.results.gap_avg = result.metadata.gap_avg;
                
            case 'plot_results'
                agent_state.plot_created = true;
        end
    end
end

%% ==================== Tool Implementations ====================

function [result, agent_state] = action_load_data(input, agent_state)
    result = struct();
    
    try
        % Use the file path stored in agent_state
        if isstruct(input) && isfield(input, 'dft_file') && ~isempty(input.dft_file)
            dft_file = input.dft_file;
        else
            dft_file = agent_state.dft_file;
        end
        
        fprintf('Attempting to load DFT data from: %s\n', dft_file);
        
        % Load DFT data
        if ~exist(dft_file, 'file')
            error('DFT data file not found: %s', dft_file);
        end
        
        data = readmatrix(dft_file);
        data = rmmissing(data);
        if size(data, 2) < 2
            error('DFT data file must contain at least 2 columns (strain and gap)');
        end
        strain = data(:, 1);
        gap = data(:, 2);
        
        agent_state.data.loaded = true;
        agent_state.data.strain = strain;
        agent_state.data.gap = gap;
        
        result.success = true;
        result.message = sprintf('Loaded DFT data (%d pts, strain %.1f-%.1f%%)', ...
            length(strain), min(strain), max(strain));
        result.metadata = struct('strain', strain, 'gap', gap);
        
    catch ME
        result.success = false;
        result.message = sprintf('Failed to load data: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_generate_strain_function(~, agent_state)
    result = struct();
    
    try
        model = openAIChat('You are a MATLAB code generator. Output ONLY valid MATLAB anonymous functions.', ...
            ModelName="gpt-4", Temperature=0.1);
        
        % Prompt using the HARDCODED base equation
        prompt = sprintf([ ...
            'Create a MATLAB ANONYMOUS FUNCTION that modifies this HARDCODED base Kuhn equation for strain:\n\n' ...
            'BASE EQUATION: %s\n\n' ...
            'PHYSICS OF STRAIN MODIFICATION:\n' ...
            '- Tension (epsilon > 0): Steeper parabolic response, maximum at epsilon = 0.25 (25%%)\n' ...
            '- Compression (epsilon < 0): Gentler inverse parabolic decrease\n' ...
            '- Strain affects both helical length L and parameter V0\n\n' ...
            'CRITICAL - MUST BE ANONYMOUS FUNCTION with name "strain_kuhn":\n' ...
            'Format: strain_kuhn = @(epsilon, n, h, m, s, l0, v0) ...\n' ...
            'Use element-wise operations: .*, ./, .^\n' ...
            'The function should modify l0 and v0 based on epsilon.\n\n' ...
            'EXAMPLE of correct format (but with your physics):\n' ...
            'strain_kuhn = @(epsilon, n, h, m, s, l0, v0) (h^2.*(s+1)./(8*m.*(l0.*(1+epsilon)).^2)) + (v0.*(1+2.5*epsilon.*(1-epsilon/0.25)).*(1-(1./s)));\n\n' ...
            'Output ONLY the anonymous function line, nothing else. No explanations, no markdown.'], ...
            agent_state.base_equation.latex);
        
        response = generate(model, prompt);
        response = strtrim(string(response));
        
        % Clean response
        func_str = clean_matlab_response(response);
        
        if isempty(func_str) || ~contains(func_str, 'strain_kuhn') || ~contains(func_str, '@(')
            fprintf('\n=== DEBUG: Raw LLM Response ===\n');
            fprintf('%s\n', response);
            fprintf('==============================\n');
            error('LLM failed to generate valid anonymous function');
        end
        
        % Ensure semicolon
        if ~endsWith(strtrim(func_str), ';')
            func_str = [strtrim(func_str), ';'];
        end
        
        % Test the function
        try
            % Test parameters
            n_test = 10;
            s_test = 4*n_test + 2;
            l0_test = (3*n_test + 3)*1.4*1.88973;
            h = 2*pi;
            m = 1;
            v0 = 0.06;
            
            % Evaluate the anonymous function
            eval(func_str);
            
            if ~exist('strain_kuhn', 'var')
                error('Function strain_kuhn was not created');
            end
            
            % Test compression and tension
            test_comp = strain_kuhn(-0.2, n_test, h, m, s_test, l0_test, v0);
            test_tension = strain_kuhn(0.25, n_test, h, m, s_test, l0_test, v0);
            
            if isempty(test_comp) || isempty(test_tension) || any(isnan(test_comp)) || any(isnan(test_tension))
                error('Function returned invalid values');
            end
            
            test_passed = true;
            fprintf('✓ Function test passed\n');
            fprintf('  Compression (-20%%): %.4f Ha\n', test_comp);
            fprintf('  Tension (+25%%): %.4f Ha\n', test_tension);
            
        catch test_err
            error('Function test failed: %s\nFunction was: %s', test_err.message, func_str);
        end
        
        % Store in workspace
        assignin('base', 'agent_func_str', func_str);
        
        agent_state.function.func_str = func_str;
        agent_state.function.test_passed = test_passed;
        agent_state.function.ready = true;
        
        result.success = true;
        result.message = sprintf('Generated anonymous function using HARDCODED base equation:\n%s', func_str);
        result.metadata = struct('func_str', func_str, 'test_passed', test_passed);
        
    catch ME
        result.success = false;
        result.message = sprintf('Failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function clean = clean_matlab_response(raw)
    raw = char(raw);
    
    % Remove markdown
    raw = strrep(raw, '```matlab', '');
    raw = strrep(raw, '```', '');
    raw = strrep(raw, '`', '');
    
    % Look for anonymous function pattern with strain_kuhn
    lines = splitlines(raw);
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if contains(line, 'strain_kuhn') && contains(line, '@(')
            clean = line;
            return;
        end
    end
    
    % If no direct match, try to find any line with @(
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if contains(line, '@(') && (contains(line, 'epsilon') || contains(line, 'n'))
            clean = sprintf('strain_kuhn = %s;', line);
            return;
        end
    end
    
    clean = '';
end

function [result, agent_state] = action_test_function(input, agent_state)
    result = struct();
    
    try
        if isstruct(input) && isfield(input, 'test_strains')
            test_strains = input.test_strains;
        else
            test_strains = [-0.2, -0.1, 0, 0.1, 0.25];
        end
        
        % Test with n=10
        n_test = 10;
        s_test = 4*n_test + 2;
        l0_test = (3*n_test + 3)*1.4*1.88973;
        h = 2*pi;
        m = 1;
        v0 = 0.06;
        
        if ~evalin('base', 'exist(''strain_kuhn'', ''var'')')
            evalin('base', agent_state.function.func_str);
        end
        strain_kuhn = evalin('base', 'strain_kuhn');
        
        results = zeros(length(test_strains), 1);
        for i = 1:length(test_strains)
            results(i) = strain_kuhn(test_strains(i), n_test, h, m, s_test, l0_test, v0);
        end
        
        result.success = true;
        result.message = sprintf('Test passed. Results: %s', num2str(results', '%.4e '));
        result.metadata = struct('test_results', results);
        
        agent_state.function.test_passed = true;
        
    catch ME
        result.success = false;
        result.message = sprintf('Test failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_calculate_response(input, agent_state)
    result = struct();
    
    try
        if isstruct(input) && isfield(input, 'strain_min') && isfield(input, 'strain_max')
            strain_min = input.strain_min;
            strain_max = input.strain_max;
        else
            strain_min = -40;
            strain_max = 150;
        end
        
        strain_array = strain_min:1:strain_max;
        n = agent_state.params.n;
        h = agent_state.params.h;
        m = agent_state.params.m;
        v0 = agent_state.params.v0;
        s = agent_state.params.s;
        l0 = agent_state.params.l0;
        
        if ~evalin('base', 'exist(''strain_kuhn'', ''var'')')
            evalin('base', agent_state.function.func_str);
        end
        strain_kuhn = evalin('base', 'strain_kuhn');
        
        gap_strain = zeros(length(strain_array), length(n));
        for i = 1:length(strain_array)
            epsilon = strain_array(i) / 100;
            gap_strain(i, :) = strain_kuhn(epsilon, n, h, m, s, l0, v0);
        end
        
        gap_avg = mean(gap_strain, 2);
        
        agent_state.results.strain_array = strain_array;
        agent_state.results.gap_strain = gap_strain;
        agent_state.results.gap_avg = gap_avg;
        
        result.success = true;
        result.message = sprintf('Calculated response for %d strains', length(strain_array));
        result.metadata = struct('gap_strain', gap_strain, 'gap_avg', gap_avg);
        
    catch ME
        result.success = false;
        result.message = sprintf('Calculation failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_plot_results(~, agent_state)
    result = struct();
    
    try
        if ~agent_state.data.loaded || isempty(agent_state.results.gap_avg)
            error('Need both data and results to plot');
        end
        
        % Create plot with a specific tag
        create_final_plot(agent_state);
        
        result.success = true;
        result.message = 'Plot created successfully';
        result.metadata = struct();
        
    catch ME
        result.success = false;
        result.message = sprintf('Plotting failed: %s', ME.message);
        result.metadata = struct();
    end
end

function [result, agent_state] = action_finalize(~, agent_state)
    result = struct();

    if agent_state.function.ready && agent_state.data.loaded && ~isempty(agent_state.results.gap_avg)
        result.success = true;
        result.message = sprintf([ ...
            'Task complete!\n' ...
            'Base equation: HARDCODED\n' ...
            'Strain modification: %s\n' ...
            'Test passed: %d\n' ...
            'Plot created with experimental data comparison'], ...
            agent_state.function.source, agent_state.function.test_passed);
        result.metadata = struct('func_str', agent_state.function.func_str);
    else
        result.success = false;
        result.message = 'Cannot finalize: incomplete workflow';
        result.metadata = struct();
    end
end

%% Helper function to create the final plot (used by both agent and final summary)
function create_final_plot(agent_state)
    % Check if plot with this tag already exists
    existing_fig = findobj('Type', 'figure', 'Tag', 'strain_plot');
    if ~isempty(existing_fig)
        % Figure already exists, bring it to front and return
        figure(existing_fig);
        return;
    end
    
    % Create new figure with tag
    figure('Position', [100, 100, 900, 600], 'Tag', 'strain_plot');
    hold on;
    
    plot(agent_state.data.strain, agent_state.data.gap, 'bs-', ...
        'MarkerSize', 8, 'LineWidth', 2, 'DisplayName', 'Helicene (DFT data)');
    plot(agent_state.results.strain_array, agent_state.results.gap_avg, 'r--', ...
        'LineWidth', 2.5, 'DisplayName', 'AI-Modified Kuhn Equation');
    
    xlabel('Strain (%)');
    ylabel('HOMO-LUMO Gap (Ha)');
    legend('Location', 'best');
    grid on;
    
    hold off;
    drawnow;
end