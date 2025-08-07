# Ownership of Power Plants Stranded by Climate Mitigation

This repository contains scripts and a subset of data used in the manuscript:  
**"Ownership of power plants stranded by climate mitigation."**

## System Requirements

### Tested on
- **MATLAB Versions:** R2023a, R2022a, R2021a/b  
- **Operating System:** macOS Ventura 13.4.1  

### Software
- MATLAB is compatible with major platforms: Linux, macOS, and Windows.
- Required Toolboxes:
  - Statistics and Machine Learning (v12.5)
  - Optimization (v9.5)
  - Global Optimization (v4.8.1)

### Hardware
- **Processor:** Any Intel or AMD x86-64 processor with a minimum of two cores  
- **RAM:** Minimum: 8 GB; Recommended: 16 GB  
- **Storage:** MATLAB requires 4–6 GB for basic installation; toolboxes will require additional hard drive space  

## Installation Guide

### Instructions
1. Install MATLAB on your system.  
2. Download and install the required MATLAB Toolboxes with the specified versions.  
3. Clone this repository or download the necessary files and data.  

### Typical Install Time
- MATLAB and Toolboxes: Varies based on internet and computer speed, typically around 30–60 minutes.

## Model Demo

### Instructions
1. Run preprocessing scripts in the order specified at the end of their names.  
2. Execute figure-related scripts in any desired order after completing preprocessing.

### Expected Output
- Figure files will perform calculations and produce at least panel (a) from the figure they are named after.

### Expected Run Time for Demo
- **Preprocessing 1:** Typically around 5 minutes (depends on computer and power plant fuel type)  
- **Preprocessing 2:** Can take up to 15 minutes  
- **Generating Figures:** Most figure files take 5 minutes or less.  
  - `Figure_1.m` takes slightly longer than 5 minutes  
  - `Figure_4_top_row.m` takes 10–20 minutes to complete  

## Instructions for Use

### Running the Power Plant Transition Risks Model
1. Ensure the data directory is correct in the source code once data has been retrieved. Otherwise, modify the file paths accordingly.  
2. A subset of the data associated with this project has been uploaded to Zenodo:  
   DOI: [10.5281/zenodo.14861495](https://doi.org/10.5281/zenodo.14861495)  
3. Follow the steps mentioned in the demo section to execute the code with your data.

## Reproduction

The source code should reproduce the quantitative results presented in the manuscript if the scripts are run in the correct order. The source data can be found within the links provided in the manuscript.  
Please reach out to the corresponding authors if you are having trouble with any sections of the code or if any inconsistencies are found.

## License

This project is released under the MIT License.

For further inquiries or reproduction assistance, contact:  
Dr. Robert Fofrich Navarro  
robertfofrich@ucla.edu
