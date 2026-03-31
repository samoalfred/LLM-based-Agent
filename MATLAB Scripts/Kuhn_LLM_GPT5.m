%% Pure ReAct Agent for Helicene HOMO-LUMO Gap Fitting (GPT-5 Version) - PORTABLE VERSION
% This version will work on any computer as long as the data file is in the
% same folder as this MATLAB script.
%
% To use:
% 1. Place this script and your data CSV file in the same folder
% 2. Update the filename variable below to match your CSV file name
% 3. Run the script

clc; clear all; close all;

%% CONFIGURATION - CHANGE THIS IF NEEDED
% Data file name (should be in the same folder as this script)
DATA_FILENAME = 'Kuhn_dataset.csv';  % <-- CHANGE THIS to your file name

%% Get the current script's directory and build full path
% This works on any computer - finds where this script is located
script_dir = fileparts(which(mfilename('fullpath')));
full_data_path = fullfile(script_dir, DATA_FILENAME);
pdf_filename = fullfile(script_dir, 'arXiv_2303.03490.pdf');

fprintf('Script directory: %s\n', script_dir);
fprintf('Looking for data file: %s\n', full_data_path);
fprintf('PDF will be saved to: %s\n', pdf_filename);

%% Initialize AI Model for ReAct Reasoning - GPT-5 (no temperature)
ai_model = openAIChat([ ...
    'You are a ReAct agent that fits the HOMO‑LUMO gap of helicenes using Kuhn''s model. ' ...
    'At each step: 1) THINK about what to do next based on current state, ' ...
    '2) Choose an ACTION from available tools, 3) OBSERVE the result. ' ...
    'Available tools: load_data, search_arxiv, download_pdf, extract_text, ' ...
    'extract_equation, extract_equation_html, convert_to_matlab, test_function, fit_model, validate_fit, ' ...
    'create_plots, finalize. ' ...
    'Respond in this EXACT format:\n' ...
    'THOUGHT: <your reasoning>\n' ...
    'ACTION: {"tool": "<tool_name>", "input": <json_input>}\n' ...
    'Keep thoughts concise and focused on what to do next.'], ...
    'ModelName', 'gpt-5');  % Removed Temperature

%% Initialize Tool Registry
tools = struct();

% Tool 1: Load Data
tools.load_data = struct();
tools.load_data.description = 'Load helicene dataset (n, gap in eV) and convert to Hartree';
tools.load_data.input_schema = {'filename'};
tools.load_data.execute = @action_load_data;

% Tool 2: Search arXiv
tools.search_arxiv = struct();
tools.search_arxiv.description = 'Search arXiv for the paper title and return the paper ID';
tools.search_arxiv.input_schema = {'paper_title'};
tools.search_arxiv.execute = @action_search_arxiv;

% Tool 3: Download PDF
tools.download_pdf = struct();
tools.download_pdf.description = 'Download PDF from arXiv using the paper ID to MATLAB directory';
tools.download_pdf.input_schema = {'paper_id'};
tools.download_pdf.execute = @action_download_pdf;

% Tool 4: Extract Text from PDF
tools.extract_text = struct();
tools.extract_text.description = 'Extract plain text from the downloaded PDF';
tools.extract_text.input_schema = {};  % No input needed - uses fixed path
tools.extract_text.execute = @action_extract_text;

% Tool 5: Extract Kuhn's Equation (LaTeX) from PDF text
tools.extract_equation = struct();
tools.extract_equation.description = 'Use LLM to extract Kuhn''s equation from paper text (LaTeX)';
tools.extract_equation.input_schema = {};
tools.extract_equation.execute = @action_extract_equation;

% Tool 6: Extract Kuhn's Equation from arXiv HTML (with token limit handling)
tools.extract_equation_html = struct();
tools.extract_equation_html.description = 'Fetch arXiv HTML and extract Kuhn''s equation (with token limit handling)';
tools.extract_equation_html.input_schema = {'paper_id'};
tools.extract_equation_html.execute = @action_extract_equation_html;

% Tool 7: Convert LaTeX to MATLAB (MUST come from LLM – NO FALLBACK)
tools.convert_to_matlab = struct();
tools.convert_to_matlab.description = 'Convert LaTeX equation to MATLAB function using LLM (strict, no fallback)';
tools.convert_to_matlab.input_schema = {};
tools.convert_to_matlab.execute = @action_convert_to_matlab;

% Tool 8: Test Function
tools.test_function = struct();
tools.test_function.description = 'Test the generated MATLAB function with sample N values';
tools.test_function.input_schema = {'test_N', 'test_v0'};
tools.test_function.execute = @action_test_function;

