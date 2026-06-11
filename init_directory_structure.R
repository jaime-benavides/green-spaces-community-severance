# File: 0_01_init_directory_structure.R
# Author(s): Jaime Benavides, Lawrence Chillrud
# Date since last edit: 5/20/21

####*******************####
#### Table of Contents ####
####*******************####
####* Notes / Description
####* 1. Initialize Directory Structure

####*********************####
#### Notes / Description ####
####*********************####
####* This script initializes the directory 
####* structure for the open street project.

####***********************************####
#### 1: Initialize Directory Structure #### 
####***********************************####

# 1a Declare directory objects:
project.folder <- paste0(print(here::here()),'/')
code.folder <- paste0(project.folder, "code/")
packages.folder <- paste0(code.folder, "packages/")
functions.folder <- paste0(code.folder, "functions/")
data.folder <- paste0(project.folder, "data/")
raw.data.folder <- paste0(data.folder, "raw/")
generated.data.folder <- paste0(data.folder, "generated/")
output.folder <- paste0(project.folder, "output/")

# 1b Store all folder names from 1a (above) in a vector:
folder.names <- grep(".folder",names(.GlobalEnv),value=TRUE)

# 1c Create all folders that do not already exist from 1b (above):
purrr::map_lgl(.x = folder.names, .f = ~ ifelse(!dir.exists(get(.)), dir.create(get(.), recursive=TRUE), FALSE))

