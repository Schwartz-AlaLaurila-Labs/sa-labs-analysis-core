[![Build Status](https://build.nbe.aalto.fi/buildStatus/icon?job=validateSALabsAnalysisCore)](https://build.nbe.aalto.fi/job/validateSALabsAnalysisCore/)

# Electrophysiology Data Analysis (In development)

### Installation

1. Download and install [ToolboxToolbox](https://github.com/ToolboxHub/ToolboxToolbox)
2. Restart Matlab
3. `git clone https://github.com/Schwartz-AlaLaurila-Labs/sa-labs-analysis-core.git` into `<userpath>\projects\sa-labs-analysis-core` folder 
4. open the matlab command window and run `tbUseProject('sa-labs-analysis-core')`

### Folder organization

1. It follows maven style source code organization
2. All the dependency will be present in toolbox folder

### Usage 
TODO
## Requirements

- Matlab 2016a+
- [ToolboxHub](https://github.com/ToolboxHub/ToolboxToolbox) for dependency management

### Matlab dependencies
	
	 sa-labs-analysis-core
	 	|
		|____ app-toolboxes
				|____ mdepin (Matlab dependency injection framework) 
				|____ appbox (Model view presenter based user interface)
				|____ Java Table Wrapper
				|____ Property Grid	 
				|____ Matlab tree data structure  
				|____ Jsonlab 
				|____ Logging for Matlab		
				|____ Matlab Query (LINQ style query processor)		 