% Tool 9: Fit Model
tools.fit_model = struct();
tools.fit_model.description = 'Fit the model to data using lsqcurvefit';
tools.fit_model.input_schema = {'initial_v0'};
tools.fit_model.execute = @action_fit_model;

% Tool 10: Validate Fit
tools.validate_fit = struct();
tools.validate_fit.description = 'Calculate R² and other fit quality metrics';
tools.validate_fit.input_schema = {};
tools.validate_fit.execute = @action_validate_fit;

% Tool 11: Create Plots
tools.create_plots = struct();
tools.create_plots.description = 'Plot data and fitted curve';
tools.create_plots.input_schema = {};
tools.create_plots.execute = @action_create_plots;

% Tool 12: Finalize
tools.finalize = struct();
tools.finalize.description = 'Complete the task and show final results';
tools.finalize.input_schema = {};
tools.finalize.execute = @action_finalize;

%% Initialize Agent State
agent_state = struct();
agent_state.complete = false;
agent_state.iteration = 0;
agent_state.max_iterations = 20;

% Task context
agent_state.context = 'Fit the Kuhn model to helicene HOMO-LUMO gap data using the equation extracted from the paper.';

% File paths - Now using dynamic directory
agent_state.data_dir = script_dir;
agent_state.filename = full_data_path;
agent_state.pdf_filename = pdf_filename;
agent_state.pdf_text = '';

% Paper info
agent_state.paper_title = 'Computational study of optical absorption spectra of helicenes as applied to strain sensing';
agent_state.paper_id = '2303.03490v1';  % Set directly to avoid search

% Data state
agent_state.data = struct('loaded', false, 'n', [], 'gap_ev', [], 'gap_hartree', [], 'filename', '');

% Equation state
agent_state.equation = struct('ready', false, 'latex', '', 'func_str', '', 'source', 'none', 'test_passed', false, 'confidence', 0);
agent_state.extraction_attempts = struct('html', false, 'pdf', false);

% Model state
agent_state.model = struct('fitted', false, 'v0', NaN, 'v0_ev', NaN, 'resnorm', NaN, 'exitflag', NaN);

% Validation state
agent_state.validation = struct('rsquared', NaN, 'rmse_ev', NaN, 'residuals', []);

% History
agent_state.history = {};

