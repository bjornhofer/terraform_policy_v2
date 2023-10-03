// Verbosity for all possible resources blocks
locals {
  verbose = false
}

locals {
  folderstructure_policies = [for folder in fileset(path.module, "**") : folder
  if(length(regexall("(\\.json)", folder)) > 0)]
  folders_policies = distinct(flatten([for folder in local.folderstructure_policies : join("/", slice(split("/", folder), 0, length(split("/", folder)) - 1))]))
}

locals {
  // Management Group Settings
  management_group_policy_file_name = "policies.json"
  mgmt_grp_layer0_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 1] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer1_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 2] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer2_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 3] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer3_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 4] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer4_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 5] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer5_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 6] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  // Test to iterate only over the first two layers
  //unfiltered_mgmt_grp_policies = merge(local.mgmt_grp_layer0_policies, local.mgmt_grp_layer1_policies)
  unfiltered_mgmt_grp_policies = merge(local.mgmt_grp_layer0_policies, local.mgmt_grp_layer1_policies, local.mgmt_grp_layer2_policies, local.mgmt_grp_layer3_policies, local.mgmt_grp_layer4_policies, local.mgmt_grp_layer5_policies)
  
  // Filter the policies (remove empty entries in map)
  /*
  // Git based policy definition
  git_mgmt_grp_policies_temp = {
    for mgmt_grp, policydata in local.unfiltered_mgmt_grp_policies : mgmt_grp => {
      for policy_name, policy_information in policydata :
      policy_name => policy_information
    if try(policy_information.project_name, false) != false }
  if length(policydata) > 0 }
  */

  // File based policy definition
  filebased_mgmt_grp_policies_temp = {
    for mgmt_grp, policydata in local.unfiltered_mgmt_grp_policies : mgmt_grp => {
      for policy_name, policy_information in policydata :
      policy_name => policy_information
      if try(policy_information.project_name, false) == false &&
    try(policy_information.policy_definition_id, false) == false }
  if length(policydata) > 0 }

  // BuiltIn policy definition
  builtin_mgmt_grp_policies_temp = {
    for mgmt_grp, policydata in local.unfiltered_mgmt_grp_policies : mgmt_grp => {
      for policy_name, policy_information in policydata :
      policy_name => policy_information
      if try(policy_information.project_name, false) == false &&
    try(policy_information.policy_definition_id, false) != false }
  if length(policydata) > 0 }

  // Flatten the map to better work with data
  /*
  // Git based policy definition
  git_mgmt_grp_policies = merge([
    for mgmt_grp, policydata in local.git_mgmt_grp_policies_temp :
    { for policy_information in policydata :
      "${mgmt_grp}/${policy_information.policy_name}" => policy_information
    } if length(policydata) > 0
  ]...)
  */

  // File based policy definition
  filebased_mgmt_grp_policies = merge([
    for mgmt_grp, policydata in local.filebased_mgmt_grp_policies_temp :
    { for policy_information in policydata :
      "${mgmt_grp}/${policy_information.policy_name}" => policy_information
    } if length(policydata) > 0
  ]...)

  // BuiltIn policy definition
  builtin_mgmt_grp_policies = merge([
    for mgmt_grp, policydata in local.builtin_mgmt_grp_policies_temp :
    { for policy_information in policydata :
      "${mgmt_grp}/${policy_information.policy_name}" => policy_information
    } if length(policydata) > 0
  ]...)

}

/*
output "git_mgmt_grp_policies" {
  value = local.verbose ? local.git_mgmt_grp_policies : null
}
*/

output "filebased_mgmt_grp_policies" {
  value = local.verbose ? local.filebased_mgmt_grp_policies : null
}
output "builtin_mgmt_grp_policies" {
  value = local.verbose ? local.builtin_mgmt_grp_policies : null
}

// Gather project data from Azure DevOps
// Deactivated due to not limiting the module to a specific provider
/*
data "azuredevops_project" "project" {
  for_each = local.mgmt_grp_policies
  name     = each.value.project_name
}

output "project" {
  value = local.verbose ? data.azuredevops_project.project : null
}

// Gather repository data from Azure DevOps
data "azuredevops_git_repository" "repo" {
  for_each   = local.mgmt_grp_policies
  project_id = data.azuredevops_project.project[each.key].id
  name       = each.value.repo_name
}

output "repo" {
  value = local.verbose ? data.azuredevops_git_repository.repo : null
}

// Triggers below commands all the time (Due to missing feature of Azure DevOps data provider, to detect changed size of repos)
resource "random_string" "trigger" {
  keepers = {
    timestamp = timestamp()
  }
  length  = 5
  special = false
}

// Detect the operating system
locals {
  is_linux = length(regexall("/home/", lower(abspath(path.root)))) > 0
}

output "is_linux" {
  value = local.is_linux
}

// Delete the file in case the it exists (to force refreshs)
resource "null_resource" "remove_cloned_directory" {
  for_each = local.mgmt_grp_policies

  triggers = {
    string = random_string.trigger.result
  }

  provisioner "local-exec" {
    command = (
      fileexists("${path.module}/policies/${each.key}/${each.value.policy_filename}") ?
      local.is_linux ?
      "rm -rf ${each.value.policy_filename}" :
      "rmdir /s /q ${each.value.policy_filename}":
      local.is_linux ? 
      "echo 'Nothing to remove: ${each.value.policy_filename}'" : 
      "echo Nothing to remove: ${each.value.policy_filename}"
      

    )
  }
  depends_on = [random_string.trigger]
}

// Clone the repo
resource "null_resource" "git_clone" {
  for_each = local.mgmt_grp_policies

  triggers = {
    string = random_string.trigger.result
  }

  provisioner "local-exec" {
    command = (
      "git clone ${replace(data.azuredevops_git_repository.repo[each.key].web_url, "https://", "https://${local.git_pat}@")} ${path.module}/policies/${each.key}"
    )
  }

  depends_on = [
    data.azuredevops_git_repository.repo,
    random_string.trigger,
    null_resource.remove_cloned_directory
  ]
}


//merge the mgmt_grp_policies and ccoe_mgmt_grp_policies to one map
locals {
  all_mgmt_grp_policies = merge(local.mgmt_grp_policies, local.ccoe_mgmt_grp_policies)
}

output "all_mgmt_grp_policies" {
  value = local.verbose ? local.all_mgmt_grp_policies : null
}
*/


