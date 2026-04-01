# Autonomous Large Language Model Agents for Materials Science
This repository contains the code accompanying the paper "From Data to Theory: Autonomous Large Language Model Agents for Materials Science".


[![MATLAB](https://img.shields.io/badge/MATLAB-R2025b-blue.svg)](https://www.mathworks.com/)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT--5-green.svg)](https://openai.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Introduction

We present an autonomous large language model agent for end-to-end, data-driven materials theory development. The agent can choose an equation form, generate and run its own code, and test how well the theory matches the data all without human intervention. The framework combines step-by-step reasoning with expert-supplied tools, allowing the agent to adjust its approach as needed while maintaining a clear record of its decisions.

---

## Authors

**Samuel Onimpa Alfred** and **Veera Sundararaghavan**

Department of Aerospace Engineering  
University of Michigan, Ann Arbor

---

## Repository Structure

```
LLM-based_Agents/
├── Datasets/
│   ├── HP_Dataset.csv          # Hall-Petch experimental data
│   ├── FCG_Data_0.1.csv        # Paris law fatigue data
│   └── Helicene_DFT.csv        # Helicene DFT calculations
├── Matlab_Scripts/
│   ├── GPT-4/
│   │   ├── Hall_Petch_GPT4.m           # Hall-Petch grain size strengthening
│   │   ├── Paris_Law_GPT4.m            # Paris law fatigue crack growth (auto region selection)
│   │   ├── Kuhn_LLM_GPT4.m             # Kuhn equation extraction from LLM's knowledge
│   │   ├── Kuhn_Lit_GPT4.m             # Literature-based Kuhn equation extraction
│   │   └── Modified_Kuhn_GPT4.m        # Modified Kuhn equation with strain effects
│   └── GPT-5/
│       ├── Hall_Petch_GPT5.m           # Hall-Petch grain size strengthening
│       ├── Paris_Law_GPT5.m            # Paris law fatigue crack growth (auto region selection)
│       ├── Kuhn_LLM_GPT5.m             # Kuhn equation extraction from LLM's knowledge
│       ├── Kuhn_Lit_GPT5.m             # Literature-based Kuhn equation extraction
│       └── Modified_Kuhn_GPT5.m        # Modified Kuhn equation with strain effects
└── README.md                   # This file
```

---

## Installation

### Install Required Toolboxes

Before running the agents, install the **Large Language Models (LLMs) with MATLAB** add-on:

**Using Add-On Explorer (Recommended)**

1. In MATLAB, go to the **Home** tab, and in the **Environment** section, click the **Add-Ons** icon.
2. In the Add-On Explorer, search for **"Large Language Models (LLMs) with MATLAB"**.
3. Select **Install**.

**Required Toolboxes:**
- **Optimization Toolbox** for nonlinear least squares fitting (`lsqcurvefit`)
- **Statistics and Machine Learning Toolbox** for confidence intervals and statistical validation
- **Deep Learning Toolbox** for LLM integration

---

## Get Started with OpenAI API

To use these agents, you need an OpenAI API key with available credits.

### Step 1: Set Up Your API Key

Create a `startup.m` file in your MATLAB path with:

```matlab
disp(">>> USER STARTUP EXECUTED <<<")
setenv("OPENAI_API_KEY", "your-openai-key-here")
```

Replace `"your-openai-key-here"` with your actual API key from [OpenAI Platform](https://platform.openai.com/api-keys).

### Step 2: Verify Installation

```matlab
% Check if API key is set
getenv("OPENAI_API_KEY")

% Test connection
test_model = openAIChat("Test connection", ModelName="gpt-5");
response = generate(test_model, "Say 'API working'");
disp(response)
```

---

## Quick Start

### Run an Agent

Navigate to the appropriate folder (GPT-4 or GPT-5) and run the desired script:

```matlab
% Hall-Petch agent
run('Hall_Petch_GPT4.m')       % GPT-4 version
run('Hall_Petch_GPT5.m')       % GPT-5 version

% Paris law agent
run('Paris_Law_GPT4.m')        % GPT-4 version
run('Paris_Law_GPT5.m')        % GPT-5 version

```

---

## How It Works

Each LLM-based agent operates through a ReAct (Reasoning + Acting) loop:

1. **THOUGHT** The LLM reasons about the current state and determines the next action
2. **ACTION** The agent calls MATLAB tools from the tool registry (load data, generate equation, fit model, etc.)
3. **OBSERVATION** The system updates state with results
4. **ITERATE** The process repeats until the objective is met


---

## Features

- 🤖 **LLM-generated equations** from its own training knowledge 
- 📚 **Literature-based equation extraction** for baseline comparison
- 🧠 **ReAct architecture** for autonomous decision-making
- 📊 **Nonlinear least squares fitting** with validation metrics (R², RMSE)
- 📈 **Publication-quality visualizations** including log-log, residuals, and linearized forms
- 📝 **Complete reasoning trace** for transparency and reproducibility
- 🔄 **GPT-4 and GPT-5 versions** for comparative analysis

---

## License

The license is available in the [LICENSE](LICENSE) file in this GitHub repository.

MIT License Copyright (c) 2026 Samuel Onimpa Alfred and Veera Sundararaghavan, University of Michigan, Ann Arbor

---

## Citation

If you use this code in your research, please cite:

```bibtex
@article{Alfred2026FromData,
  title={From Data to Theory: Autonomous Large Language Model Agents for Materials Science},
  author={Alfred, Samuel Onimpa and Sundararaghavan, Veera},
  institution={University of Michigan, Ann Arbor},
  year={2026},
  note={Available at: https://github.com/yourusername/LLM-based_Agents}
}
```

---

## Community Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/LLM-based_Agents/issues)
- **MATLAB Central:** [File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/)

---

*Copyright 2026 Samuel Onimpa Alfred and Veera Sundararaghavan, University of Michigan, Ann Arbor*