fprintf('\n=== Pure ReAct Agent for Helicene HOMO-LUMO Gap Fitting (GPT-5) Started ===\n');
fprintf('Task: Fit Kuhn model to helicene data\n');
fprintf('Data file: %s\n', agent_state.filename);
fprintf('PDF will be saved to: %s\n', agent_state.pdf_filename);
fprintf('Paper ID: %s\n', agent_state.paper_id);
fprintf('Available tools: %s\n\n', strjoin(fieldnames(tools)', ', '));
fprintf('*** NOTE: Kuhn equation MUST be extracted by LLM and converted to MATLAB – no fallback ***\n');
fprintf('*** PDF saved to same folder as script for reliable access ***\n\n');

%% Check if data file exists
if ~exist(agent_state.filename, 'file')
    fprintf('\n!!! WARNING: Data file not found at: %s\n', agent_state.filename);
    fprintf('Please ensure the file "%s" is in the same folder as this script.\n', DATA_FILENAME);
    fprintf('Current script location: %s\n', script_dir);
    fprintf('Looking for file: %s\n', full_data_path);
    fprintf('\nPress any key to continue (will fail)...\n');
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
        
        if ~isfield(tools, tool_name)
            error('Unknown tool: %s', tool_name);
        end
        
        fprintf('Executing tool: %s\n', tool_name);
        
    catch ME
        observation = sprintf('Failed to parse action: %s. Action must be valid JSON with "tool" and "input" fields.', ME.message);
        fprintf('\nOBSERVATION: %s\n', observation);
        agent_state = record_history(agent_state, thought, action_json, observation, false);
        continue;
    end
    
    %% Step 3: Execute the tool
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
        
        % If equation conversion fails, agent halts (no fallback)
        if strcmp(tool_name, 'convert_to_matlab')
            fprintf('\n*** CRITICAL ERROR: LLM failed to generate MATLAB function. ***\n');
            fprintf('*** No fallback provided – agent cannot continue. ***\n');
            error('Equation conversion failed – no fallback available');
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
    fprintf('Equation confidence: %d/11\n', agent_state.equation.confidence);
    fprintf('MATLAB function: %s\n', agent_state.equation.func_str);
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
    prompt = build_react_prompt(agent_state);
    response = generate(model, prompt);
    response = strtrim(string(response));
end

function prompt = build_react_prompt(agent_state)
    prompt = [ ...
        'You are a ReAct agent for helicene HOMO-LUMO gap fitting.\n\n' ...
        'TASK: ' agent_state.context '\n\n' ...
        'The data file is located at: ' agent_state.filename '\n' ...
        'Paper ID: ' agent_state.paper_id '\n\n' ...
        'AVAILABLE TOOLS:\n' ...
        '- load_data: Load CSV file (input: {"filename": "path"})\n' ...
        '- download_pdf: Download PDF using paper ID to fixed directory (input: {"paper_id": "id"})\n' ...
        '- extract_text: Extract plain text from PDF (input: {} - uses fixed path)\n' ...
        '- extract_equation: Use LLM to extract Kuhn''s equation as LaTeX from PDF text (input: {})\n' ...
        '- extract_equation_html: Fetch arXiv HTML and extract Kuhn''s equation (input: {"paper_id": "id"})\n' ...
        '- convert_to_matlab: Convert LaTeX to MATLAB function (input: {}) – *** CRITICAL: MUST output valid MATLAB, no fallback ***\n' ...
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
    end

    if ~isempty(agent_state.pdf_text)
        prompt = [prompt sprintf('- PDF text extracted (%d characters)\n', length(agent_state.pdf_text))];
    end

    if ~isempty(agent_state.equation.latex)
        prompt = [prompt sprintf('- Equation extracted (LaTeX): %s\n', agent_state.equation.latex)];
        prompt = [prompt sprintf('- Equation confidence: %d/11\n', agent_state.equation.confidence)];
    end

    if agent_state.equation.ready
        prompt = [prompt sprintf('- MATLAB function ready (from %s)\n', agent_state.equation.source)];
        if agent_state.equation.test_passed
            prompt = [prompt '  Function test: PASSED\n'];
        end
    else
        prompt = [prompt '- MATLAB function not generated yet – MUST use convert_to_matlab\n'];
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

    prompt = [prompt ...
        '\nBased on current state and history, what should you do next?\n' ...
        'IMPORTANT: The PDF is always saved to: ' agent_state.pdf_filename '\n' ...
        'So extract_text does not need a path input.\n' ...
        'convert_to_matlab MUST produce a valid MATLAB function. No fallback exists.\n' ...
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
                agent_state.data.n = result.metadata.n;
                agent_state.data.gap_ev = result.metadata.gap_ev;
                agent_state.data.gap_hartree = result.metadata.gap_hartree;

            case 'download_pdf'
                % PDF downloaded successfully - path already set in agent_state

            case 'extract_text'
                agent_state.pdf_text = result.metadata.text;

            case {'extract_equation', 'extract_equation_html'}
                agent_state.equation.latex = result.metadata.latex;
                if isfield(result.metadata, 'confidence')
                    agent_state.equation.confidence = result.metadata.confidence;
                end

            case 'convert_to_matlab'
                agent_state.equation.ready = result.metadata.test_passed;
                agent_state.equation.source = result.metadata.source;
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
        if isstruct(input) && isfield(input, 'filename')
            filename = input.filename;
        else
            filename = agent_state.filename;
        end

        data = readmatrix(filename);
        data = rmmissing(data);
        n = data(:,1);
        gap_ev = data(:,2);
        hat2ev = 27.2114;
        gap_hartree = gap_ev / hat2ev;

        agent_state.data.loaded = true;
        agent_state.data.n = n;
        agent_state.data.gap_ev = gap_ev;
        agent_state.data.gap_hartree = gap_hartree;
        agent_state.data.filename = filename;

        assignin('base', 'agent_n', n);
        assignin('base', 'agent_gap_hartree', gap_hartree);

        result.success = true;
        result.message = sprintf('Loaded %d data points. n range: [%d, %d], Gap range: [%.3f, %.3f] eV', ...
            length(n), min(n), max(n), min(gap_ev), max(gap_ev));
        result.metadata = struct('n', n, 'gap_ev', gap_ev, 'gap_hartree', gap_hartree);
    catch ME
        result.success = false;
        result.message = sprintf('Failed to load data: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_search_arxiv(~, agent_state)
    % This tool is simplified since we already have the paper ID
    result = struct();
    result.success = true;
    result.message = sprintf('Paper ID already set to: %s', agent_state.paper_id);
    result.metadata = struct('paper_id', agent_state.paper_id);
end

function [result, agent_state] = action_download_pdf(input, agent_state)
    result = struct();
    try
        if isstruct(input) && isfield(input, 'paper_id')
            paper_id = input.paper_id;
        else
            paper_id = agent_state.paper_id;
        end

        % Clean paper ID
        paper_id = regexprep(paper_id, '^arXiv:', '');
        paper_id = regexprep(paper_id, 'v\d+$', '');
        
        % Use fixed filename in MATLAB directory
        pdf_filename = agent_state.pdf_filename;
        
        % Create directory if it doesn't exist
        pdf_dir = fileparts(pdf_filename);
        if ~exist(pdf_dir, 'dir')
            mkdir(pdf_dir);
        end
        
        % Download PDF
        pdfURL = "https://arxiv.org/pdf/" + paper_id + ".pdf";
        fprintf('Downloading from: %s\n', pdfURL);
        
        options_web = weboptions('Timeout', 60, 'ContentType', 'binary');
        pdfBytes = webread(pdfURL, options_web);

        fid = fopen(pdf_filename, 'w');
        fwrite(fid, pdfBytes);
        fclose(fid);
        
        % Verify file was created
        if ~isfile(pdf_filename)
            error('Failed to save PDF to: %s', pdf_filename);
        end

        result.success = true;
        result.message = sprintf('PDF downloaded to fixed location: %s', pdf_filename);
        result.metadata = struct('pdf_path', pdf_filename);
        
    catch ME
        result.success = false;
        result.message = sprintf('PDF download failed: %s', ME.message);
        result.metadata = struct();
        rethrow(ME);
    end
end

function [result, agent_state] = action_extract_text(~, agent_state)
    result = struct();
    try
        % Use fixed PDF path
        pdf_path = agent_state.pdf_filename;
        
        % Check if file exists
        if ~isfile(pdf_path)
            error('PDF file not found at: %s. Please run download_pdf first.', pdf_path);
        end
        
        % Extract text
        fprintf('Extracting text from: %s\n', pdf_path);
        pdfText = extractFileText(pdf_path);
        
        % Check if extraction worked
        if isempty(pdfText) || strlength(pdfText) < 100
            fprintf('Warning: Only extracted %d characters. This may indicate PDF is scanned or protected.\n', strlength(pdfText));
            fprintf('Will proceed with available text.\n');
        end
        
        if isempty(pdfText)
            error('No text extracted from PDF');
        end
        
        agent_state.pdf_text = pdfText;

        result.success = true;
        result.message = sprintf('Extracted %d characters from PDF: %s', length(pdfText), pdf_path);
        result.metadata = struct('text', pdfText);
        
    catch ME
        result.success = false;
        result.message = sprintf('Text extraction failed: %s', ME.message);
        result.metadata = struct();
        % Don't rethrow - let agent try HTML method
    end
end

function [result, agent_state] = action_extract_equation(~, agent_state)
    result = struct();
    try
        % Check if we have PDF text
        if isempty(agent_state.pdf_text)
            error('No PDF text available. Please run extract_text first.');
        end
        
        % Create extractor - GPT-5 version (no temperature)
        extractor = openAIChat( ...
            'You are an expert in extracting mathematical equations from scientific text. Provide only the LaTeX equation, no explanations.', ...
            'ModelName', 'gpt-5');  % Removed Temperature

        % Limit text length to avoid token limits
        max_chars = 10000;
        if length(agent_state.pdf_text) > max_chars
            text_sample = agent_state.pdf_text(1:max_chars);
            fprintf('Text truncated to %d characters\n', max_chars);
        else
            text_sample = agent_state.pdf_text;
        end
        
        % Ensure text_sample is not empty
        if isempty(text_sample)
            error('Text sample is empty after truncation');
        end
        
        % Build prompt
        prompt = ['From the following text, extract Kuhn''s equation for the HOMO-LUMO gap of helicenes. ' ...
            'This should be an equation of the form: ΔE = (h²/(8mL²))(N+1) + V₀(1 - 1/N) or similar. ' ...
            'Look for equations containing:\n' ...
            '- Terms with 1/L² or 1/L^2 (confinement energy)\n' ...
            '- Terms with (N+1) dependence\n' ...
            '- Terms with V₀(1 - 1/N) or similar\n' ...
            'Output ONLY the LaTeX equation, no extra text.\n\n' ...
            char(text_sample)];

        fprintf('Sending request to OpenAI...\n');
        latex_eq = generate(extractor, prompt);
        latex_eq = strtrim(string(latex_eq));

        % Simple validation
        latex_lower = lower(latex_eq);
        confidence = 0;
        if contains(latex_lower, 'l^2') || contains(latex_lower, 'l^{-2}'), confidence = confidence + 3; end
        if contains(latex_lower, 'v0') || contains(latex_lower, 'v_0'), confidence = confidence + 2; end
        if contains(latex_lower, 'n+1') || contains(latex_lower, '(n+1)'), confidence = confidence + 2; end
        if contains(latex_lower, '1/n') || contains(latex_lower, '\\frac{1}{n}'), confidence = confidence + 2; end

        agent_state.equation.latex = latex_eq;
        agent_state.equation.confidence = confidence;
        agent_state.extraction_attempts.pdf = true;

        result.success = true;
        result.message = sprintf('Extracted LaTeX from PDF (confidence %d/11): %s', confidence, latex_eq);
        result.metadata = struct('latex', latex_eq, 'confidence', confidence);
        
    catch ME
        result.success = false;
        result.message = sprintf('PDF equation extraction failed: %s', ME.message);
        result.metadata = struct();
        % Don't rethrow - let agent try HTML method
    end
end

function [result, agent_state] = action_extract_equation_html(input, agent_state)
    result = struct();
    try
        if isstruct(input) && isfield(input, 'paper_id')
            paper_id = input.paper_id;
        else
            paper_id = agent_state.paper_id;
        end

        paper_id = regexprep(paper_id, '^arXiv:', '');
        paper_id_base = regexprep(paper_id, 'v\d+$', '');
        
        htmlUrls = {
            sprintf('https://arxiv.org/html/%s', paper_id_base);
            sprintf('https://arxiv.org/html/%s', paper_id);
            sprintf('https://ar5iv.org/html/%s', paper_id_base);
        };
        
        htmlText = '';
        used_url = '';
        for i = 1:length(htmlUrls)
            try
                options = weboptions('Timeout', 30, 'ContentType', 'text');
                htmlText = webread(htmlUrls{i}, options);
                used_url = htmlUrls{i};
                fprintf('Successfully fetched HTML from: %s\n', used_url);
                break;
            catch
                continue;
            end
        end
        
        if isempty(htmlText)
            error('Could not fetch HTML from any URL');
        end

        %% STRATEGY 1: Pattern matching for Kuhn equation
        % Look for LaTeX equations in the HTML
        equation_patterns = {
            '\\\[.*?\\\]',  % \[ ... \] style
            '\$\$.*?\$\$',     % $$ ... $$ style
            '\\begin{equation}.*?\\end{equation}'  % \begin{equation} ... \end{equation}
        };
        
        all_equations = {};
        for i = 1:length(equation_patterns)
            matches = regexp(htmlText, equation_patterns{i}, 'match');
            all_equations = [all_equations, matches];
        end
        
        % Look for equations containing Kuhn model terms
        kuhn_equation = '';
        for i = 1:length(all_equations)
            eq = all_equations{i};
            eq_lower = lower(eq);
            if (contains(eq_lower, 'l^2') || contains(eq_lower, 'l^{-2}')) && ...
               (contains(eq_lower, 'v') || contains(eq_lower, 'v0')) && ...
               (contains(eq_lower, 'n+1') || contains(eq_lower, 'n + 1'))
                kuhn_equation = eq;
                break;
            end
        end
        
        if ~isempty(kuhn_equation)
            latex_eq = kuhn_equation;
            confidence = 10;
            fprintf('Found Kuhn equation via pattern matching\n');
        else
            %% STRATEGY 2: Use LLM with limited context to avoid token limits
            % Convert HTML to plain text and limit size
            plainText = regexprep(htmlText, '<[^>]*>', ' ');
            plainText = regexprep(plainText, '\s+', ' ');
            
            % Limit to 3000 characters to avoid token limits
            if length(plainText) > 3000
                plainText = plainText(1:3000);
                fprintf('HTML truncated to 3000 characters\n');
            end
            
            if isempty(plainText)
                error('Plain text is empty after processing');
            end
            
            % Use GPT-5 (no temperature)
            extractor = openAIChat( ...
                'You are an expert in identifying Kuhn''s equation for helicenes.', ...
                'ModelName', 'gpt-5');  % Removed Temperature

            prompt = sprintf([ ...
                'Find Kuhn''s equation for the HOMO-LUMO gap of helicenes in this text.\n\n' ...
                'The CORRECT Kuhn equation has this form:\n' ...
                'ΔE = (h²/(8mL²))(N+1) + V₀(1 - 1/N)\n\n' ...
                'Key identifiers:\n' ...
                '- Contains 1/L² or 1/L^2\n' ...
                '- Contains (N+1)\n' ...
                '- Contains V₀(1 - 1/N)\n\n' ...
                'Text: %s\n\n' ...
                'Output ONLY the LaTeX equation, nothing else.'], plainText);

            latex_eq = generate(extractor, prompt);
            latex_eq = strtrim(string(latex_eq));
            confidence = 7;  % Medium confidence for LLM extraction
        end

        if isempty(latex_eq)
            error('No equation extracted from HTML');
        end

        agent_state.equation.latex = latex_eq;
        agent_state.equation.confidence = confidence;
        agent_state.extraction_attempts.html = true;
        
        fprintf('\n=== Extracted Equation ===\n');
        fprintf('%s\n', latex_eq);
        fprintf('==========================\n');

        result.success = true;
        result.message = sprintf('Extracted LaTeX from HTML (confidence %d/11): %s', confidence, latex_eq);
        result.metadata = struct('latex', latex_eq, 'confidence', confidence, 'source_url', used_url);
        
    catch ME
        result.success = false;
        result.message = sprintf('HTML extraction failed: %s', ME.message);
        result.metadata = struct();
        % Don't rethrow - let agent try other methods
    end
end

%% FIXED CONVERSION FUNCTION - NO EXAMPLE LEAKAGE
function [result, agent_state] = action_convert_to_matlab(~, agent_state)
    result = struct();
    
    % Try to get equation if not already present
    if isempty(agent_state.equation.latex)
        % Try HTML extraction first
        if ~agent_state.extraction_attempts.html && ~isempty(agent_state.paper_id)
            fprintf('*** Attempting HTML extraction... ***\n');
            try
                [html_result, agent_state] = action_extract_equation_html(struct('paper_id', agent_state.paper_id), agent_state);
                if html_result.success
                    agent_state.equation.latex = html_result.metadata.latex;
                    agent_state.equation.confidence = html_result.metadata.confidence;
                    fprintf('✓ HTML extraction successful (confidence %d/11)\n', agent_state.equation.confidence);
                end
            catch
                fprintf('✗ HTML extraction failed\n');
            end
        end
        
        % Try PDF extraction if HTML failed
        if isempty(agent_state.equation.latex) && ~agent_state.extraction_attempts.pdf && ~isempty(agent_state.pdf_text)
            fprintf('*** Attempting PDF extraction... ***\n');
            try
                [pdf_result, agent_state] = action_extract_equation(struct(), agent_state);
                if pdf_result.success
                    agent_state.equation.latex = pdf_result.metadata.latex;
                    agent_state.equation.confidence = pdf_result.metadata.confidence;
                    fprintf('✓ PDF extraction successful (confidence %d/11)\n', agent_state.equation.confidence);
                end
            catch
                fprintf('✗ PDF extraction failed\n');
            end
        end
    end
    
    % If no equation was extracted, error out
    if isempty(agent_state.equation.latex)
        error('No equation could be extracted from either HTML or PDF sources');
    end
    
    % Convert the extracted LaTeX to MATLAB function
    try
        % Use GPT-5 for better mathematical understanding (no temperature)
        converter = openAIChat( ...
            'You are an expert at converting physics equations to MATLAB code. Follow the instructions carefully and output only valid MATLAB code.', ...
            'ModelName', 'gpt-5');  % Removed Temperature

        latexEq = char(agent_state.equation.latex);
        
        % Extract the data range to provide context
        if agent_state.data.loaded
            n_min = min(agent_state.data.n);
            n_max = max(agent_state.data.n);
        else
            n_min = 1;
            n_max = 10;
        end
        
        % Build prompt with scaffolding but NO example equation
        prompt = sprintf([ ...
            'Convert this LaTeX equation for Kuhn''s model to a MATLAB anonymous function.\n\n' ...
            'EQUATION TO CONVERT:\n%s\n\n' ...
            'PHYSICAL CONTEXT:\n' ...
            '- This is Kuhn''s equation for the HOMO-LUMO gap of helicenes\n' ...
            '- N = number of π electrons = 4n+2, where n is helicene number (range: %d to %d)\n' ...
            '- The helical length L in bohr is calculated as: L = ((3.*n+3).*1.4*1.88973)\n' ...
            '- In atomic units: hbar = 1, h = 2π, m = 1\n' ...
            '- Therefore, h²/(8m) = (2π)²/8 = 4π²/8 = π²/2\n\n' ...
            'YOUR TASK:\n' ...
            'Create a MATLAB anonymous function named "gap_model" with signature: gap_model = @(v0, N)\n\n' ...
            'STEP-BY-STEP INSTRUCTIONS:\n' ...
            '1. Parse the LaTeX equation to identify its structure\n' ...
            '2. Replace n with (N-2)/4 throughout\n' ...
            '3. Replace h²/(8m) with pi^2/2 (exact symbolic form)\n' ...
            '4. Calculate L using the formula above with n replaced\n' ...
            '5. Implement both terms from the equation and ADD them\n' ...
            '6. Use element-wise operations: .*, ./, .^\n' ...
            '7. Ensure proper parentheses for correct order of operations\n\n' ...
            'CRITICAL REQUIREMENTS:\n' ...
            '- Output EXACTLY ONE LINE of MATLAB code\n' ...
            '- The function must accept v0 and N as inputs\n' ...
            '- v0 is the fitting parameter (in Hartree)\n' ...
            '- N can be a scalar or vector - use element-wise operations\n' ...
            '- No markdown, no backticks, no explanations - just the code\n\n' ...
            'Now convert the given equation following these rules exactly.'], ...
            latexEq, n_min, n_max);

        fprintf('Converting equation to MATLAB with enhanced prompt and proper atomic units...\n');
        fprintf('Equation to convert: %s\n', latexEq);

        response = generate(converter, prompt);
        response = strtrim(string(response));
        fprintf('Raw response: %s\n', response);

        % Clean response
        func_str = clean_matlab_response(response);

        if isempty(func_str) || ~contains(func_str, 'gap_model') || ~contains(func_str, '@(')
            error('LLM failed to output valid MATLAB function. Response was: %s', response);
        end

        % Ensure semicolon
        if ~endsWith(strtrim(func_str), ';')
            func_str = [strtrim(func_str), ';'];
        end

        % Test the function with comprehensive validation
        try
            eval(func_str);
            
            % Test with multiple N values
            test_N = [6, 10, 14, 18, 22, 26];
            test_v0 = 0.1;
            test_result = gap_model(test_v0, test_N);
            
            % Validate results
            if isempty(test_result) || any(isnan(test_result)) || any(~isfinite(test_result))
                error('Function returned invalid values (NaN or Inf)');
            end
            if any(test_result <= 0)
                error('Function produced non-positive gaps - physical values should be positive');
            end
            
            % Check monotonicity (gap should decrease as N increases)
            if ~all(diff(test_result) < 0)
                fprintf('Warning: Function does not monotonically decrease with N\n');
            end
            
            fprintf('✓ Comprehensive function test passed\n');
            test_passed = true;
            
        catch test_err
            error('Function test failed: %s\nFunction was: %s', test_err.message, func_str);
        end

        evalin('base', func_str);
        assignin('base', 'agent_func_str', func_str);

        agent_state.equation.ready = true;
        agent_state.equation.source = 'LLM conversion of extracted equation';
        agent_state.equation.func_str = func_str;
        agent_state.equation.test_passed = true;

        result.success = true;
        result.message = sprintf('LLM generated function from extracted equation: %s', func_str);
        result.metadata = struct('func_str', func_str, 'test_passed', true, 'source', 'LLM conversion');

    catch ME
        result.success = false;
        result.message = sprintf('Conversion failed: %s', ME.message);
        result.metadata = struct();
        
        fprintf('\n*** CRITICAL: LLM failed to generate valid MATLAB function. ***\n');
        fprintf('Error: %s\n', ME.message);
        fprintf('Equation was: %s\n', agent_state.equation.latex);
        
        % Save debug info
        debug_file = fullfile(agent_state.data_dir, 'conversion_debug.txt');
        fid = fopen(debug_file, 'w');
        fprintf(fid, 'Equation: %s\n', agent_state.equation.latex);
        fprintf(fid, 'Error: %s\n', ME.message);
        fprintf(fid, 'Prompt used:\n%s\n', prompt);
        fclose(fid);
        fprintf('Debug info saved to: %s\n', debug_file);
        
        rethrow(ME);
    end
end

function clean = clean_matlab_response(raw)
    raw = char(raw);
    % Remove markdown code blocks
    raw = strrep(raw, '```matlab', '');
    raw = strrep(raw, '```', '');
    raw = strrep(raw, '`', '');
    
    % Remove everything before first 'gap_model'
    idx = strfind(raw, 'gap_model');
    if ~isempty(idx)
        raw = raw(idx(1):end);
    end
    lines = splitlines(raw);
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if contains(line, 'gap_model') && contains(line, '@(')
            clean = line;
            return;
        end
    end
    % If no line with 'gap_model', try to find any line that looks like a function
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

        if ~evalin('base', 'exist(''gap_model'', ''var'')')
            evalin('base', agent_state.equation.func_str);
        end
        gap_model = evalin('base', 'gap_model');

        if isstruct(input) && isfield(input, 'initial_v0')
            v0_initial = input.initial_v0;
        else
            v0_initial = 0.1;
        end

        fit_func = @(v0, N) gap_model(v0, N);
        options = optimoptions('lsqcurvefit', 'Display', 'off');
        [v0_opt, resnorm, ~, exitflag] = lsqcurvefit(fit_func, v0_initial, N, gap_hartree, [], [], options);

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

        if ~evalin('base', 'exist(''gap_model'', ''var'')')
            evalin('base', agent_state.equation.func_str);
        end
        gap_model = evalin('base', 'gap_model');

        gap_pred_hartree = gap_model(v0, N);
        gap_pred_ev = gap_pred_hartree * hat2ev;
        gap_obs_ev = agent_state.data.gap_ev;

        ss_res = sum((gap_obs_ev - gap_pred_ev).^2);
        ss_tot = sum((gap_obs_ev - mean(gap_obs_ev)).^2);
        rsquared = 1 - ss_res/ss_tot;
        rmse_ev = sqrt(mean((gap_obs_ev - gap_pred_ev).^2));

        agent_state.validation.rsquared = rsquared;
        agent_state.validation.rmse_ev = rmse_ev;
        agent_state.validation.residuals = gap_obs_ev - gap_pred_ev;

        result.success = true;
        result.message = sprintf('Validation: R² = %.4f, RMSE = %.4f eV', rsquared, rmse_ev);
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
        n = agent_state.data.n;
        gap_ev = agent_state.data.gap_ev;
        v0 = agent_state.model.v0;
        v0_ev = v0 * hat2ev;

        N_fine = linspace(min(4*n+2), max(4*n+2), 200)';
        n_fine = (N_fine - 2) / 4;
        
        if ~evalin('base', 'exist(''gap_model'', ''var'')')
            evalin('base', agent_state.equation.func_str);
        end
        gap_model = evalin('base', 'gap_model');
        gap_fitted_hartree = gap_model(v0, N_fine);
        gap_fitted_ev = gap_fitted_hartree * hat2ev;

        figure('Position', [100 100 800 600]);
        plot(n, gap_ev, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', 'Experimental Data');
        hold on;
        plot(n_fine, gap_fitted_ev, 'b-', 'LineWidth', 2, 'DisplayName', sprintf('Fitted Kuhn Model (v₀ = %.4f eV)', v0_ev));
        xlabel('Helicene number n');
        ylabel('HOMO-LUMO gap (eV)');
        title(sprintf('Kuhn Model Fit (Equation confidence: %d/11)', agent_state.equation.confidence));
        legend('Location', 'best');
        grid on;

        text(0.05, 0.95, sprintf('R² = %.4f\nSource: %s\nConfidence: %d/11', ...
            agent_state.validation.rsquared, agent_state.equation.source, agent_state.equation.confidence), ...
            'Units', 'normalized', 'FontSize', 11, 'BackgroundColor', 'white', ...
            'EdgeColor', 'black', 'VerticalAlignment', 'top');

        drawnow;

        result.success = true;
        result.message = 'Plot created successfully.';
        result.metadata = struct();

    catch ME
        result.success = false;
        result.message = sprintf('Plotting failed: %s', ME.message);
        result.metadata = struct();
    end
end

function [result, agent_state] = action_finalize(~, agent_state)
    result = struct();
    if agent_state.model.fitted
        result.success = true;
        result.message = sprintf([ ...
            'Task complete! Final model (from %s): v₀ = %.6f hartree (%.4f eV)\n' ...
            'R² = %.4f, RMSE = %.4f eV\n' ...
            'Equation confidence: %d/11\n' ...
            'Equation: %s'], ...
            agent_state.equation.source, ...
            agent_state.model.v0, agent_state.model.v0_ev, ...
            agent_state.validation.rsquared, agent_state.validation.rmse_ev, ...
            agent_state.equation.confidence, ...
            agent_state.equation.latex);
        result.metadata = struct('v0', agent_state.model.v0, 'v0_ev', agent_state.model.v0_ev);
    else
        result.success = false;
        result.message = 'Cannot finalize: model not fitted yet';
        result.metadata = struct();
    end
end