//Deploy custom policy defintions
// only if variable deploy_custom_policies is set to true
resource "azurerm_policy_definition" "filebased" {
  for_each            = var.deploy_policies ? local.filebased_mgmt_grp_policies : {}
  name                = jsondecode(file("${path.module}/policies/${each.key}.json"))["name"]
  display_name        = jsondecode(file("${path.module}/policies/${each.key}.json"))["properties"]["displayName"]
  description         = jsondecode(file("${path.module}/policies/${each.key}.json"))["properties"]["description"]
  policy_type         = jsondecode(file("${path.module}/policies/${each.key}.json"))["properties"]["policyType"]
  mode                = jsondecode(file("${path.module}/policies/${each.key}.json"))["properties"]["mode"]
  policy_rule         = jsonencode(jsondecode(file("${path.module}/policies/${each.key}.json"))["properties"]["policyRule"])
  management_group_id = "/providers/Microsoft.Management/managementGroups/${split("/", each.key)[length(split("/", each.key)) - 2]}"
}

/*
resource "azurerm_policy_definition" "git" {
  for_each            = var.deploy_policies ? local.mgmt_grp_policies : {}
  name                = jsondecode(file("${path.module}/policies/${each.key}/${each.value.policy_filename}"))["name"]
  display_name        = jsondecode(file("${path.module}/policies/${each.key}/{each.value.policy_filename}"))["properties"]["displayName"]
  description         = jsondecode(file("${path.module}/policies/${each.key}/{each.value.policy_filename}"))["properties"]["description"]
  policy_type         = jsondecode(file("${path.module}/policies/${each.key}/{each.value.policy_filename}"))["properties"]["policyType"]
  mode                = jsondecode(file("${path.module}/policies/${each.key}/${each.value.policy_filename}"))["properties"]["mode"]
  policy_rule         = jsonencode(jsondecode(file("${path.module}/policies/${each.key}/${each.value.policy_filename}"))["properties"]["policyRule"])
  management_group_id = "/providers/Microsoft.Management/managementGroups/${split("/", each.key)[length(split("/", each.key)) - 2]}"
  depends_on          = [null_resource.remove_cloned_directory, null_resource.git_clone]
}
*/

resource "azurerm_management_group_policy_assignment" "filebased" {
  for_each             = var.deploy_policies ? local.filebased_mgmt_grp_policies : {}
  name                 = each.value.assignment_name
  policy_definition_id = azurerm_policy_definition.filebased[each.key].id
  management_group_id  = "/providers/Microsoft.Management/managementGroups/${split("/", each.key)[length(split("/", each.key)) - 2]}"
  parameters           = jsonencode(jsondecode(file("${path.module}/policies/${each.key}/${each.value.policy_filename}"))["properties"]["parameters"])
  depends_on           = [azurerm_policy_definition.filebased]
}

/*
resource "azurerm_management_group_policy_assignment" "git" {
  for_each             = var.deploy_policies ? local.mgmt_grp_policies : {}
  name                 = each.value.assignment_name
  policy_definition_id = azurerm_policy_definition.git_defintions[each.key].id
  management_group_id  = "/providers/Microsoft.Management/managementGroups/${split("/", each.key)[length(split("/", each.key)) - 2]}"
  parameters           = jsonencode(jsondecode(file("${path.module}/policies/${each.key}/${each.value.policy_filename}"))["properties"]["parameters"])
  depends_on           = [azurerm_policy_definition.git_defintions]
}
*/

resource "azurerm_management_group_policy_assignment" "builtin" {
  for_each             = var.deploy_policies ? local.builtin_mgmt_grp_policies : {}
  name                 = each.value.assignment_name
  policy_definition_id = each.value.policy_definition_id
  parameters           = jsonencode(jsondecode(file("${path.module}/policies/${each.key}/${each.value.policy_filename}"))["properties"]["parameters"])
  management_group_id  = "/providers/Microsoft.Management/managementGroups/${split("/", each.key)[length(split("/", each.key)) - 2]}"
}
