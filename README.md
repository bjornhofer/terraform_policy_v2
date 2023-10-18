# Terraform Policy Module
## Azure Policy as Code with JSON definitions - applied to management groups

# Description
## Folder structure
Every folder stored in the policies reflects your management group structure.
### Example
Root-Management Group is called mgroot and holds a child-management group called policytest
mgroot
|- policytest

The folder structure must be exact the same:
mgroot
|- policytest
The folder storage path would be mgroot/policytest
An example file (eg. policies.json) would be stored at: mgroot/policytest/policies.json

## Policy configuration

The policy configuration is done at least in policy.json.

In case you want to add a custom policy this can be done in a seperate .json file (eg. mycustompolicy.json)


### policies.json
This main configuration file will provide following informations to about the policy - and what to do with it at the subsequent management group layer.

#### Workflow
Terraform looks for a file called policies.json - every policy mentioned there will be (at least) definied at that management group layer.
Possible actions/configurations:
##### Define/Apply (existing) policy
A policy gets defined and assigned at the same management group layer.
##### Define (existing) policy
A policy get only defined at the management group layer.

### custom policy (e.g.: mypolicydefinitionxyz.json)
Filename can be choosen by creator (please refer to operating sytstem constraints).
This file contains the definition of the custom policy.

Following parameters can be used for policy definition
- name - if not provided by policies.json Terraform will take value provided in the definition file
- display_name (stored in properties) - if not provided by policies.json Terraform will take value provided in the definition file
- description (stored in properties) - if not provided by policies.json Terraform will take value provided in the definition file
- policy_type (stored in properties) - must be provided, otherwise "Custom" will be used
- mode (stored in properties) - must be provided, otherwise "All" will be used
- parameters - must be provided
- policy_rule - must be provided

Following paramenters can be used for policy assignment
- assignment_name - if not provided by policies.json Terraform will take the name provided in the definition file
- display_name (stored in properties) - if not provided by policies.json Terraform will look at assignment_name, if not provided Terraform will take value provided in the definition file
- parameters - if not provided by policies.json Terraform will take the properties of the file definition
